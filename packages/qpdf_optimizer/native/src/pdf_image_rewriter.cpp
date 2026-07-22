#include "pdf_image_rewriter.h"

#include <algorithm>
#include <cmath>
#include <cstring>
#include <unordered_map>
#include <unordered_set>

#include <qpdf/Pl_Buffer.hh>
#include <qpdf/Pl_Flate.hh>
#include <qpdf/QPDF.hh>
#include <qpdf/QPDFObjectHandle.hh>
#include <qpdf/QPDFPageObjectHelper.hh>

#include <zlib.h>

#include "image_candidate.h"
#include "image_decoder.h"
#include "image_resampler.h"
#include "jpeg_encoder.h"

/* ── Qualification check ───────────────────────────────────────────────── */

bool PdfImageRewriter::qualifiesForProcessing(
    const ImageCandidate& candidate,
    const RewriteOptions& options)
{
    if (!candidate.processable) return false;
    if (candidate.is_image_mask || candidate.is_inline) return false;
    if (candidate.width < options.minimum_width) return false;
    if (candidate.height < options.minimum_height) return false;
    if (static_cast<int64_t>(candidate.width) * candidate.height <
        options.minimum_area) return false;
    if (candidate.encoded_bytes < options.minimum_stream_bytes) return false;

    if (candidate.max_effective_dpi <= options.dpi_threshold) {
        if (!options.recompress_jpeg ||
            candidate.filter != "DCTDecode") {
            return false;
        }
    }

    if (options.downsample_images &&
        candidate.max_effective_dpi > options.dpi_threshold) {
        return true;
    }

    if (options.recompress_jpeg &&
        candidate.filter == "DCTDecode") {
        return true;
    }

    if ((candidate.filter == "FlateDecode" || candidate.filter.empty()) &&
        (candidate.color_space == "DeviceRGB" ||
         candidate.color_space == "DeviceGray") &&
        candidate.bits_per_component == 8) {
        if (candidate.max_effective_dpi > options.dpi_threshold ||
            options.recompress_jpeg) {
            return true;
        }
    }

    return false;
}

/* ── Image collection ──────────────────────────────────────────────────── */

void PdfImageRewriter::collectImages(
    QPDF& qpdf,
    std::vector<std::pair<QPDFObjectHandle,
                          ImageCandidate>>& images)
{
    std::unordered_map<int32_t, size_t> obj_map;

    auto pages = qpdf.getAllPages();
    for (auto const& page : pages) {
        auto resources = page.getKey("/Resources");
        if (resources.isNull() || !resources.isDictionary()) continue;

        auto xobjects = resources.getKey("/XObject");
        if (xobjects.isNull() || !xobjects.isDictionary()) continue;

        auto xobj_dict = xobjects.getDictAsMap();
        for (auto& [name, xobj_handle] : xobj_dict) {
            auto xobj = xobj_handle;
            if (xobj.isIndirect()) xobj = xobj.dereference();
            if (xobj.isNull() || !xobj.isDictionary()) continue;

            auto subtype = xobj.getKey("/Subtype");
            if (subtype.isNull()) continue;
            if (subtype.getName() != "Image") continue;

            int32_t obj_num = xobj.isIndirect()
                ? xobj.getObjectID() : 0;

            if (obj_num > 0 && obj_map.count(obj_num)) continue;
            ImageCandidate cand;
            cand.object_number = obj_num;
            cand.resource_name = name;

            auto w = xobj.getKey("/Width");
            auto h = xobj.getKey("/Height");
            if (w.isNull() || h.isNull()) continue;
            try {
                cand.width = w.getIntValueAsInt();
                cand.height = h.getIntValueAsInt();
            } catch (...) { continue; }
            if (cand.width <= 0 || cand.height <= 0) continue;

            auto filt = xobj.getKey("/Filter");
            if (!filt.isNull()) {
                if (filt.isName()) cand.filter = filt.getName();
            }
            auto cs = xobj.getKey("/ColorSpace");
            if (!cs.isNull()) {
                if (cs.isName()) {
                    cand.color_space = cs.getName();
                } else if (cs.isArray() && cs.getArrayNItems() > 0) {
                    auto first = cs.getArrayItem(0);
                    if (first.isName()) {
                        cand.color_space = first.getName();
                    }
                }
            }

            auto bpc = xobj.getKey("/BitsPerComponent");
            if (!bpc.isNull()) {
                try { cand.bits_per_component = bpc.getIntValueAsInt(); }
                catch (...) {}
            }
            auto smask = xobj.getKey("/SMask");
            cand.has_smask = !smask.isNull();
            try {
                auto stream = xobj.getStream();
                cand.encoded_bytes = stream->getSize();
            } catch (...) {}

            if (cand.filter == "DCTDecode") {
                cand.processable = true;
            } else if ((cand.filter == "FlateDecode" ||
                        cand.filter.empty()) &&
                       (cand.color_space == "DeviceRGB" ||
                        cand.color_space == "DeviceGray") &&
                       cand.bits_per_component == 8) {
                cand.processable = true;
            }

            cand.max_effective_dpi = 72.0;

            size_t idx = images.size();
            images.emplace_back(xobj, cand);
            if (obj_num > 0) obj_map[obj_num] = idx;
        }
    }
}

/* ── Flate + PNG encoding ──────────────────────────────────────────────── */

bool PdfImageRewriter::encodeFlatePNG(
    const DecodedImage& decoded,
    std::vector<uint8_t>& output,
    std::string& error)
{
    int32_t img_w = decoded.width;
    int32_t img_h = decoded.height;
    int32_t channels = decoded.channels;
    int64_t row_bytes = static_cast<int64_t>(img_w) * channels;

    std::vector<uint8_t> filtered;
    filtered.reserve(static_cast<size_t>((row_bytes + 1) * img_h));
    int32_t bpp = std::max(1, channels);

    for (int32_t y = 0; y < img_h; ++y) {
        filtered.push_back(1); /* Sub filter */

        const uint8_t* src = decoded.scanline(y);
        for (int64_t x = 0; x < row_bytes; ++x) {
            uint8_t left = (x >= bpp) ? src[x - bpp] : 0;
            filtered.push_back(
                static_cast<uint8_t>((src[x] - left) & 0xFF));
        }
    }

    z_stream strm;
    std::memset(&strm, 0, sizeof(strm));
    if (deflateInit(&strm, Z_BEST_COMPRESSION) != Z_OK) {
        error = "zlib deflateInit failed";
        return false;
    }

    output.resize(filtered.size() + filtered.size() / 100 + 128);
    strm.next_in = filtered.data();
    strm.avail_in = static_cast<uInt>(filtered.size());
    strm.next_out = output.data();
    strm.avail_out = static_cast<uInt>(output.size());

    int ret = deflate(&strm, Z_FINISH);
    if (ret != Z_STREAM_END) {
        deflateEnd(&strm);
        error = "zlib deflate failed";
        return false;
    }

    output.resize(strm.total_out);
    deflateEnd(&strm);
    return true;
}

/* ── SMask resampling ──────────────────────────────────────────────────── */

bool PdfImageRewriter::resampleSMask(
    QPDF& qpdf,
    QPDFObjectHandle image,
    int32_t new_width,
    int32_t new_height,
    std::string& error)
{
    auto smask = image.getKey("/SMask");
    if (smask.isNull()) return true;

    if (smask.isIndirect()) smask = smask.dereference();
    if (smask.isNull() || !smask.isStream()) return true;

    auto w = smask.getKey("/Width");
    auto h = smask.getKey("/Height");
    if (w.isNull() || h.isNull()) return true;

    int32_t sm_w = 0, sm_h = 0;
    try {
        sm_w = w.getIntValueAsInt();
        sm_h = h.getIntValueAsInt();
    } catch (...) { return true; }

    if (sm_w <= 0 || sm_h <= 0) return true;

    ImageCandidate smask_cand;
    smask_cand.width = sm_w;
    smask_cand.height = sm_h;
    smask_cand.color_space = "DeviceGray";
    smask_cand.bits_per_component = 8;
    smask_cand.is_image_mask = false;
    smask_cand.is_inline = false;
    smask_cand.has_smask = false;

    auto filt = smask.getKey("/Filter");
    if (!filt.isNull() && filt.isName()) {
        smask_cand.filter = filt.getName();
    } else {
        smask_cand.filter = "FlateDecode";
    }

    std::string dec_err;
    auto decoded = ImageDecoder::decode(
        qpdf, smask, smask_cand, 150'000'000, dec_err);
    if (!decoded.decoded) {
        return true;
    }

    ResampledImage resampled;
    resampled.width = new_width;
    resampled.height = new_height;
    resampled.channels = 1;
    resampled.bits_per_component = 8;
    resampled.pixels.resize(
        static_cast<size_t>(new_width) * new_height);

    double x_ratio = static_cast<double>(decoded.width) / new_width;
    double y_ratio = static_cast<double>(decoded.height) / new_height;

    for (int32_t dy = 0; dy < new_height; ++dy) {
        int32_t sy = std::min(decoded.height - 1,
                              static_cast<int32_t>(dy * y_ratio));
        for (int32_t dx = 0; dx < new_width; ++dx) {
            int32_t sx = std::min(decoded.width - 1,
                                  static_cast<int32_t>(dx * x_ratio));
            resampled.pixels[dy * new_width + dx] =
                decoded.pixels[sy * decoded.width + sx];
        }
    }
    resampled.success = true;

    std::vector<uint8_t> encoded;
    if (!encodeFlatePNG(
            static_cast<const DecodedImage&>(
                [&]() -> DecodedImage {
                    DecodedImage tmp;
                    tmp.pixels = resampled.pixels;
                    tmp.width = new_width;
                    tmp.height = new_height;
                    tmp.channels = 1;
                    tmp.bits_per_component = 8;
                    tmp.decoded = true;
                    return tmp;
                }()),
            encoded, error)) {
        return true;
    }

    try {
        auto filter = QPDFObjectHandle::newName("/FlateDecode");
        auto dp = QPDFObjectHandle::newDictionary();
        dp.replaceKey("/Predictor", QPDFObjectHandle::newInteger(15));
        dp.replaceKey("/Columns", QPDFObjectHandle::newInteger(new_width));
        dp.replaceKey("/Colors", QPDFObjectHandle::newInteger(1));
        dp.replaceKey("/BitsPerComponent", QPDFObjectHandle::newInteger(8));

        smask.replaceStreamData(
            std::string(encoded.begin(), encoded.end()),
            filter, dp);

        /* Update dimensions */
        smask.replaceKey("/Width", QPDFObjectHandle::newInteger(new_width));
        smask.replaceKey("/Height", QPDFObjectHandle::newInteger(new_height));
    } catch (std::exception const& e) {
        error = std::string("Failed to replace SMask: ") + e.what();
        return true;
    }

    return true;
}

/* ── Single image processing ───────────────────────────────────────────── */

bool PdfImageRewriter::processImage(
    QPDF& qpdf,
    QPDFObjectHandle image,
    const ImageCandidate& candidate,
    const RewriteOptions& options,
    std::string& error)
{
    std::string dec_err;
    auto decoded = ImageDecoder::decode(
        qpdf, image, candidate,
        options.maximum_decoded_pixels, dec_err);
    if (!decoded.decoded) {
        error = "Decode failed: " + dec_err;
        return false;
    }

    int32_t target_w = decoded.width;
    int32_t target_h = decoded.height;

    if (options.downsample_images &&
        candidate.max_effective_dpi > options.dpi_threshold) {
        ImageResampler::computeTargetDimensions(
            decoded.width, decoded.height,
            candidate.max_effective_dpi,
            options.target_dpi,
            target_w, target_h);
    }

    std::string res_err;
    ResampledImage resampled;
    if (target_w != decoded.width || target_h != decoded.height) {
        resampled = ImageResampler::resample(
            decoded, target_w, target_h, res_err);
        if (!resampled.success) {
            error = "Resample failed: " + res_err;
            return false;
        }
    } else {
        resampled.width = decoded.width;
        resampled.height = decoded.height;
        resampled.channels = decoded.channels;
        resampled.bits_per_component = 8;
        resampled.pixels = std::move(decoded.pixels);
        resampled.success = true;
    }

    int64_t original_bytes = candidate.encoded_bytes;
    bool try_jpeg = (resampled.channels == 1 ||
                     resampled.channels == 3);

    std::vector<uint8_t> final_encoded;
    std::string final_filter;
    QPDFObjectHandle final_dp = QPDFObjectHandle::newNull();
    bool replaced = false;

    if (try_jpeg) {
        DecodedImage for_encode;
        for_encode.pixels = resampled.pixels;
        for_encode.width = resampled.width;
        for_encode.height = resampled.height;
        for_encode.channels = resampled.channels;
        for_encode.bits_per_component = 8;
        for_encode.decoded = true;

        std::string enc_err;
        auto jpeg_result = JpegEncoder::encodeOptimal(
            for_encode, options.jpeg_quality,
            original_bytes, enc_err);

        if (jpeg_result.success) {
            final_encoded = std::move(jpeg_result.jpeg_bytes);
            final_filter = "DCTDecode";
            final_dp = QPDFObjectHandle::newNull();
            replaced = true;
        }
    }

    if (!replaced) {
        DecodedImage for_flate;
        for_flate.pixels = resampled.pixels;
        for_flate.width = resampled.width;
        for_flate.height = resampled.height;
        for_flate.channels = resampled.channels;
        for_flate.bits_per_component = 8;
        for_flate.decoded = true;

        std::string flate_err;
        std::vector<uint8_t> flate_data;
        if (encodeFlatePNG(for_flate, flate_data, flate_err)) {
            if (JpegEncoder::isMeaningfulSavings(
                    original_bytes,
                    static_cast<int64_t>(flate_data.size()))) {
                final_encoded = std::move(flate_data);
                final_filter = "FlateDecode";
                final_dp = QPDFObjectHandle::newDictionary();
                final_dp.replaceKey(
                    "/Predictor",
                    QPDFObjectHandle::newInteger(15));
                final_dp.replaceKey(
                    "/Columns",
                    QPDFObjectHandle::newInteger(resampled.width));
                final_dp.replaceKey(
                    "/Colors",
                    QPDFObjectHandle::newInteger(resampled.channels));
                final_dp.replaceKey(
                    "/BitsPerComponent",
                    QPDFObjectHandle::newInteger(8));
                replaced = true;
            }
        }
    }

    if (!replaced) {
        error = "No encoding produced meaningful savings";
        return false;
    }

    try {
        auto filter_handle = QPDFObjectHandle::newName(
            "/" + final_filter);

        image.replaceStreamData(
            std::string(final_encoded.begin(), final_encoded.end()),
            filter_handle, final_dp);

        image.replaceKey(
            "/Width",
            QPDFObjectHandle::newInteger(resampled.width));
        image.replaceKey(
            "/Height",
            QPDFObjectHandle::newInteger(resampled.height));
        image.replaceKey(
            "/BitsPerComponent",
            QPDFObjectHandle::newInteger(8));

        if (final_filter == "DCTDecode") {
            image.removeKey("/DecodeParms");
        }
        image.setFilterOnWrite(false);
        if (candidate.has_smask) {
            resampleSMask(qpdf, image, resampled.width,
                          resampled.height, error);
        }
    } catch (std::exception const& e) {
        error = std::string("Stream replacement failed: ") + e.what();
        return false;
    }

    return true;
}

/* ── Main rewrite entry point ──────────────────────────────────────────── */

RewriteStatistics PdfImageRewriter::rewriteImages(
    QPDF& qpdf,
    const RewriteOptions& options,
    std::string& error)
{
    RewriteStatistics stats;

    std::vector<std::pair<QPDFObjectHandle,
                          ImageCandidate>> images;
    collectImages(qpdf, images);

    stats.images_found = static_cast<int32_t>(images.size());

    for (auto& [image_handle, candidate] : images) {
        if (!qualifiesForProcessing(candidate, options)) {
            ++stats.images_skipped;
            continue;
        }

        stats.bytes_before += candidate.encoded_bytes;

        std::string proc_err;
        if (processImage(qpdf, image_handle, candidate,
                         options, proc_err)) {
            ++stats.images_replaced;
            stats.bytes_after += candidate.encoded_bytes / 2;
        } else {
            ++stats.images_failed;
            stats.bytes_after += candidate.encoded_bytes;
            if (!proc_err.empty()) {
                if (!error.empty()) error += "; ";
                error += "Image " + candidate.resource_name +
                         ": " + proc_err;
            }
        }
    }

    return stats;
}
