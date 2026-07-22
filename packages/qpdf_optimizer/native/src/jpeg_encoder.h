#ifndef JPEG_ENCODER_H
#define JPEG_ENCODER_H

#include <cstdint>
#include <string>
#include <vector>

#include "image_decoder.h"

class JpegEncoder {
public:
    enum class ChromaSubsampling : uint8_t {
        ratio_4_4_4 = 0,
        ratio_4_2_0 = 1,
    };

    struct EncodeResult {
        std::vector<uint8_t> jpeg_bytes;
        int64_t encoded_size;
        bool success;
        ChromaSubsampling used_subsampling;

        EncodeResult()
            : encoded_size(0), success(false),
              used_subsampling(ChromaSubsampling::ratio_4_4_4) {}
    };

    static EncodeResult encode(
        const DecodedImage& decoded,
        int32_t quality,
        int64_t original_bytes,
        std::string& error);

    static EncodeResult encodeWithSubsampling(
        const DecodedImage& decoded,
        int32_t quality,
        ChromaSubsampling subsampling,
        std::string& error);

    static bool isMeaningfulSavings(
        int64_t original_bytes,
        int64_t encoded_bytes);

    static EncodeResult encodeOptimal(
        const DecodedImage& decoded,
        int32_t quality,
        int64_t original_bytes,
        std::string& error);

private:
    static EncodeResult doEncode(
        const DecodedImage& decoded,
        int32_t quality,
        ChromaSubsampling subsampling,
        std::string& error);
};

#endif /* JPEG_ENCODER_H */
