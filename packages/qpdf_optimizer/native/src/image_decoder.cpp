#include "image_decoder.h"

#include <algorithm>
#include <cstring>
#include <limits>
#include <memory>
#include <setjmp.h>
#include <stdexcept>

#include <jpeglib.h>

#include <zlib.h>

#include <qpdf/Pl_Buffer.hh>
#include <qpdf/QPDF.hh>
#include <qpdf/QPDFObjectHandle.hh>

/* ── PNG predictor helpers ────────────────────────────────────────────── */

namespace {

int paethPredictor(int a, int b, int c)
{
    int p = a + b - c;
    int pa = std::abs(p - a);
    int pb = std::abs(p - b);
    int pc = std::abs(p - c);
    if (pa <= pb && pa <= pc) return a;
    if (pb <= pc) return b;
    return c;
}

} // anonymous namespace

void ImageDecoder::reversePNGFilter(
    uint8_t filter,
    const uint8_t* prev_row,
    uint8_t* row,
    int32_t row_stride,
    int32_t bpp)
{
    if (filter == 0) return; /* None */

    for (int32_t i = 0; i < row_stride; ++i) {
        uint8_t raw = 0;
        uint8_t left = (i >= bpp) ? row[i - bpp] : 0;
        uint8_t up = prev_row ? prev_row[i] : 0;
        uint8_t up_left =
            (prev_row && i >= bpp) ? prev_row[i - bpp] : 0;

        switch (filter) {
        case 1: /* Sub */
            raw = static_cast<uint8_t>(
                (static_cast<int>(row[i]) + static_cast<int>(left)) & 0xFF);
            break;
        case 2: /* Up */
            raw = static_cast<uint8_t>(
                (static_cast<int>(row[i]) + static_cast<int>(up)) & 0xFF);
            break;
        case 3: /* Average */
            raw = static_cast<uint8_t>(
                (static_cast<int>(row[i]) +
                 static_cast<int>((left + up) / 2)) & 0xFF);
            break;
        case 4: /* Paeth */
            raw = static_cast<uint8_t>(
                (static_cast<int>(row[i]) +
                 paethPredictor(left, up, up_left)) & 0xFF);
            break;
        default:
            return; /* Unknown filter — leave as-is */
        }
        row[i] = raw;
    }
}

/* ── Color space helpers ──────────────────────────────────────────────── */

int32_t ImageDecoder::channelsForColorSpace(const std::string& cs)
{
    if (cs == "DeviceRGB") return 3;
    if (cs == "DeviceGray") return 1;
    if (cs == "DeviceCMYK") return 4;
    if (cs == "CalRGB") return 3;
    if (cs == "CalGray") return 1;
    if (cs == "Lab") return 3;
    if (cs == "ICCBased") return 3; /* assume RGB, refined below */
    return 0;
}

bool ImageDecoder::isFilterSupported(const std::string& filter)
{
    return filter == "DCTDecode" || filter == "FlateDecode" ||
           filter.empty();
}

bool ImageDecoder::isColorSpaceSupported(const std::string& cs)
{
    return cs == "DeviceRGB" || cs == "DeviceGray" ||
           cs == "ICCBased" || cs == "CalRGB" ||
           cs == "CalGray";
}

/* ── DecodeParms for Flate ───────────────────────────────────────────── */

bool ImageDecoder::getFlateDecodeParms(
    QPDFObjectHandle image,
    int32_t& predictor,
    int32_t& colors,
    int32_t& bits_per_component,
    int32_t& columns)
{
    predictor = 1;
    colors = 3;
    bits_per_component = 8;
    columns = 0;

    auto dp = image.getKey("/DecodeParms");
    if (dp.isNull() || !dp.isDictionary()) {
        return false;
    }

    auto pred = dp.getKey("/Predictor");
    if (!pred.isNull()) {
        predictor = pred.getIntValueAsInt();
    }

    auto cols = dp.getKey("/Columns");
    if (!cols.isNull()) {
        columns = cols.getIntValueAsInt();
    }

    auto clr = dp.getKey("/Colors");
    if (!clr.isNull()) {
        colors = clr.getIntValueAsInt();
    }

    auto bpc = dp.getKey("/BitsPerComponent");
    if (!bpc.isNull()) {
        bits_per_component = bpc.getIntValueAsInt();
    }

    return predictor >= 10; /* PNG predictor range */
}

/* ── Indexed color expansion ──────────────────────────────────────────── */

bool ImageDecoder::expandIndexed(
    const uint8_t* indexed_data,
    int32_t width,
    int32_t height,
    int32_t bits_per_component,
    QPDFObjectHandle color_space_array,
    std::vector<uint8_t>& rgb_pixels,
    std::string& error)
{
    if (color_space_array.isNull() || !color_space_array.isArray() ||
        color_space_array.getArrayNItems() < 4) {
        error = "Invalid Indexed color space array";
        return false;
    }

    auto base_cs = color_space_array.getArrayItem(1);
    auto num_entries = color_space_array.getArrayItem(2);
    auto lookup = color_space_array.getArrayItem(3);

    if (base_cs.isNull() || lookup.isNull()) {
        error = "Indexed color space missing base or lookup";
        return false;
    }

    std::string base_name;
    if (base_cs.isName()) {
        base_name = base_cs.getName();
    } else if (base_cs.isArray() && base_cs.getArrayNItems() > 0) {
        auto first = base_cs.getArrayItem(0);
        if (first.isName()) base_name = first.getName();
    }

    if (base_name != "DeviceRGB") {
        error = "Indexed color space with unsupported base: " + base_name;
        return false;
    }

    int32_t max_index = 0;
    try {
        max_index = num_entries.getIntValueAsInt();
    } catch (...) {
        error = "Invalid Indexed color space num_entries";
        return false;
    }

    std::vector<uint8_t> lookup_bytes;
    if (lookup.isStream()) {
        try {
            auto buf = lookup.getStreamData(qpdf_dl_none);
            auto* bp = buf->getBuffer();
            auto sz = buf->getSize();
            lookup_bytes.assign(bp, bp + sz);
        } catch (...) {
            error = "Failed to read Indexed color space lookup";
            return false;
        }
    } else if (lookup.isString()) {
        auto s = lookup.getStringValue();
        lookup_bytes.assign(s.begin(), s.end());
    } else {
        error = "Indexed color space lookup is not a stream or string";
        return false;
    }

    int64_t pixel_count = static_cast<int64_t>(width) * height;

    rgb_pixels.resize(static_cast<size_t>(pixel_count * 3));

    for (int64_t i = 0; i < pixel_count; ++i) {
        int32_t index = 0;
        if (bits_per_component <= 8) {
            index = indexed_data[i];
        } else {
            index = (indexed_data[2 * i] << 8) | indexed_data[2 * i + 1];
        }
        if (index < 0 || index >= max_index) {
            rgb_pixels[3 * i + 0] = 0;
            rgb_pixels[3 * i + 1] = 0;
            rgb_pixels[3 * i + 2] = 0;
            continue;
        }
        int64_t lookup_offset = static_cast<int64_t>(index) * 3;
        if (lookup_offset + 2 <
            static_cast<int64_t>(lookup_bytes.size())) {
            rgb_pixels[3 * i + 0] = lookup_bytes[lookup_offset + 0];
            rgb_pixels[3 * i + 1] = lookup_bytes[lookup_offset + 1];
            rgb_pixels[3 * i + 2] = lookup_bytes[lookup_offset + 2];
        } else {
            rgb_pixels[3 * i + 0] = 0;
            rgb_pixels[3 * i + 1] = 0;
            rgb_pixels[3 * i + 2] = 0;
        }
    }

    return true;
}

/* ── DCT (JPEG) decoding ─────────────────────────────────────────────── */

namespace {

struct JpegErrorManager {
    struct jpeg_error_mgr pub;
    std::jmp_buf jump_buffer;
    char error_msg[JMSG_LENGTH_MAX];
};

void jpegErrorExit(j_common_ptr cinfo)
{
    auto* err = reinterpret_cast<JpegErrorManager*>(cinfo->err);
    (*cinfo->err->format_message)(cinfo, err->error_msg);
    std::longjmp(err->jump_buffer, 1);
}

} // anonymous namespace

DecodedImage ImageDecoder::decodeDCT(
    QPDF& qpdf,
    QPDFObjectHandle image,
    const ImageCandidate& candidate,
    int64_t max_decoded_pixels,
    std::string& error)
{
    DecodedImage result;

    std::shared_ptr<Buffer> raw_buf;
    try {
        raw_buf = image.getStreamData(qpdf_dl_all);
    } catch (std::exception const& e) {
        error = std::string("Failed to get DCT stream data: ") + e.what();
        return result;
    }

    if (!raw_buf) {
        error = "DCT stream returned null buffer";
        return result;
    }

    auto* bp = raw_buf->getBuffer();
    auto sz = raw_buf->getSize();
    if (!bp || sz == 0) {
        error = "DCT stream is empty";
        return result;
    }

    struct jpeg_decompress_struct cinfo;
    JpegErrorManager jerr;

    std::memset(&cinfo, 0, sizeof(cinfo));
    std::memset(&jerr, 0, sizeof(jerr));
    cinfo.err = jpeg_std_error(&jerr.pub);
    jerr.pub.error_exit = jpegErrorExit;

    if (setjmp(jerr.jump_buffer)) {
        error = std::string("JPEG decode error: ") + jerr.error_msg;
        jpeg_destroy_decompress(&cinfo);
        return result;
    }

    jpeg_create_decompress(&cinfo);
    jpeg_mem_src(&cinfo, bp, sz);
    if (jpeg_read_header(&cinfo, TRUE) != JPEG_HEADER_OK) {
        error = "JPEG read_header failed";
        jpeg_destroy_decompress(&cinfo);
        return result;
    }

    bool output_gray = (cinfo.out_color_space == JCS_GRAYSCALE) ||
                       (candidate.color_space == "DeviceGray");

    if (output_gray) {
        cinfo.out_color_space = JCS_GRAYSCALE;
    } else {
        /* Force RGB output */
        cinfo.out_color_space = JCS_RGB;
    }

    int scale = 1;
    for (int s = 8; s >= 2; s /= 2) {
        JDIMENSION test_w = (cinfo.image_width + s - 1) / s;
        JDIMENSION test_h = (cinfo.image_height + s - 1) / s;
        int test_chans = output_gray ? 1 : 3;
        int64_t test_pixels =
            static_cast<int64_t>(test_w) * test_h * test_chans;
        if (test_pixels <= max_decoded_pixels) {
            scale = s;
            break;
        }
    }

    cinfo.scale_num = 1;
    cinfo.scale_denom = scale;

    cinfo.out_color_components = output_gray ? 1 : 3;
    cinfo.output_components = output_gray ? 1 : 3;

    jpeg_start_decompress(&cinfo);

    int32_t out_w = static_cast<int32_t>(cinfo.output_width);
    int32_t out_h = static_cast<int32_t>(cinfo.output_height);
    int32_t out_chans = output_gray ? 1 : 3;

    int64_t total_pixels =
        static_cast<int64_t>(out_w) * out_h * out_chans;
    if (total_pixels > max_decoded_pixels) {
        error = "Decoded image exceeds pixel limit after DCT scaling";
        jpeg_destroy_decompress(&cinfo);
        return result;
    }

    result.width = out_w;
    result.height = out_h;
    result.channels = out_chans;
    result.bits_per_component = 8;
    result.has_smask = candidate.has_smask;
    result.pixels.resize(static_cast<size_t>(total_pixels));

    while (cinfo.output_scanline < cinfo.output_height) {
        int row = static_cast<int>(cinfo.output_scanline);
        uint8_t* dest = result.scanline(row);
        JSAMPROW row_ptr = dest;
        jpeg_read_scanlines(&cinfo, &row_ptr, 1);
    }

    jpeg_finish_decompress(&cinfo);
    jpeg_destroy_decompress(&cinfo);

    result.decoded = true;
    return result;
}

/* ── Flate (zlib + PNG predictor) decoding ────────────────────────────── */

DecodedImage ImageDecoder::decodeFlate(
    QPDF& qpdf,
    QPDFObjectHandle image,
    const ImageCandidate& candidate,
    int64_t max_decoded_pixels,
    std::string& error)
{
    DecodedImage result;

    std::shared_ptr<Buffer> raw_buf;
    try {
        raw_buf = image.getRawStreamData();
    } catch (std::exception const& e) {
        error = std::string("Failed to get raw stream data: ") + e.what();
        return result;
    }

    if (!raw_buf) {
        error = "Raw stream data is null";
        return result;
    }

    auto* compressed = raw_buf->getBuffer();
    auto compressed_size = raw_buf->getSize();
    if (!compressed || compressed_size == 0) {
        error = "Stream data is empty";
        return result;
    }

    z_stream strm;
    std::memset(&strm, 0, sizeof(strm));
    if (inflateInit(&strm) != Z_OK) {
        error = "zlib inflateInit failed";
        return result;
    }

    std::vector<uint8_t> decompressed;
    decompressed.reserve(compressed_size * 2);

    strm.next_in = compressed;
    strm.avail_in = static_cast<uInt>(compressed_size);

    constexpr size_t kChunkSize = 65536;
    uint8_t chunk[kChunkSize];
    int ret;

    do {
        strm.next_out = chunk;
        strm.avail_out = sizeof(chunk);
        ret = inflate(&strm, Z_NO_FLUSH);
        if (ret != Z_OK && ret != Z_STREAM_END) {
            inflateEnd(&strm);
            error = std::string("zlib inflate failed: ") +
                    strm.msg ? strm.msg : "unknown error";
            return result;
        }
        size_t have = sizeof(chunk) - strm.avail_out;
        decompressed.insert(decompressed.end(), chunk, chunk + have);
    } while (ret != Z_STREAM_END);

    inflateEnd(&strm);

    int32_t predictor = 1;
    int32_t colors = 3;
    int32_t bpc = 8;
    int32_t columns = 0;
    bool has_png_predictor = getFlateDecodeParms(
        image, predictor, colors, bpc, columns);

    if (bpc != 8) {
        error = "FlateDecode with BitsPerComponent != 8 not supported";
        return result;
    }

    int32_t img_w = candidate.width;
    int32_t img_h = candidate.height;
    if (img_w <= 0 || img_h <= 0) {
        error = "Invalid image dimensions";
        return result;
    }

    int32_t channels = channelsForColorSpace(candidate.color_space);
    if (channels == 0) {
        /* Check for ICCBased — get actual number of components */
        if (candidate.color_space == "ICCBased") {
            auto cs = image.getKey("/ColorSpace");
            if (cs.isArray() && cs.getArrayNItems() > 1) {
                auto icc = cs.getArrayItem(1);
                if (icc.isStream()) {
                    auto n = icc.getKey("/N");
                    if (!n.isNull()) {
                        channels = n.getIntValueAsInt();
                    }
                }
            }
            if (channels == 0) channels = 3; /* fallback */
        } else {
            error = "Unsupported color space: " + candidate.color_space;
            return result;
        }
    }

    bool is_indexed = (candidate.color_space.find("Indexed") !=
                       std::string::npos);
    if (is_indexed) {
        channels = 1;
    }

    int64_t row_stride = static_cast<int64_t>(img_w) * channels;
    int64_t expected_bytes = row_stride * img_h;

    if (has_png_predictor && columns > 0) {
        int64_t raw_row = static_cast<int64_t>(columns) * colors;
        int64_t filtered_bytes = (raw_row + 1) * img_h;
        expected_bytes = filtered_bytes;

        if (static_cast<int64_t>(decompressed.size()) != filtered_bytes) {
            expected_bytes = raw_row * img_h;
        }
    }

    if (static_cast<int64_t>(decompressed.size()) < expected_bytes) {
        int64_t raw_row = row_stride;
        expected_bytes = raw_row * img_h;
        if (static_cast<int64_t>(decompressed.size()) < expected_bytes) {
            error = "Decompressed data too small: expected " +
                    std::to_string(expected_bytes) + ", got " +
                    std::to_string(decompressed.size());
            return result;
        }
    }

    int64_t total_pixels =
        static_cast<int64_t>(img_w) * img_h * channels;
    if (total_pixels > max_decoded_pixels) {
        error = "Decoded image exceeds pixel limit";
        return result;
    }

    if (has_png_predictor) {
        int64_t bytes_per_row = static_cast<int64_t>(img_w) * channels;
        int32_t bpp = std::max(1, (channels * bpc) / 8);
        std::vector<uint8_t> unfiltered;
        unfiltered.resize(static_cast<size_t>(bytes_per_row * img_h));

        for (int32_t y = 0; y < img_h; ++y) {
            size_t src_offset =
                static_cast<size_t>(y) * (bytes_per_row + 1);
            size_t dst_offset =
                static_cast<size_t>(y) * bytes_per_row;

            if (src_offset >= decompressed.size()) break;

            uint8_t filter_type = decompressed[src_offset];
            uint8_t* dst_row = unfiltered.data() + dst_offset;
            const uint8_t* src_row =
                decompressed.data() + src_offset + 1;

            std::memcpy(dst_row, src_row,
                        std::min(static_cast<size_t>(bytes_per_row),
                                 decompressed.size() - src_offset - 1));

            const uint8_t* prev = (y > 0)
                ? unfiltered.data() +
                  static_cast<size_t>((y - 1)) * bytes_per_row
                : nullptr;

            reversePNGFilter(filter_type, prev, dst_row,
                             static_cast<int32_t>(bytes_per_row), bpp);
        }

        decompressed = std::move(unfiltered);
    }

    if (is_indexed) {
        auto cs = image.getKey("/ColorSpace");
        std::vector<uint8_t> rgb_pixels;
        if (!expandIndexed(decompressed.data(), img_w, img_h, bpc,
                           cs, rgb_pixels, error)) {
            return result;
        }
        result.pixels = std::move(rgb_pixels);
        result.width = img_w;
        result.height = img_h;
        result.channels = 3;
    } else {
        int64_t exact_size =
            static_cast<int64_t>(img_w) * img_h * channels;
        if (static_cast<int64_t>(decompressed.size()) > exact_size) {
            decompressed.resize(static_cast<size_t>(exact_size));
        }
        result.pixels = std::move(decompressed);
        result.width = img_w;
        result.height = img_h;
        result.channels = channels;
    }

    result.bits_per_component = 8;
    result.has_smask = candidate.has_smask;
    result.decoded = true;
    return result;
}

/* ── Main decode dispatcher ───────────────────────────────────────────── */

DecodedImage ImageDecoder::decode(
    QPDF& qpdf,
    QPDFObjectHandle image,
    const ImageCandidate& candidate,
    int64_t max_decoded_pixels,
    std::string& error)
{
    if (candidate.is_image_mask) {
        error = "Image masks are not supported";
        return DecodedImage();
    }

    if (candidate.is_inline) {
        error = "Inline images are not supported";
        return DecodedImage();
    }

    if (!isFilterSupported(candidate.filter)) {
        error = "Unsupported filter: " + candidate.filter;
        return DecodedImage();
    }

    std::string effective_cs = candidate.color_space;
    if (effective_cs.empty()) {
        auto cs = image.getKey("/ColorSpace");
        if (!cs.isNull()) {
            if (cs.isName()) {
                effective_cs = cs.getName();
            } else if (cs.isArray() && cs.getArrayNItems() > 0) {
                auto first = cs.getArrayItem(0);
                if (first.isName()) effective_cs = first.getName();
            }
        }
    }

    bool is_indexed = (effective_cs.find("Indexed") !=
                       std::string::npos);

    if (!is_indexed) {
        if (!isColorSpaceSupported(effective_cs) &&
            effective_cs != "DeviceCMYK") {
            error = "Unsupported color space: " + effective_cs;
            return DecodedImage();
        }
    }

    if (candidate.filter == "DCTDecode") {
        return decodeDCT(qpdf, image, candidate,
                         max_decoded_pixels, error);
    } else {
        /* FlateDecode or uncompressed */
        return decodeFlate(qpdf, image, candidate,
                           max_decoded_pixels, error);
    }
}
