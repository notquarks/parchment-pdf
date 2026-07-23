#ifndef IMAGE_DECODER_H
#define IMAGE_DECODER_H

#include <cstdint>
#include <string>
#include <vector>

#include <qpdf/QPDF.hh>
#include <qpdf/QPDFObjectHandle.hh>

#include "image_candidate.h"

struct DecodedImage {
    std::vector<uint8_t> pixels;
    int32_t source_width;
    int32_t source_height;
    int32_t width;
    int32_t height;
    int32_t channels;
    int32_t bits_per_component;
    int32_t scale_denominator;
    bool has_smask;
    bool decoded;

    DecodedImage()
        : source_width(0), source_height(0), width(0), height(0), channels(0),
          bits_per_component(8), scale_denominator(1), has_smask(false),
          decoded(false) {}

    int64_t sample_count() const {
        return static_cast<int64_t>(width) * height * channels;
    }

    int64_t pixel_count() const {
        return sample_count();
    }

    int64_t row_bytes() const {
        return static_cast<int64_t>(width) * channels;
    }

    uint8_t* scanline(int32_t y) {
        return pixels.data() + static_cast<int64_t>(y) * row_bytes();
    }

    const uint8_t* scanline(int32_t y) const {
        return pixels.data() + static_cast<int64_t>(y) * row_bytes();
    }
};

class ImageDecoder {
public:
    static DecodedImage decode(
        QPDF& qpdf,
        QPDFObjectHandle image,
        const ImageCandidate& candidate,
        int32_t requested_width,
        int32_t requested_height,
        int64_t maximum_decoded_samples,
        std::string& error);

    static DecodedImage decode(
        QPDF& qpdf,
        QPDFObjectHandle image,
        const ImageCandidate& candidate,
        int64_t maximum_decoded_samples,
        std::string& error);

    static bool isFilterSupported(const std::string& filter);
    static bool isColorSpaceSupported(const ImageCandidate& candidate);

private:
    static DecodedImage decodeDCT(
        QPDFObjectHandle image,
        const ImageCandidate& candidate,
        int32_t requested_width,
        int32_t requested_height,
        int64_t maximum_decoded_samples,
        std::string& error);

    static DecodedImage decodeLossless(
        QPDFObjectHandle image,
        const ImageCandidate& candidate,
        int64_t maximum_decoded_samples,
        std::string& error);
};

#endif
