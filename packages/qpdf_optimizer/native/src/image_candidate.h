#ifndef IMAGE_CANDIDATE_H
#define IMAGE_CANDIDATE_H

#include <cstdint>
#include <string>
#include <vector>

constexpr int kMaxPlacements = 32;
constexpr int kMaxFormDepth = 16;
constexpr int kMaxImageCandidates = 10000;
constexpr int kMaxTotalPlacements = 50000;

struct ImagePlacement {
    int32_t page_index;
    int32_t form_depth;
    int32_t form_object_number;
    double matrix[6];
    double displayed_width_pts;
    double displayed_height_pts;
    double effective_dpi;
};

struct ImageCandidate {
    int32_t object_number;
    int32_t generation;
    std::string resource_name;

    int32_t width;
    int32_t height;
    int32_t bits_per_component;
    std::string color_space;
    std::string filter;
    bool has_smask;
    bool is_inline;
    bool is_image_mask;

    int64_t encoded_bytes;

    std::vector<ImagePlacement> placements;

    double max_effective_dpi;
    int32_t required_width;
    int32_t required_height;

    enum class Kind : uint8_t {
        unknown = 0,
        photograph,
        scanned_text,
        screenshot,
        line_art,
        monochrome,
        mixed,
    };
    Kind kind;

    bool processable;

    ImageCandidate()
        : object_number(0), generation(0), width(0), height(0),
          bits_per_component(8), has_smask(false), is_inline(false),
          is_image_mask(false), encoded_bytes(0), max_effective_dpi(72),
          required_width(0), required_height(0), kind(Kind::unknown),
          processable(false) {}
};

struct AnalysisResult {
    int32_t page_count;
    int64_t file_bytes;
    int32_t image_count;
    int32_t placement_count;
    int32_t high_dpi_count;
    int64_t total_image_bytes;
    bool is_encrypted;
    bool has_signatures;

    std::vector<ImageCandidate> images;

    AnalysisResult()
        : page_count(0), file_bytes(0), image_count(0),
          placement_count(0), high_dpi_count(0),
          total_image_bytes(0), is_encrypted(false),
          has_signatures(false) {}
};

#endif /* IMAGE_CANDIDATE_H */
