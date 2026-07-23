#include "pdf_image_rewriter.h"

#include <algorithm>
#include <cstring>
#include <limits>
#include <unordered_map>
#include <unordered_set>
#include <utility>

#include <qpdf/Buffer.hh>
#include <qpdf/QPDFPageObjectHelper.hh>

#include <zlib.h>

#include "image_classifier.h"
#include "image_resampler.h"
#include "jpeg_encoder.h"
#include "pdf_name_utils.h"

namespace {

struct EncodedImage {
    std::vector<uint8_t> bytes;
    std::string filter;
    QPDFObjectHandle decode_parms = QPDFObjectHandle::newNull();
};

QPDFObjectHandle makeFlateDecodeParms(int32_t width, int32_t channels)
{
    auto params = QPDFObjectHandle::newDictionary();
    params.replaceKey("/Predictor", QPDFObjectHandle::newInteger(15));
    params.replaceKey("/Columns", QPDFObjectHandle::newInteger(width));
    params.replaceKey("/Colors", QPDFObjectHandle::newInteger(channels));
    params.replaceKey("/BitsPerComponent", QPDFObjectHandle::newInteger(8));
    return params;
}

DecodedImage makeDecoded(ResampledImage&& image)
{
    DecodedImage decoded;
    decoded.pixels = std::move(image.pixels);
    decoded.source_width = image.width;
    decoded.source_height = image.height;
    decoded.width = image.width;
    decoded.height = image.height;
    decoded.channels = image.channels;
    decoded.bits_per_component = image.bits_per_component;
    decoded.decoded = image.success;
    return decoded;
}

void convertToGray(DecodedImage& image)
{
    if (image.channels != 3) {
        return;
    }

    std::vector<uint8_t> gray(
        static_cast<size_t>(image.width) * image.height);
    for (size_t source = 0, target = 0;
         source + 2 < image.pixels.size();
         source += 3, ++target) {
        int value = 77 * image.pixels[source] +
                    150 * image.pixels[source + 1] +
                    29 * image.pixels[source + 2];
        gray[target] = static_cast<uint8_t>((value + 128) >> 8);
    }
    image.pixels = std::move(gray);
    image.channels = 1;
}

bool encodeJpeg(
    const DecodedImage& image,
    int32_t quality,
    ImageClassifier::EncodingRecommendation::ChromaSubsampling chroma,
    EncodedImage& encoded,
    std::string& error)
{
    auto subsampling = chroma ==
            ImageClassifier::EncodingRecommendation::ChromaSubsampling::cs444
        ? JpegEncoder::ChromaSubsampling::ratio_4_4_4
        : JpegEncoder::ChromaSubsampling::ratio_4_2_0;
    auto result = JpegEncoder::encodeWithSubsampling(
        image, quality, subsampling, error);
    if (!result.success) {
        return false;
    }
    encoded.bytes = std::move(result.jpeg_bytes);
    encoded.filter = "DCTDecode";
    return true;
}

bool encodeFlate(
    const DecodedImage& image,
    EncodedImage& encoded,
    std::string& error)
{
    if (!PdfImageRewriter::encodeFlatePNG(image, encoded.bytes, error)) {
        return false;
    }
    encoded.filter = "FlateDecode";
    encoded.decode_parms = makeFlateDecodeParms(image.width, image.channels);
    return true;
}

void collectHandles(
    QPDFObjectHandle resources,
    std::unordered_map<uint64_t, QPDFObjectHandle>& handles,
    std::unordered_set<uint64_t>& active_forms)
{
    if (!resources.isDictionary()) {
        return;
    }

    auto xobjects = resources.getKey("/XObject");
    if (!xobjects.isDictionary()) {
        return;
    }

    for (auto const& [name, value] : xobjects.getDictAsMap()) {
        (void)name;
        auto object = value;
        if (!object.isStream()) {
            continue;
        }

        auto dictionary = object.getDict();
        auto subtype = pdfName(dictionary.getKey("/Subtype"));
        if (subtype == "Image") {
            auto key = pdfObjectKey(object);
            if (key != 0) {
                handles.emplace(key, object);
            }
            continue;
        }

        if (subtype != "Form") {
            continue;
        }

        auto form_key = pdfObjectKey(object);
        if (form_key != 0 && !active_forms.insert(form_key).second) {
            continue;
        }

        auto form_resources = dictionary.getKey("/Resources");
        if (form_resources.isNull()) {
            form_resources = resources;
        }
        collectHandles(form_resources, handles, active_forms);

        if (form_key != 0) {
            active_forms.erase(form_key);
        }
    }
}

void buildHandleMap(
    QPDF& qpdf,
    std::unordered_map<uint64_t, QPDFObjectHandle>& handles)
{
    for (auto const& page : qpdf.getAllPages()) {
        QPDFPageObjectHelper helper(page);
        auto resources = helper.getAttribute("/Resources", false);
        std::unordered_set<uint64_t> active_forms;
        collectHandles(resources, handles, active_forms);
    }
}

} // namespace

bool PdfImageRewriter::qualifiesForProcessing(
    const ImageCandidate& candidate,
    const RewriteOptions& options)
{
    if (!candidate.processable || candidate.is_image_mask || candidate.is_inline) {
        return false;
    }
    if (candidate.width < options.minimum_width ||
        candidate.height < options.minimum_height) {
        return false;
    }
    if (static_cast<int64_t>(candidate.width) * candidate.height <
            options.minimum_area ||
        candidate.encoded_bytes < options.minimum_stream_bytes) {
        return false;
    }

    bool resize = options.downsample_images &&
                  !candidate.placements.empty() &&
                  candidate.max_effective_dpi > options.dpi_threshold &&
                  (candidate.required_width < candidate.width ||
                   candidate.required_height < candidate.height);
    bool recompress = options.recompress_jpeg &&
                      candidate.filter == "DCTDecode";
    bool grayscale = options.convert_to_grayscale &&
                     candidate.color_model == ImageColorModel::rgb;

    if (candidate.has_smask && resize) {
        return false;
    }
    return resize || recompress || grayscale;
}

bool PdfImageRewriter::encodeFlatePNG(
    const DecodedImage& decoded,
    std::vector<uint8_t>& output,
    std::string& error)
{
    if (!decoded.decoded || decoded.width <= 0 || decoded.height <= 0 ||
        (decoded.channels != 1 && decoded.channels != 3)) {
        error = "Invalid image for Flate encoding";
        return false;
    }

    int64_t row_bytes = static_cast<int64_t>(decoded.width) * decoded.channels;
    int64_t filtered_size = (row_bytes + 1) * decoded.height;
    if (row_bytes <= 0 || filtered_size <= 0 ||
        filtered_size > static_cast<int64_t>(std::numeric_limits<uInt>::max())) {
        error = "Image is too large for Flate encoding";
        return false;
    }

    std::vector<uint8_t> filtered(static_cast<size_t>(filtered_size));
    size_t offset = 0;
    for (int32_t y = 0; y < decoded.height; ++y) {
        filtered[offset++] = 1;
        auto* row = decoded.scanline(y);
        for (int64_t x = 0; x < row_bytes; ++x) {
            uint8_t left = x >= decoded.channels ? row[x - decoded.channels] : 0;
            filtered[offset++] = static_cast<uint8_t>(row[x] - left);
        }
    }

    z_stream stream;
    std::memset(&stream, 0, sizeof(stream));
    if (deflateInit(&stream, Z_BEST_COMPRESSION) != Z_OK) {
        error = "zlib initialization failed";
        return false;
    }

    auto bound = deflateBound(&stream, static_cast<uLong>(filtered.size()));
    if (bound > std::numeric_limits<uInt>::max()) {
        deflateEnd(&stream);
        error = "Compressed image buffer is too large";
        return false;
    }
    output.resize(static_cast<size_t>(bound));
    stream.next_in = filtered.data();
    stream.avail_in = static_cast<uInt>(filtered.size());
    stream.next_out = output.data();
    stream.avail_out = static_cast<uInt>(output.size());

    auto status = deflate(&stream, Z_FINISH);
    if (status != Z_STREAM_END) {
        deflateEnd(&stream);
        error = "zlib compression failed";
        return false;
    }

    output.resize(stream.total_out);
    deflateEnd(&stream);
    return true;
}

bool PdfImageRewriter::processImage(
    QPDF& qpdf,
    QPDFObjectHandle image,
    const ImageCandidate& candidate,
    const RewriteOptions& options,
    std::string& error)
{
    int32_t target_width = candidate.width;
    int32_t target_height = candidate.height;
    if (options.downsample_images &&
        !candidate.placements.empty() &&
        candidate.max_effective_dpi > options.dpi_threshold) {
        target_width = candidate.required_width;
        target_height = candidate.required_height;
    }

    auto decoded_limit = std::min(
        options.maximum_decoded_pixels,
        options.memory_budget_bytes);
    auto decoded = ImageDecoder::decode(
        qpdf, image, candidate, target_width, target_height,
        decoded_limit, error);
    if (!decoded.decoded) {
        return false;
    }
    if (decoded.width < target_width || decoded.height < target_height) {
        error = "Decoded image is smaller than its target";
        return false;
    }

    if (decoded.width != target_width || decoded.height != target_height) {
        auto resampled = ImageResampler::resample(
            decoded, target_width, target_height, error);
        if (!resampled.success) {
            return false;
        }
        decoded = makeDecoded(std::move(resampled));
    }

    if (options.convert_to_grayscale) {
        convertToGray(decoded);
    }

    auto recommendation = ImageClassifier::classify(decoded);
    EncodedImage encoded;
    bool should_use_jpeg = candidate.filter == "DCTDecode" ||
        recommendation.format ==
            ImageClassifier::EncodingRecommendation::OutputFormat::jpeg;

    if (should_use_jpeg) {
        if (!encodeJpeg(
                decoded, options.jpeg_quality,
                recommendation.chroma, encoded, error)) {
            return false;
        }
    } else {
        if (!encodeFlate(decoded, encoded, error)) {
            return false;
        }
    }

    if (!JpegEncoder::isMeaningfulSavings(
            candidate.encoded_bytes,
            static_cast<int64_t>(encoded.bytes.size()))) {
        error.clear();
        return false;
    }

    try {
        image.replaceStreamData(
            std::string(encoded.bytes.begin(), encoded.bytes.end()),
            QPDFObjectHandle::newName(pdfDictionaryKey(encoded.filter)),
            encoded.decode_parms);
        auto dictionary = image.getDict();
        dictionary.replaceKey(
            "/Width", QPDFObjectHandle::newInteger(decoded.width));
        dictionary.replaceKey(
            "/Height", QPDFObjectHandle::newInteger(decoded.height));
        dictionary.replaceKey(
            "/BitsPerComponent", QPDFObjectHandle::newInteger(8));

        if (options.convert_to_grayscale && decoded.channels == 1 &&
            candidate.color_model == ImageColorModel::rgb) {
            dictionary.replaceKey(
                "/ColorSpace", QPDFObjectHandle::newName("/DeviceGray"));
            dictionary.removeKey("/Decode");
        }
        if (encoded.filter == "DCTDecode") {
            dictionary.removeKey("/DecodeParms");
        }
        image.setFilterOnWrite(false);
    } catch (std::exception const& exception) {
        error = std::string("Stream replacement failed: ") + exception.what();
        return false;
    }
    return true;
}

RewriteStatistics PdfImageRewriter::rewriteImages(
    QPDF& qpdf,
    const AnalysisResult& analysis,
    const RewriteOptions& options,
    std::string& error,
    std::atomic<bool>* cancelled,
    const std::function<void(int32_t, int32_t)>& progress)
{
    RewriteStatistics stats;
    stats.images_found = static_cast<int32_t>(analysis.images.size());

    std::unordered_map<uint64_t, QPDFObjectHandle> handles;
    buildHandleMap(qpdf, handles);

    int32_t index = 0;
    auto total = static_cast<int32_t>(analysis.images.size());
    for (auto const& candidate : analysis.images) {
        if (cancelled && cancelled->load(std::memory_order_acquire)) {
            stats.cancelled = true;
            break;
        }
        if (progress) {
            progress(index, total);
        }
        ++index;
        if (!qualifiesForProcessing(candidate, options)) {
            ++stats.images_skipped;
            continue;
        }

        auto handle = handles.find(
            pdfObjectKey(candidate.object_number, candidate.generation));
        if (handle == handles.end()) {
            ++stats.images_skipped;
            continue;
        }

        stats.bytes_before += candidate.encoded_bytes;
        std::string image_error;
        if (processImage(qpdf, handle->second, candidate, options, image_error)) {
            ++stats.images_replaced;
            try {
                auto raw = handle->second.getRawStreamData();
                stats.bytes_after += raw
                    ? static_cast<int64_t>(raw->getSize())
                    : candidate.encoded_bytes;
            } catch (...) {
                stats.bytes_after += candidate.encoded_bytes;
            }
        } else if (image_error.empty()) {
            ++stats.images_skipped;
            stats.bytes_after += candidate.encoded_bytes;
        } else {
            ++stats.images_failed;
            stats.bytes_after += candidate.encoded_bytes;
            if (!error.empty()) {
                error += "; ";
            }
            error += "Image " + std::to_string(candidate.object_number) +
                     " " + std::to_string(candidate.generation) +
                     ": " + image_error;
        }
    }
    if (progress) {
        progress(index, total);
    }
    return stats;
}
