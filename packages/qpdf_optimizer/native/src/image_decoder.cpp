#include "image_decoder.h"

#include <algorithm>
#include <exception>
#include <cstring>
#include <memory>
#include <setjmp.h>

#include <jpeglib.h>

#include <qpdf/Buffer.hh>

namespace {

struct JpegErrorManager {
    jpeg_error_mgr pub;
    jmp_buf jump_buffer;
    char message[JMSG_LENGTH_MAX];
};

void jpegErrorExit(j_common_ptr cinfo)
{
    auto* error = reinterpret_cast<JpegErrorManager*>(cinfo->err);
    (*cinfo->err->format_message)(cinfo, error->message);
    longjmp(error->jump_buffer, 1);
}

std::shared_ptr<Buffer> jpegStreamData(
    QPDFObjectHandle image,
    const ImageCandidate& candidate)
{
    return candidate.has_generalized_filter_wrappers
        ? image.getStreamData(qpdf_dl_generalized)
        : image.getRawStreamData();
}

} // namespace

bool ImageDecoder::isFilterSupported(const std::string& filter)
{
    return filter.empty() || filter == "DCTDecode" || filter == "FlateDecode";
}

bool ImageDecoder::isColorSpaceSupported(const ImageCandidate& candidate)
{
    return (candidate.color_model == ImageColorModel::gray &&
            candidate.color_components == 1) ||
           (candidate.color_model == ImageColorModel::rgb &&
            candidate.color_components == 3);
}

DecodedImage ImageDecoder::decodeDCT(
    QPDFObjectHandle image,
    const ImageCandidate& candidate,
    int32_t requested_width,
    int32_t requested_height,
    int64_t maximum_decoded_samples,
    std::string& error)
{
    DecodedImage result;
    std::shared_ptr<Buffer> data;
    try {
        data = jpegStreamData(image, candidate);
    } catch (std::exception const& exception) {
        error = std::string("Failed to read JPEG stream: ") + exception.what();
        return result;
    }

    if (!data || data->getSize() == 0) {
        error = "JPEG stream is empty";
        return result;
    }

    jpeg_decompress_struct cinfo;
    JpegErrorManager jerr;
    std::memset(&cinfo, 0, sizeof(cinfo));
    std::memset(&jerr, 0, sizeof(jerr));
    cinfo.err = jpeg_std_error(&jerr.pub);
    jerr.pub.error_exit = jpegErrorExit;

    if (setjmp(jerr.jump_buffer)) {
        error = std::string("JPEG decode failed: ") + jerr.message;
        jpeg_destroy_decompress(&cinfo);
        return result;
    }

    jpeg_create_decompress(&cinfo);
    jpeg_mem_src(&cinfo, data->getBuffer(), data->getSize());
    if (jpeg_read_header(&cinfo, TRUE) != JPEG_HEADER_OK) {
        error = "JPEG header is invalid";
        jpeg_destroy_decompress(&cinfo);
        return result;
    }

    if (cinfo.jpeg_color_space == JCS_CMYK ||
        cinfo.jpeg_color_space == JCS_YCCK) {
        error = "CMYK JPEG images are not supported";
        jpeg_destroy_decompress(&cinfo);
        return result;
    }

    int32_t channels = candidate.color_components == 1 ? 1 : 3;
    cinfo.out_color_space = channels == 1 ? JCS_GRAYSCALE : JCS_RGB;

    requested_width = std::clamp(requested_width, 1, candidate.width);
    requested_height = std::clamp(requested_height, 1, candidate.height);

    int selected_denominator = 0;
    for (int denominator : {8, 4, 2, 1}) {
        cinfo.scale_num = 1;
        cinfo.scale_denom = denominator;
        jpeg_calc_output_dimensions(&cinfo);
        auto samples = static_cast<int64_t>(cinfo.output_width) *
                       cinfo.output_height * channels;
        if (static_cast<int32_t>(cinfo.output_width) >= requested_width &&
            static_cast<int32_t>(cinfo.output_height) >= requested_height &&
            samples <= maximum_decoded_samples) {
            selected_denominator = denominator;
            break;
        }
    }

    if (selected_denominator == 0) {
        error = "JPEG target exceeds the decoded image limit";
        jpeg_destroy_decompress(&cinfo);
        return result;
    }

    cinfo.scale_num = 1;
    cinfo.scale_denom = selected_denominator;
    jpeg_start_decompress(&cinfo);

    auto output_width = static_cast<int32_t>(cinfo.output_width);
    auto output_height = static_cast<int32_t>(cinfo.output_height);
    auto sample_count = static_cast<int64_t>(output_width) * output_height * channels;
    if (sample_count <= 0 || sample_count > maximum_decoded_samples) {
        error = "Decoded JPEG exceeds the image limit";
        jpeg_destroy_decompress(&cinfo);
        return result;
    }

    result.source_width = static_cast<int32_t>(cinfo.image_width);
    result.source_height = static_cast<int32_t>(cinfo.image_height);
    result.width = output_width;
    result.height = output_height;
    result.channels = channels;
    result.scale_denominator = selected_denominator;
    result.has_smask = candidate.has_smask;
    result.pixels.resize(static_cast<size_t>(sample_count));

    while (cinfo.output_scanline < cinfo.output_height) {
        auto* row = result.scanline(static_cast<int32_t>(cinfo.output_scanline));
        JSAMPROW rows[1] = {row};
        jpeg_read_scanlines(&cinfo, rows, 1);
    }

    jpeg_finish_decompress(&cinfo);
    jpeg_destroy_decompress(&cinfo);
    result.decoded = true;
    return result;
}

DecodedImage ImageDecoder::decodeLossless(
    QPDFObjectHandle image,
    const ImageCandidate& candidate,
    int64_t maximum_decoded_samples,
    std::string& error)
{
    DecodedImage result;
    auto expected = static_cast<int64_t>(candidate.width) *
                    candidate.height * candidate.color_components;
    if (expected <= 0 || expected > maximum_decoded_samples) {
        error = "Decoded image exceeds the image limit";
        return result;
    }

    std::shared_ptr<Buffer> data;
    try {
        data = candidate.filter.empty()
            ? image.getRawStreamData()
            : image.getStreamData(qpdf_dl_all);
    } catch (std::exception const& exception) {
        error = std::string("Failed to decode image stream: ") + exception.what();
        return result;
    }

    if (!data || static_cast<int64_t>(data->getSize()) < expected) {
        error = "Decoded image stream is shorter than expected";
        return result;
    }

    result.pixels.assign(data->getBuffer(), data->getBuffer() + expected);
    result.source_width = candidate.width;
    result.source_height = candidate.height;
    result.width = candidate.width;
    result.height = candidate.height;
    result.channels = candidate.color_components;
    result.has_smask = candidate.has_smask;
    result.decoded = true;
    return result;
}

DecodedImage ImageDecoder::decode(
    QPDF& qpdf,
    QPDFObjectHandle image,
    const ImageCandidate& candidate,
    int32_t requested_width,
    int32_t requested_height,
    int64_t maximum_decoded_samples,
    std::string& error)
{
    static_cast<void>(qpdf);
    if (!candidate.processable || candidate.is_image_mask || candidate.is_inline) {
        error = "Image is not processable";
        return {};
    }
    if (!isFilterSupported(candidate.filter)) {
        error = "Unsupported filter: " + candidate.filter;
        return {};
    }
    if (!isColorSpaceSupported(candidate)) {
        error = "Unsupported color space: " + candidate.color_space;
        return {};
    }
    if (candidate.filter == "DCTDecode") {
        return decodeDCT(
            image, candidate, requested_width, requested_height,
            maximum_decoded_samples, error);
    }
    return decodeLossless(image, candidate, maximum_decoded_samples, error);
}

DecodedImage ImageDecoder::decode(
    QPDF& qpdf,
    QPDFObjectHandle image,
    const ImageCandidate& candidate,
    int64_t maximum_decoded_samples,
    std::string& error)
{
    return decode(
        qpdf, image, candidate, candidate.width, candidate.height,
        maximum_decoded_samples, error);
}
