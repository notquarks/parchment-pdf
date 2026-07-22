#ifndef IMAGE_DECODER_H
#define IMAGE_DECODER_H

#include <cstdint>
#include <memory>
#include <string>
#include <vector>

#include <qpdf/QPDF.hh>
#include <qpdf/QPDFObjectHandle.hh>

#include "image_candidate.h"

struct DecodedImage {
    std::vector<uint8_t> pixels;
    int32_t width;
    int32_t height;
    int32_t channels;
    int32_t bits_per_component;
    bool has_smask;
    bool decoded;

    DecodedImage()
        : width(0), height(0), channels(0),
          bits_per_component(8), has_smask(false),
          decoded(false) {}

    int64_t pixel_count() const {
        return static_cast<int64_t>(width) * height * channels;
    }

    int64_t row_bytes() const {
        return static_cast<int64_t>(width) * channels;
    }

    uint8_t* scanline(int32_t y) {
        return pixels.data() +
               static_cast<int64_t>(y) * row_bytes();
    }

    const uint8_t* scanline(int32_t y) const {
        return pixels.data() +
               static_cast<int64_t>(y) * row_bytes();
    }
};

class ImageDecoder {
public:
    static DecodedImage decode(
        QPDF& qpdf,
        QPDFObjectHandle image,
        const ImageCandidate& candidate,
        int64_t max_decoded_pixels = 150'000'000,
        std::string& error);

    static bool isFilterSupported(const std::string& filter);
    static bool isColorSpaceSupported(const std::string& cs);

private:
    static DecodedImage decodeDCT(
        QPDF& qpdf,
        QPDFObjectHandle image,
        const ImageCandidate& candidate,
        int64_t max_decoded_pixels,
        std::string& error);

    static DecodedImage decodeFlate(
        QPDF& qpdf,
        QPDFObjectHandle image,
        const ImageCandidate& candidate,
        int64_t max_decoded_pixels,
        std::string& error);

    static void reversePNGFilter(
        uint8_t filter,
        const uint8_t* prev_row,
        uint8_t* row,
        int32_t row_stride,
        int32_t bpp);

    static bool expandIndexed(
        const uint8_t* indexed_data,
        int32_t width,
        int32_t height,
        int32_t bits_per_component,
        QPDFObjectHandle color_space_array,
        std::vector<uint8_t>& rgb_pixels,
        std::string& error);

    static int32_t channelsForColorSpace(const std::string& cs);

    static bool getFlateDecodeParms(
        QPDFObjectHandle image,
        int32_t& predictor,
        int32_t& colors,
        int32_t& bits_per_component,
        int32_t& columns);
};

#endif /* IMAGE_DECODER_H */
