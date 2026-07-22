#include "jpeg_encoder.h"

#include <algorithm>
#include <cmath>
#include <cstring>
#include <memory>
#include <setjmp.h>

#include <jpeglib.h>

/* ── libjpeg error boundary ──────────────────────────────────────────── */

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

struct JpegMemDestination {
    struct jpeg_destination_mgr pub;
    std::vector<uint8_t>* buffer;
    size_t next_write;
    static constexpr size_t kChunkSize = 65536;
};

void initDestination(j_compress_ptr cinfo)
{
    auto* dest = reinterpret_cast<JpegMemDestination*>(cinfo->dest);
    dest->buffer->resize(dest->kChunkSize);
    dest->next_write = 0;
    dest->pub.next_output_byte = dest->buffer->data();
    dest->pub.free_in_buffer = dest->kChunkSize;
}

boolean emptyOutputBuffer(j_compress_ptr cinfo)
{
    auto* dest = reinterpret_cast<JpegMemDestination*>(cinfo->dest);
    dest->next_write += dest->kChunkSize;
    dest->buffer->resize(dest->next_write + dest->kChunkSize);
    dest->pub.next_output_byte =
        dest->buffer->data() + dest->next_write;
    dest->pub.free_in_buffer = dest->kChunkSize;
    return TRUE;
}

void termDestination(j_compress_ptr cinfo)
{
    auto* dest = reinterpret_cast<JpegMemDestination*>(cinfo->dest);
    dest->next_write +=
        dest->kChunkSize - dest->pub.free_in_buffer;
    dest->buffer->resize(dest->next_write);
}

} // anonymous namespace

/* ── Subsampling helpers ──────────────────────────────────────────────── */

namespace {

void setSubsampling(
    struct jpeg_compress_struct& cinfo,
    JpegEncoder::ChromaSubsampling subsampling)
{
    if (cinfo.input_components == 1) {
        return;
    }

    switch (subsampling) {
    case JpegEncoder::ChromaSubsampling::ratio_4_4_4:
        cinfo.comp_info[0].h_samp_factor = 1;
        cinfo.comp_info[0].v_samp_factor = 1;
        cinfo.comp_info[1].h_samp_factor = 1;
        cinfo.comp_info[1].v_samp_factor = 1;
        cinfo.comp_info[2].h_samp_factor = 1;
        cinfo.comp_info[2].v_samp_factor = 1;
        break;
    case JpegEncoder::ChromaSubsampling::ratio_4_2_0:
        cinfo.comp_info[0].h_samp_factor = 2;
        cinfo.comp_info[0].v_samp_factor = 2;
        cinfo.comp_info[1].h_samp_factor = 1;
        cinfo.comp_info[1].v_samp_factor = 1;
        cinfo.comp_info[2].h_samp_factor = 1;
        cinfo.comp_info[2].v_samp_factor = 1;
        break;
    }
}

} // anonymous namespace

/* ── Savings threshold ────────────────────────────────────────────────── */

bool JpegEncoder::isMeaningfulSavings(
    int64_t original_bytes,
    int64_t encoded_bytes)
{
    int64_t saved = original_bytes - encoded_bytes;
    int64_t threshold = std::max(
        static_cast<int64_t>(1024),
        original_bytes / 100);
    return saved >= threshold;
}

/* ── Low-level encode ─────────────────────────────────────────────────── */

JpegEncoder::EncodeResult JpegEncoder::doEncode(
    const DecodedImage& decoded,
    int32_t quality,
    ChromaSubsampling subsampling,
    std::string& error)
{
    EncodeResult result;

    if (!decoded.decoded || decoded.width <= 0 ||
        decoded.height <= 0) {
        error = "Cannot encode undecoded or invalid image";
        return result;
    }

    if (decoded.channels != 1 && decoded.channels != 3) {
        error = "JPEG encoding supports 1 or 3 channels only";
        return result;
    }

    quality = std::clamp(quality, 1, 100);

    struct jpeg_compress_struct cinfo;
    JpegErrorManager jerr;

    std::memset(&cinfo, 0, sizeof(cinfo));
    std::memset(&jerr, 0, sizeof(jerr));
    cinfo.err = jpeg_std_error(&jerr.pub);
    jerr.pub.error_exit = jpegErrorExit;

    if (setjmp(jerr.jump_buffer)) {
        error = std::string("JPEG encode error: ") + jerr.error_msg;
        jpeg_destroy_compress(&cinfo);
        return result;
    }

    jpeg_create_compress(&cinfo);

    JpegMemDestination mem_dest;
    mem_dest.buffer = &result.jpeg_bytes;
    mem_dest.next_write = 0;
    mem_dest.pub.init_destination = initDestination;
    mem_dest.pub.empty_output_buffer = emptyOutputBuffer;
    mem_dest.pub.term_destination = termDestination;
    cinfo.dest = &mem_dest.pub;

    cinfo.image_width = static_cast<JDIMENSION>(decoded.width);
    cinfo.image_height = static_cast<JDIMENSION>(decoded.height);

    if (decoded.channels == 1) {
        cinfo.input_components = 1;
        cinfo.in_color_space = JCS_GRAYSCALE;
    } else {
        cinfo.input_components = 3;
        cinfo.in_color_space = JCS_RGB;
    }

    jpeg_set_defaults(&cinfo);
    jpeg_set_quality(&cinfo, quality, TRUE);
    cinfo.optimize_coding = TRUE;
    setSubsampling(cinfo, subsampling);
    jpeg_start_compress(&cinfo, TRUE);
    while (cinfo.next_scanline < cinfo.image_height) {
        int row = static_cast<int>(cinfo.next_scanline);
        const uint8_t* src_row = decoded.scanline(row);
        JSAMPROW row_ptr = const_cast<JSAMPROW>(src_row);
        jpeg_write_scanlines(&cinfo, &row_ptr, 1);
    }

    jpeg_finish_compress(&cinfo);
    jpeg_destroy_compress(&cinfo);

    result.encoded_size =
        static_cast<int64_t>(result.jpeg_bytes.size());
    result.success = true;
    result.used_subsampling = subsampling;
    return result;
}

/* ── Single-subsampling encode ────────────────────────────────────────── */

JpegEncoder::EncodeResult JpegEncoder::encode(
    const DecodedImage& decoded,
    int32_t quality,
    int64_t original_bytes,
    std::string& error)
{
    auto result_420 = encodeWithSubsampling(
        decoded, quality, ChromaSubsampling::ratio_4_2_0, error);
    if (!result_420.success) return result_420;

    auto result_444 = encodeWithSubsampling(
        decoded, quality, ChromaSubsampling::ratio_4_4_4, error);
    if (!result_444.success) return result_420;

    if (result_444.encoded_size < result_420.encoded_size) {
        return result_444;
    }
    return result_420;
}

JpegEncoder::EncodeResult JpegEncoder::encodeWithSubsampling(
    const DecodedImage& decoded,
    int32_t quality,
    ChromaSubsampling subsampling,
    std::string& error)
{
    return doEncode(decoded, quality, subsampling, error);
}

/* ── Optimal encode (try both, validate savings) ──────────────────────── */

JpegEncoder::EncodeResult JpegEncoder::encodeOptimal(
    const DecodedImage& decoded,
    int32_t quality,
    int64_t original_bytes,
    std::string& error)
{
    std::string err_420, err_444;

    auto result_420 = encodeWithSubsampling(
        decoded, quality, ChromaSubsampling::ratio_4_2_0, err_420);
    auto result_444 = encodeWithSubsampling(
        decoded, quality, ChromaSubsampling::ratio_4_4_4, err_444);

    EncodeResult* best = nullptr;
    if (result_420.success && result_444.success) {
        best = (result_420.encoded_size <= result_444.encoded_size)
            ? &result_420 : &result_444;
    } else if (result_420.success) {
        best = &result_420;
    } else if (result_444.success) {
        best = &result_444;
    } else {
        error = "Both 4:4:4 and 4:2:0 encoding failed: " +
                err_420 + " / " + err_444;
        return EncodeResult();
    }

    if (!isMeaningfulSavings(original_bytes, best->encoded_size)) {
        error = "Encoded size (" +
                std::to_string(best->encoded_size) +
                ") does not save enough vs original (" +
                std::to_string(original_bytes) + ")";
        return EncodeResult();
    }

    return *best;
}
