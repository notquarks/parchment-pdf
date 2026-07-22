#ifndef PDF_IMAGE_REWRITER_H
#define PDF_IMAGE_REWRITER_H

#include <cstdint>
#include <string>

#include <qpdf/QPDF.hh>
#include <qpdf/QPDFObjectHandle.hh>

#include "image_candidate.h"
#include "image_decoder.h"
#include "image_resampler.h"
#include "jpeg_encoder.h"

struct RewriteStatistics {
    int32_t images_found;
    int32_t images_replaced;
    int32_t images_skipped;
    int32_t images_failed;
    int64_t bytes_before;
    int64_t bytes_after;

    RewriteStatistics()
        : images_found(0), images_replaced(0),
          images_skipped(0), images_failed(0),
          bytes_before(0), bytes_after(0) {}
};

struct RewriteOptions {
    int32_t jpeg_quality;
    int32_t target_dpi;
    int32_t dpi_threshold;
    int32_t minimum_width;
    int32_t minimum_height;
    int64_t minimum_area;
    int64_t minimum_stream_bytes;
    int64_t maximum_decoded_pixels;
    bool recompress_jpeg;
    bool downsample_images;

    RewriteOptions()
        : jpeg_quality(75), target_dpi(144), dpi_threshold(180),
          minimum_width(64), minimum_height(64), minimum_area(4096),
          minimum_stream_bytes(1024), maximum_decoded_pixels(150'000'000),
          recompress_jpeg(true), downsample_images(true) {}
};

class PdfImageRewriter {
public:
    static RewriteStatistics rewriteImages(
        QPDF& qpdf,
        const RewriteOptions& options,
        std::string& error);

    static bool processImage(
        QPDF& qpdf,
        QPDFObjectHandle image,
        const ImageCandidate& candidate,
        const RewriteOptions& options,
        std::string& error);

    static bool encodeFlatePNG(
        const DecodedImage& decoded,
        std::vector<uint8_t>& output,
        std::string& error);

private:
    static bool resampleSMask(
        QPDF& qpdf,
        QPDFObjectHandle image,
        int32_t new_width,
        int32_t new_height,
        std::string& error);

    static bool qualifiesForProcessing(
        const ImageCandidate& candidate,
        const RewriteOptions& options);

    static void collectImages(
        QPDF& qpdf,
        std::vector<std::pair<QPDFObjectHandle,
                              ImageCandidate>>& images);
};

#endif /* PDF_IMAGE_REWRITER_H */
