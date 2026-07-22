#include "image_resampler.h"

#include <algorithm>
#include <cmath>
#include <cstring>
#include <memory>
#include <numeric>
#include <vector>

/* ── Dimension calculation ────────────────────────────────────────────── */

void ImageResampler::computeTargetDimensions(
    int32_t orig_width,
    int32_t orig_height,
    double effective_dpi,
    int32_t target_dpi,
    int32_t& out_width,
    int32_t& out_height)
{
    if (effective_dpi <= 0 || target_dpi <= 0) {
        out_width = orig_width;
        out_height = orig_height;
        return;
    }

    if (effective_dpi <= static_cast<double>(target_dpi)) {
        /* Already at or below target — don't upscale */
        out_width = orig_width;
        out_height = orig_height;
        return;
    }

    double scale = static_cast<double>(target_dpi) / effective_dpi;
    out_width = std::max(1, static_cast<int32_t>(
        std::ceil(orig_width * scale)));
    out_height = std::max(1, static_cast<int32_t>(
        std::ceil(orig_height * scale)));

    /* Never exceed original */
    out_width = std::min(out_width, orig_width);
    out_height = std::min(out_height, orig_height);
}

/* ====================================================================== */
/*  Method selection                                                       */
/* ====================================================================== */

ImageResampler::Method ImageResampler::chooseMethod(
    int32_t src_w, int32_t src_h,
    int32_t dst_w, int32_t dst_h)
{
    if (src_w == dst_w && src_h == dst_h) {
        return Method::copy;
    }

    /* If either dimension is unchanged, use area box for the
       changed dimension and copy for the other.  We'll handle this
       with area box and let the clamping logic work it out. */
    double x_ratio = static_cast<double>(src_w) / dst_w;
    double y_ratio = static_cast<double>(src_h) / dst_h;
    double max_ratio = std::max(x_ratio, y_ratio);

    if (max_ratio >= 2.0) {
        return Method::area_box;
    } else if (max_ratio > 1.0) {
        return Method::bicubic;
    } else {
        return Method::copy;
    }
}

/* ====================================================================== */
/*  Area/box filter                                                        */
/* ====================================================================== */

ResampledImage ImageResampler::resampleAreaBox(
    const DecodedImage& src,
    int32_t dst_w, int32_t dst_h)
{
    ResampledImage dst;
    dst.width = dst_w;
    dst.height = dst_h;
    dst.channels = src.channels;
    dst.bits_per_component = 8;
    dst.pixels.resize(
        static_cast<size_t>(dst_w) * dst_h * src.channels);

    double x_ratio = static_cast<double>(src.width) / dst_w;
    double y_ratio = static_cast<double>(src.height) / dst_h;

    struct ColSpan {
        int32_t start;
        int32_t count;
    };
    std::vector<ColSpan> col_spans(dst_w);
    for (int32_t dx = 0; dx < dst_w; ++dx) {
        double x0 = dx * x_ratio;
        double x1 = (dx + 1) * x_ratio;
        int32_t sx0 = std::max(0, static_cast<int32_t>(std::floor(x0)));
        int32_t sx1 = std::min(src.width,
                               static_cast<int32_t>(std::ceil(x1)));
        col_spans[dx].start = sx0;
        col_spans[dx].count = std::max(1, sx1 - sx0);
    }

    std::vector<double> accumulator(
        static_cast<size_t>(dst_w) * src.channels, 0.0);

    auto processRow = [&](int32_t dy, int32_t sy) {
        for (int32_t dx = 0; dx < dst_w; ++dx) {
            auto& span = col_spans[dx];
            const uint8_t* src_row = src.scanline(sy);
            for (int c = 0; c < src.channels; ++c) {
                double sum = 0;
                for (int k = 0; k < span.count; ++k) {
                    sum += src_row[(span.start + k) * src.channels + c];
                }
                accumulator[dx * src.channels + c] += sum / span.count;
            }
        }
    };

    for (int32_t dy = 0; dy < dst_h; ++dy) {
        double y0 = dy * y_ratio;
        double y1 = (dy + 1) * y_ratio;
        int32_t sy0 = std::max(0, static_cast<int32_t>(std::floor(y0)));
        int32_t sy1 = std::min(src.height,
                               static_cast<int32_t>(std::ceil(y1)));
        int32_t row_count = std::max(1, sy1 - sy0);

        std::fill(accumulator.begin(), accumulator.end(), 0.0);

        for (int32_t sy = sy0; sy < sy1; ++sy) {
            processRow(dy, sy);
        }

        uint8_t* dst_row = dst.pixels.data() +
            static_cast<size_t>(dy) * dst_w * src.channels;
        for (int32_t dx = 0; dx < dst_w; ++dx) {
            for (int c = 0; c < src.channels; ++c) {
                double val = accumulator[dx * src.channels + c] /
                             row_count;
                dst_row[dx * src.channels + c] = static_cast<uint8_t>(
                    std::clamp(val + 0.5, 0.0, 255.0));
            }
        }
    }

    dst.success = true;
    return dst;
}

/* ── Mitchell-Netravali cubic kernel ──────────────────────────────────── */

double ImageResampler::mitchellKernel(double x)
{
    constexpr double B = 1.0 / 3.0;
    constexpr double C = 1.0 / 3.0;
    double ax = std::abs(x);

    if (ax < 1.0) {
        return ((12.0 - 9.0 * B - 6.0 * C) * ax * ax * ax +
                (-18.0 + 12.0 * B + 6.0 * C) * ax * ax +
                (6.0 - 2.0 * B)) / 6.0;
    } else if (ax < 2.0) {
        return ((-B - 6.0 * C) * ax * ax * ax +
                (6.0 * B + 30.0 * C) * ax * ax +
                (-12.0 * B - 48.0 * C) * ax +
                (8.0 * B + 24.0 * C)) / 6.0;
    }
    return 0.0;
}

/* ── Bicubic interpolation ────────────────────────────────────────────── */

ResampledImage ImageResampler::resampleBicubic(
    const DecodedImage& src,
    int32_t dst_w, int32_t dst_h)
{
    ResampledImage dst;
    dst.width = dst_w;
    dst.height = dst_h;
    dst.channels = src.channels;
    dst.bits_per_component = 8;
    dst.pixels.resize(
        static_cast<size_t>(dst_w) * dst_h * src.channels);

    double x_ratio = static_cast<double>(src.width) / dst_w;
    double y_ratio = static_cast<double>(src.height) / dst_h;

    struct WeightSet {
        int32_t offsets[4];
        double weights[4];
    };
    std::vector<WeightSet> h_weights(dst_w);

    for (int32_t dx = 0; dx < dst_w; ++dx) {
        double src_x = (dx + 0.5) * x_ratio - 0.5;
        int32_t ix = static_cast<int32_t>(std::floor(src_x));
        double frac_x = src_x - ix;

        for (int k = 0; k < 4; ++k) {
            int32_t sx = ix + k - 1;
            sx = std::clamp(sx, 0, src.width - 1);
            h_weights[dx].offsets[k] = sx * src.channels;
            h_weights[dx].weights[k] =
                mitchellKernel(frac_x - (k - 1));
        }

        /* Normalize weights */
        double sum_w = 0;
        for (int k = 0; k < 4; ++k) sum_w += h_weights[dx].weights[k];
        if (sum_w > 0) {
            for (int k = 0; k < 4; ++k)
                h_weights[dx].weights[k] /= sum_w;
        }
    }

    for (int32_t dy = 0; dy < dst_h; ++dy) {
        double src_y = (dy + 0.5) * y_ratio - 0.5;
        int32_t iy = static_cast<int32_t>(std::floor(src_y));
        double frac_y = src_y - iy;

        int32_t v_offsets[4];
        double v_weights[4];
        for (int k = 0; k < 4; ++k) {
            int32_t sy = iy + k - 1;
            sy = std::clamp(sy, 0, src.height - 1);
            v_offsets[k] = sy;
            v_weights[k] = mitchellKernel(frac_y - (k - 1));
        }
        double sum_vw = 0;
        for (int k = 0; k < 4; ++k) sum_vw += v_weights[k];
        if (sum_vw > 0) {
            for (int k = 0; k < 4; ++k)
                v_weights[k] /= sum_vw;
        }

        uint8_t* dst_row = dst.pixels.data() +
            static_cast<size_t>(dy) * dst_w * src.channels;

        for (int32_t dx = 0; dx < dst_w; ++dx) {
            auto& hw = h_weights[dx];

            for (int c = 0; c < src.channels; ++c) {
                double val = 0;
                for (int vy = 0; vy < 4; ++vy) {
                    const uint8_t* src_row =
                        src.scanline(v_offsets[vy]);
                    double row_val = 0;
                    for (int vx = 0; vx < 4; ++vx) {
                        row_val += src_row[hw.offsets[vx] + c] *
                                   hw.weights[vx];
                    }
                    val += row_val * v_weights[vy];
                }
                dst_row[dx * src.channels + c] =
                    static_cast<uint8_t>(
                        std::clamp(val + 0.5, 0.0, 255.0));
            }
        }
    }

    dst.success = true;
    return dst;
}

/* ── Nearest-neighbor ─────────────────────────────────────────────────── */

ResampledImage ImageResampler::resampleNearest(
    const DecodedImage& src,
    int32_t dst_w, int32_t dst_h)
{
    ResampledImage dst;
    dst.width = dst_w;
    dst.height = dst_h;
    dst.channels = src.channels;
    dst.bits_per_component = 8;
    dst.pixels.resize(
        static_cast<size_t>(dst_w) * dst_h * src.channels);

    double x_ratio = static_cast<double>(src.width) / dst_w;
    double y_ratio = static_cast<double>(src.height) / dst_h;

    for (int32_t dy = 0; dy < dst_h; ++dy) {
        int32_t sy = std::min(
            src.height - 1,
            static_cast<int32_t>(dy * y_ratio));
        const uint8_t* src_row = src.scanline(sy);
        uint8_t* dst_row = dst.pixels.data() +
            static_cast<size_t>(dy) * dst_w * src.channels;

        for (int32_t dx = 0; dx < dst_w; ++dx) {
            int32_t sx = std::min(
                src.width - 1,
                static_cast<int32_t>(dx * x_ratio));
            std::memcpy(
                dst_row + dx * src.channels,
                src_row + sx * src.channels,
                src.channels);
        }
    }

    dst.success = true;
    return dst;
}

/* ── Main resample dispatcher ─────────────────────────────────────────── */

ResampledImage ImageResampler::resample(
    const DecodedImage& decoded,
    int32_t target_width,
    int32_t target_height,
    std::string& error)
{
    if (!decoded.decoded) {
        error = "Cannot resample undecoded image";
        return ResampledImage();
    }

    if (decoded.width <= 0 || decoded.height <= 0) {
        error = "Invalid source dimensions";
        return ResampledImage();
    }

    target_width = std::min(target_width, decoded.width);
    target_height = std::min(target_height, decoded.height);
    target_width = std::max(1, target_width);
    target_height = std::max(1, target_height);

    auto method = chooseMethod(
        decoded.width, decoded.height,
        target_width, target_height);

    switch (method) {
    case Method::copy: {
        ResampledImage copy;
        copy.width = decoded.width;
        copy.height = decoded.height;
        copy.channels = decoded.channels;
        copy.bits_per_component = decoded.bits_per_component;
        copy.pixels = decoded.pixels;
        copy.success = true;
        return copy;
    }
    case Method::nearest:
        return resampleNearest(decoded, target_width, target_height);
    case Method::area_box:
        return resampleAreaBox(decoded, target_width, target_height);
    case Method::bicubic:
        return resampleBicubic(decoded, target_width, target_height);
    }

    error = "Unknown resampling method";
    return ResampledImage();
}
