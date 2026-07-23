#include "image_classifier.h"

#include <algorithm>
#include <cmath>
#include <cstring>
#include <unordered_set>
#include <vector>

/* ── Helpers ─────────────────────────────────────────────────────────── */

uint32_t ImageClassifier::quantizeColor(
    uint8_t r, uint8_t g, uint8_t b)
{
    /* 5 bits per channel → 15-bit hash key */
    return (static_cast<uint32_t>(r >> 3) << 10) |
           (static_cast<uint32_t>(g >> 3) << 5) |
           static_cast<uint32_t>(b >> 3);
}

DecodedImage ImageClassifier::downscale(
    const DecodedImage& decoded,
    int32_t max_sample_dim)
{
    int32_t sw = decoded.width;
    int32_t sh = decoded.height;

    int32_t factor = std::max(1, std::max(sw, sh) / max_sample_dim);
    int32_t out_w = std::max(1, sw / factor);
    int32_t out_h = std::max(1, sh / factor);
    int32_t ch = decoded.channels;

    DecodedImage sample;
    sample.width = out_w;
    sample.height = out_h;
    sample.channels = ch;
    sample.bits_per_component = 8;
    sample.decoded = true;
    sample.pixels.resize(
        static_cast<size_t>(out_w) * out_h * ch);

    double x_ratio = static_cast<double>(sw) / out_w;
    double y_ratio = static_cast<double>(sh) / out_h;

    for (int32_t dy = 0; dy < out_h; ++dy) {
        int32_t sy = std::min(sh - 1,
                              static_cast<int32_t>(dy * y_ratio));
        for (int32_t dx = 0; dx < out_w; ++dx) {
            int32_t sx = std::min(sw - 1,
                                  static_cast<int32_t>(dx * x_ratio));
            const uint8_t* src = decoded.scanline(sy);
            uint8_t* dst = sample.pixels.data() +
                           (static_cast<int64_t>(dy) * out_w + dx) * ch;
            std::memcpy(dst, src + sx * ch,
                        static_cast<size_t>(ch));
        }
    }

    return sample;
}

/* ── Metrics computation ────────────────────────────────────────────── */

ImageClassifier::ClassificationMetrics
ImageClassifier::computeMetrics(const DecodedImage& decoded)
{
    ClassificationMetrics m;

    if (!decoded.decoded || decoded.width <= 0 ||
        decoded.height <= 0 || decoded.channels < 1) {
        return m;
    }

    /* Downsample for speed */
    DecodedImage sample = downscale(decoded, 256);
    int32_t sw = sample.width;
    int32_t sh = sample.height;
    int32_t ch = sample.channels;

    m.sample_width = sw;
    m.sample_height = sh;

    int64_t total_pixels = static_cast<int64_t>(sw) * sh;
    if (total_pixels == 0) return m;

    /* ── Distinct color count (RGB channels only) ── */
    std::unordered_set<uint32_t> colors;
    colors.reserve(static_cast<size_t>(
        std::min(total_pixels, static_cast<int64_t>(65536))));

    /* ── Grayscale check ── */
    bool any_non_gray = false;

    /* ── Luma accumulators ── */
    double luma_sum = 0.0;
    double luma_sq_sum = 0.0;
    int64_t luma_count = 0;

    /* ── Near-white count (R,G,B all >= 245) ── */
    int64_t near_white_count = 0;

    /* ── Flat-color count (adjacent horizontal diff < 3) ── */
    int64_t flat_h_count = 0;
    int64_t flat_pair_count = 0;

    /* ── Edge count (simple horizontal + vertical gradient) ── */
    int64_t edge_count = 0;

    for (int32_t y = 0; y < sh; ++y) {
        const uint8_t* row = sample.scanline(y);
        const uint8_t* prev_row = (y > 0)
            ? sample.scanline(y - 1) : nullptr;

        for (int32_t x = 0; x < sw; ++x) {
            int64_t off = static_cast<int64_t>(x) * ch;

            uint8_t r = row[off + 0];
            uint8_t g = (ch >= 3) ? row[off + 1] : r;
            uint8_t b = (ch >= 3) ? row[off + 2] : r;

            /* Distinct colors */
            colors.insert(quantizeColor(r, g, b));

            /* Grayscale check: only first few thousand pixels */
            if (!any_non_gray && luma_count < 10000) {
                if (r != g || g != b) any_non_gray = true;
            }

            /* Luma (BT.601) */
            double luma = 0.299 * r + 0.587 * g + 0.114 * b;
            luma_sum += luma;
            luma_sq_sum += luma * luma;
            ++luma_count;

            /* Near-white */
            if (r >= 245 && g >= 245 && b >= 245) {
                ++near_white_count;
            }

            /* Horizontal flat check */
            if (x > 0) {
                const uint8_t* prev_px = row + (off - ch);
                int32_t diff = 0;
                for (int32_t c = 0; c < ch; ++c) {
                    diff += std::abs(
                        static_cast<int>(row[off + c]) -
                        static_cast<int>(prev_px[c]));
                }
                if (diff < 3) ++flat_h_count;
                ++flat_pair_count;
            }

            /* Vertical flat check for edges */
            if (prev_row) {
                int32_t vdiff = 0;
                for (int32_t c = 0; c < ch; ++c) {
                    vdiff += std::abs(
                        static_cast<int>(row[off + c]) -
                        static_cast<int>(prev_row[off + c]));
                }
                if (vdiff > 30) {
                    ++edge_count;
                }
            }

            /* Also count horizontal edges */
            if (x > 0) {
                const uint8_t* prev_px = row + (off - ch);
                int32_t hdiff = 0;
                for (int32_t c = 0; c < ch; ++c) {
                    hdiff += std::abs(
                        static_cast<int>(row[off + c]) -
                        static_cast<int>(prev_px[c]));
                }
                if (hdiff > 30) {
                    ++edge_count;
                }
            }
        }
    }

    m.distinct_colors = static_cast<int32_t>(
        std::min(colors.size(),
                 static_cast<size_t>(INT32_MAX)));

    m.is_grayscale = !any_non_gray;

    if (luma_count > 0) {
        m.luma_mean = luma_sum / luma_count;
        double variance = (luma_sq_sum / luma_count) -
                          (m.luma_mean * m.luma_mean);
        m.luma_variance = std::max(0.0, variance);
    }

    m.near_white_fraction = static_cast<double>(near_white_count) /
                            total_pixels;

    m.flat_color_fraction = (flat_pair_count > 0)
        ? static_cast<double>(flat_h_count) / flat_pair_count
        : 0.0;

    /* Edge density: count pixels where at least one gradient > 30,
     * divided by total (double-counted but normalized). */
    m.edge_density = static_cast<double>(edge_count) /
                     std::max(static_cast<int64_t>(1),
                              total_pixels * 2);

    return m;
}

/* ── Classification ───────────────────────────────────────────────── */

ImageClassifier::EncodingRecommendation
ImageClassifier::classify(const DecodedImage& decoded)
{
    EncodingRecommendation rec;
    ClassificationMetrics m = computeMetrics(decoded);

    if (m.sample_width <= 0 || m.sample_height <= 0) {
        rec.confidence = 0.0f;
        return rec;
    }

    /* ── Rule 1: Monochrome (grayscale, effectively 1-bit) ── */
    if (m.is_grayscale && m.distinct_colors <= 16 &&
        m.luma_variance < 50.0) {
        rec.format = EncodingRecommendation::OutputFormat::preserve;
        rec.use_grayscale = true;
        rec.suggested_quality = 80;
        rec.confidence = 0.95f;
        rec.chroma = EncodingRecommendation::ChromaSubsampling::cs444;
        return rec;
    }

    /* ── Rule 2: Line art (very few colors) ── */
    if (m.distinct_colors <= 10) {
        rec.format = EncodingRecommendation::OutputFormat::flate_png;
        rec.use_grayscale = m.is_grayscale;
        rec.suggested_quality = 100;
        rec.confidence = 0.95f;
        rec.chroma = EncodingRecommendation::ChromaSubsampling::cs444;
        return rec;
    }

    /* ── Rule 3: Scanned text ── */
    /*    Few distinct colors, high edge density, many near-white pixels */
    bool text_color_profile = (m.distinct_colors < 50) &&
                              (m.near_white_fraction > 0.40);
    bool text_edge_profile = (m.edge_density > 0.15);

    if (text_color_profile && text_edge_profile) {
        /* Use JPEG 4:4:4 to preserve sharp text edges */
        rec.format = EncodingRecommendation::OutputFormat::jpeg;
        rec.chroma = EncodingRecommendation::ChromaSubsampling::cs444;
        rec.use_grayscale = m.is_grayscale;
        rec.suggested_quality = 90;
        rec.confidence = 0.85f;
        return rec;
    }

    /* ── Rule 4: Screenshot / UI ── */
    /*    Flat color regions dominate, sharp edges, moderate colors */
    if (m.flat_color_fraction > 0.30 && m.edge_density > 0.08) {
        rec.format = EncodingRecommendation::OutputFormat::flate_png;
        rec.use_grayscale = m.is_grayscale;
        rec.suggested_quality = 100;
        rec.confidence = 0.85f;
        rec.chroma = EncodingRecommendation::ChromaSubsampling::cs444;
        return rec;
    }

    /* ── Rule 5: Photograph ── */
    /*    High luma variance, many distinct colors, smooth gradients */
    if (m.distinct_colors > 1000 && m.luma_variance > 500.0 &&
        m.flat_color_fraction < 0.50) {
        rec.format = EncodingRecommendation::OutputFormat::jpeg;
        rec.chroma = EncodingRecommendation::ChromaSubsampling::cs420;
        rec.use_grayscale = m.is_grayscale;
        rec.suggested_quality = 80;
        rec.confidence = 0.90f;
        return rec;
    }

    /* ── Rule 6: Photograph (lower confidence) ── */
    if (m.distinct_colors > 200 && m.luma_variance > 100.0) {
        rec.format = EncodingRecommendation::OutputFormat::jpeg;
        rec.chroma = EncodingRecommendation::ChromaSubsampling::cs420;
        rec.use_grayscale = m.is_grayscale;
        rec.suggested_quality = 75;
        rec.confidence = 0.70f;
        return rec;
    }

    /* ── Fallback: Mixed ── */
    /*    Neither a clear photograph nor a clear non-photo.
     *    Caller should try both and pick the smaller. */
    rec.format = EncodingRecommendation::OutputFormat::jpeg;
    rec.chroma = EncodingRecommendation::ChromaSubsampling::cs420;
    rec.use_grayscale = m.is_grayscale;
    rec.suggested_quality = 75;
    rec.confidence = 0.30f;
    return rec;
}

/* ── Map candidate kind to recommendation ───────────────────────────── */

ImageClassifier::EncodingRecommendation
ImageClassifier::fromCandidateKind(ImageCandidate::Kind kind)
{
    EncodingRecommendation rec;

    switch (kind) {
    case ImageCandidate::Kind::photograph:
        rec.format = EncodingRecommendation::OutputFormat::jpeg;
        rec.chroma = EncodingRecommendation::ChromaSubsampling::cs420;
        rec.suggested_quality = 80;
        rec.confidence = 0.90f;
        break;

    case ImageCandidate::Kind::scanned_text:
        rec.format = EncodingRecommendation::OutputFormat::jpeg;
        rec.chroma = EncodingRecommendation::ChromaSubsampling::cs444;
        rec.suggested_quality = 90;
        rec.confidence = 0.85f;
        break;

    case ImageCandidate::Kind::screenshot:
    case ImageCandidate::Kind::line_art:
        rec.format = EncodingRecommendation::OutputFormat::flate_png;
        rec.chroma = EncodingRecommendation::ChromaSubsampling::cs444;
        rec.suggested_quality = 100;
        rec.confidence = 0.90f;
        break;

    case ImageCandidate::Kind::monochrome:
        rec.format = EncodingRecommendation::OutputFormat::preserve;
        rec.use_grayscale = true;
        rec.suggested_quality = 80;
        rec.confidence = 0.90f;
        break;

    case ImageCandidate::Kind::mixed:
    case ImageCandidate::Kind::unknown:
    default:
        /* Low confidence — caller should try both formats */
        rec.format = EncodingRecommendation::OutputFormat::jpeg;
        rec.chroma = EncodingRecommendation::ChromaSubsampling::cs420;
        rec.suggested_quality = 75;
        rec.confidence = 0.30f;
        break;
    }

    return rec;
}
