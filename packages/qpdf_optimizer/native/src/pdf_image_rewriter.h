#ifndef PDF_IMAGE_REWRITER_H
#define PDF_IMAGE_REWRITER_H

#include <atomic>
#include <cstdint>
#include <functional>
#include <string>
#include <vector>

#include <qpdf/QPDF.hh>
#include <qpdf/QPDFObjectHandle.hh>

#include "image_candidate.h"
#include "image_decoder.h"

struct RewriteStatistics {
    int32_t images_found = 0;
    int32_t images_replaced = 0;
    int32_t images_skipped = 0;
    int32_t images_failed = 0;
    int64_t bytes_before = 0;
    int64_t bytes_after = 0;
    bool cancelled = false;
};

struct RewriteOptions {
    int32_t jpeg_quality = 75;
    int32_t target_dpi = 144;
    int32_t dpi_threshold = 180;
    int32_t minimum_width = 64;
    int32_t minimum_height = 64;
    int64_t minimum_area = 4096;
    int64_t minimum_stream_bytes = 1024;
    int64_t maximum_decoded_pixels = 150'000'000;
    int64_t memory_budget_bytes = 512'000'000;
    bool recompress_jpeg = true;
    bool downsample_images = true;
    bool convert_to_grayscale = false;
    bool preserve_transparency = true;
};

class PdfImageRewriter {
public:
    static RewriteStatistics rewriteImages(
        QPDF& qpdf,
        const AnalysisResult& analysis,
        const RewriteOptions& options,
        std::string& error,
        std::atomic<bool>* cancelled = nullptr,
        const std::function<void(int32_t, int32_t)>& progress = {});

    static bool encodeFlatePNG(
        const DecodedImage& decoded,
        std::vector<uint8_t>& output,
        std::string& error);

private:
    static bool qualifiesForProcessing(
        const ImageCandidate& candidate,
        const RewriteOptions& options);

    static bool processImage(
        QPDF& qpdf,
        QPDFObjectHandle image,
        const ImageCandidate& candidate,
        const RewriteOptions& options,
        std::string& error);
};

#endif
