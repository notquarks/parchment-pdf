#ifndef IMAGE_RESAMPLER_H
#define IMAGE_RESAMPLER_H

#include <cstdint>
#include <string>

#include "image_decoder.h"

struct ResampledImage {
    std::vector<uint8_t> pixels;
    int32_t width;
    int32_t height;
    int32_t channels;
    int32_t bits_per_component;
    bool success;

    ResampledImage()
        : width(0), height(0), channels(0),
          bits_per_component(8), success(false) {}
};

class ImageResampler {
public:
    static void computeTargetDimensions(
        int32_t orig_width,
        int32_t orig_height,
        double effective_dpi,
        int32_t target_dpi,
        int32_t& out_width,
        int32_t& out_height);

    static ResampledImage resample(
        const DecodedImage& decoded,
        int32_t target_width,
        int32_t target_height,
        std::string& error);

    enum class Method {
        nearest,
        area_box,
        bicubic,
        copy,
    };

    static Method chooseMethod(
        int32_t src_w, int32_t src_h,
        int32_t dst_w, int32_t dst_h);

private:
    static ResampledImage resampleAreaBox(
        const DecodedImage& src,
        int32_t dst_w, int32_t dst_h);

    static ResampledImage resampleBicubic(
        const DecodedImage& src,
        int32_t dst_w, int32_t dst_h);

    static ResampledImage resampleNearest(
        const DecodedImage& src,
        int32_t dst_w, int32_t dst_h);

    static double mitchellKernel(double x);
};

#endif /* IMAGE_RESAMPLER_H */
