#ifndef IMAGE_CLASSIFIER_H
#define IMAGE_CLASSIFIER_H

#include <cstdint>
#include <string>

#include "image_decoder.h"

class ImageClassifier {
public:
    struct EncodingRecommendation {
        enum class OutputFormat : uint8_t {
            jpeg,
            flate_png,
            preserve,
        };

        enum class ChromaSubsampling : uint8_t {
            cs444,
            cs420,
        };

        OutputFormat format;
        ChromaSubsampling chroma;
        bool use_grayscale;
        int suggested_quality;
        float confidence;

        EncodingRecommendation()
            : format(OutputFormat::jpeg),
              chroma(ChromaSubsampling::cs420),
              use_grayscale(false),
              suggested_quality(75),
              confidence(0.5f) {}
    };

    struct ClassificationMetrics {
        int32_t distinct_colors;
        double luma_mean;
        double luma_variance;
        double edge_density;         // fraction of pixels on edges [0,1]
        double near_white_fraction;  // fraction of near-white pixels [0,1]
        double flat_color_fraction;  // fraction of pixels in flat regions [0,1]
        double chroma_edge_strength; // mean chroma change on luma edges
        bool is_grayscale;
        int32_t sample_width;
        int32_t sample_height;

        ClassificationMetrics()
            : distinct_colors(0), luma_mean(0.0),
              luma_variance(0.0), edge_density(0.0),
              near_white_fraction(0.0), flat_color_fraction(0.0),
              chroma_edge_strength(0.0), is_grayscale(false),
              sample_width(0), sample_height(0) {}
    };

    /* Classify a decoded image and return an encoding recommendation.
     * Uses a downscaled sample for speed (~1 ms budget). */
    static EncodingRecommendation classify(
        const DecodedImage& decoded);

    /* Compute raw classification metrics on a downscaled sample. */
    static ClassificationMetrics computeMetrics(
        const DecodedImage& decoded);

    /* Map ImageCandidate::Kind to an EncodingRecommendation. */
    static EncodingRecommendation fromCandidateKind(
        ImageCandidate::Kind kind);

private:
    /* Quantize a pixel to a 15-bit color (5 bits per channel)
     * for the distinct-color count. */
    static uint32_t quantizeColor(uint8_t r, uint8_t g, uint8_t b);

    /* Create a downscaled version of the decoded image. */
    static DecodedImage downscale(
        const DecodedImage& decoded,
        int32_t max_sample_dim);
};

#endif /* IMAGE_CLASSIFIER_H */
