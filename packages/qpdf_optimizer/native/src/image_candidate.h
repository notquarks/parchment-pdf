#ifndef IMAGE_CANDIDATE_H
#define IMAGE_CANDIDATE_H

#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

constexpr int kMaxPlacements = 32;
constexpr int kMaxFormDepth = 16;
constexpr int kMaxImageCandidates = 10000;
constexpr int kMaxTotalPlacements = 50000;

enum class ImageColorModel : uint8_t {
    unknown = 0,
    gray,
    rgb,
    cmyk,
    indexed,
};

enum class ImageSkipReason : uint8_t {
    none = 0,
    image_mask,
    inline_image,
    unsupported_color_space,
    unsupported_components,
    unsupported_filter,
    unsupported_bit_depth,
    no_placement,
};

inline const char* imageSkipReasonName(ImageSkipReason reason)
{
    switch (reason) {
    case ImageSkipReason::none: return "none";
    case ImageSkipReason::image_mask: return "image_mask";
    case ImageSkipReason::inline_image: return "inline_image";
    case ImageSkipReason::unsupported_color_space: return "unsupported_color_space";
    case ImageSkipReason::unsupported_components: return "unsupported_components";
    case ImageSkipReason::unsupported_filter: return "unsupported_filter";
    case ImageSkipReason::unsupported_bit_depth: return "unsupported_bit_depth";
    case ImageSkipReason::no_placement: return "no_placement";
    }
    return "unknown";
}

struct ImagePlacement {
    int32_t page_index;
    int32_t form_depth;
    int32_t form_object_number;
    int32_t object_number;
    int32_t generation;
    std::string resource_name;
    double matrix[6];
    double displayed_width_pts;
    double displayed_height_pts;
    double horizontal_dpi;
    double vertical_dpi;
    double effective_dpi;

    ImagePlacement()
        : page_index(0), form_depth(0), form_object_number(0),
          object_number(0), generation(0), displayed_width_pts(0),
          displayed_height_pts(0), horizontal_dpi(0), vertical_dpi(0),
          effective_dpi(0) {
        std::memset(matrix, 0, sizeof(matrix));
    }
};

struct ImageCandidate {
    int32_t object_number;
    int32_t generation;
    std::string resource_name;
    int32_t width;
    int32_t height;
    int32_t bits_per_component;
    std::string color_space;
    ImageColorModel color_model;
    int32_t color_components;
    std::string filter;
    bool has_generalized_filter_wrappers;
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
    ImageSkipReason skip_reason;

    ImageCandidate()
        : object_number(0), generation(0), width(0), height(0),
          bits_per_component(8), color_model(ImageColorModel::unknown),
          color_components(0), has_generalized_filter_wrappers(false),
          has_smask(false), is_inline(false), is_image_mask(false),
          encoded_bytes(0), max_effective_dpi(0), required_width(0),
          required_height(0), kind(Kind::unknown), processable(false),
          skip_reason(ImageSkipReason::none) {}
};

struct AnalysisResult {
    int32_t page_count;
    int64_t file_bytes;
    int32_t image_count;
    int32_t placement_count;
    int32_t high_dpi_count;
    int32_t pages_with_resources;
    int32_t xobject_dictionaries;
    int32_t image_xobjects_seen;
    int32_t form_xobjects_seen;
    int64_t total_image_bytes;
    bool is_encrypted;
    bool has_signatures;
    std::vector<ImageCandidate> images;

    AnalysisResult()
        : page_count(0), file_bytes(0), image_count(0), placement_count(0),
          high_dpi_count(0), pages_with_resources(0), xobject_dictionaries(0),
          image_xobjects_seen(0), form_xobjects_seen(0), total_image_bytes(0),
          is_encrypted(false), has_signatures(false) {}
};

#endif
