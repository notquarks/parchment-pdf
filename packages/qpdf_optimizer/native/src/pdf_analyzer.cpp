#include "pdf_analyzer.h"

#include <algorithm>
#include <exception>
#include <cmath>
#include <unordered_map>
#include <unordered_set>

#include <qpdf/Buffer.hh>
#include <qpdf/QPDFPageObjectHelper.hh>

#include "content_interpreter.h"
#include "pdf_name_utils.h"

namespace
{

    struct ColorInfo
    {
        std::string name;
        ImageColorModel model = ImageColorModel::unknown;
        int32_t components = 0;
    };

    ColorInfo resolveColorInfo(QPDFObjectHandle color_space)
    {
        ColorInfo info;
        if (color_space.isName())
        {
            info.name = pdfName(color_space);
            if (info.name == "DeviceGray")
            {
                info.model = ImageColorModel::gray;
                info.components = 1;
            }
            else if (info.name == "DeviceRGB")
            {
                info.model = ImageColorModel::rgb;
                info.components = 3;
            }
            else if (info.name == "DeviceCMYK")
            {
                info.model = ImageColorModel::cmyk;
                info.components = 4;
            }
            return info;
        }

        if (!color_space.isArray() || color_space.getArrayNItems() == 0)
        {
            return info;
        }

        info.name = pdfName(color_space.getArrayItem(0));
        if (info.name == "ICCBased" && color_space.getArrayNItems() > 1)
        {
            auto profile = color_space.getArrayItem(1);
            if (profile.isStream())
            {
                auto component_count = profile.getDict().getKey("/N");
                if (component_count.isInteger())
                {
                    info.components = component_count.getIntValueAsInt();
                    if (info.components == 1)
                    {
                        info.model = ImageColorModel::gray;
                    }
                    else if (info.components == 3)
                    {
                        info.model = ImageColorModel::rgb;
                    }
                    else if (info.components == 4)
                    {
                        info.model = ImageColorModel::cmyk;
                    }
                }
            }
        }
        else if (info.name == "Indexed" || info.name == "I")
        {
            info.model = ImageColorModel::indexed;
            info.components = 1;
        }
        return info;
    }

    double pageUserUnit(QPDFPageObjectHelper &helper)
    {
        auto value = helper.getAttribute("/UserUnit", false);
        if (!value.isNumber())
        {
            return 1.0;
        }
        double user_unit = value.getNumericValue();
        return std::isfinite(user_unit) && user_unit > 0 ? user_unit : 1.0;
    }

    void addPlacements(
        ImageCandidate &candidate,
        const std::vector<ImagePlacement> &placements)
    {
        if (placements.empty() || candidate.placements.size() >= kMaxPlacements)
        {
            return;
        }
        auto remaining = static_cast<size_t>(kMaxPlacements) - candidate.placements.size();
        auto count = std::min(remaining, placements.size());
        candidate.placements.insert(
            candidate.placements.end(), placements.begin(), placements.begin() + count);
    }

    void collectImage(
        QPDFObjectHandle image,
        const std::string &resource_name,
        AnalysisResult &result,
        std::unordered_map<uint64_t, size_t> &image_index,
        const std::unordered_map<uint64_t, std::vector<ImagePlacement>> &placements_by_image,
        std::unordered_set<uint64_t> &placements_attached)
    {
        if (!image.isStream())
        {
            return;
        }

        auto key = pdfObjectKey(image);
        if (key == 0)
        {
            return;
        }

        auto existing = image_index.find(key);
        if (existing != image_index.end())
        {
            auto &candidate = result.images[existing->second];
            if (candidate.resource_name.empty())
            {
                candidate.resource_name = normalizePdfName(resource_name);
            }
            if (placements_attached.insert(key).second)
            {
                auto placement_it = placements_by_image.find(key);
                if (placement_it != placements_by_image.end())
                {
                    addPlacements(candidate, placement_it->second);
                }
            }
            return;
        }

        auto dictionary = image.getDict();
        auto width = dictionary.getKey("/Width");
        auto height = dictionary.getKey("/Height");
        if (!width.isInteger() || !height.isInteger())
        {
            return;
        }

        ImageCandidate candidate;
        candidate.object_number = image.getObjectID();
        candidate.generation = image.getGeneration();
        candidate.resource_name = normalizePdfName(resource_name);
        candidate.width = width.getIntValueAsInt();
        candidate.height = height.getIntValueAsInt();
        if (candidate.width <= 0 || candidate.height <= 0)
        {
            return;
        }

        auto bits = dictionary.getKey("/BitsPerComponent");
        if (bits.isInteger())
        {
            candidate.bits_per_component = bits.getIntValueAsInt();
        }

        auto color = resolveColorInfo(dictionary.getKey("/ColorSpace"));
        candidate.color_space = color.name;
        candidate.color_model = color.model;
        candidate.color_components = color.components;

        auto filter = imageFilterInfo(dictionary.getKey("/Filter"));
        candidate.filter = filter.terminal;
        candidate.has_generalized_filter_wrappers = filter.generalized_wrappers;
        if (!filter.supported)
        {
            candidate.filter = "UnsupportedFilterChain";
        }

        auto mask = dictionary.getKey("/ImageMask");
        candidate.is_image_mask = mask.isBool() && mask.getBoolValue();
        candidate.has_smask = !dictionary.getKey("/SMask").isNull();

        try
        {
            auto raw = image.getRawStreamData();
            if (raw)
            {
                candidate.encoded_bytes = static_cast<int64_t>(raw->getSize());
            }
        }
        catch (...)
        {
        }

        auto placement_it = placements_by_image.find(key);
        if (placement_it != placements_by_image.end())
        {
            addPlacements(candidate, placement_it->second);
            placements_attached.insert(key);
        }

        image_index.emplace(key, result.images.size());
        result.images.push_back(std::move(candidate));
    }

    void scanResources(
        QPDFObjectHandle resources,
        AnalysisResult &result,
        std::unordered_map<uint64_t, size_t> &image_index,
        const std::unordered_map<uint64_t, std::vector<ImagePlacement>> &placements_by_image,
        std::unordered_set<uint64_t> &placements_attached,
        std::unordered_set<uint64_t> &active_forms)
    {
        if (!resources.isDictionary())
        {
            return;
        }

        auto xobjects = resources.getKey("/XObject");
        if (!xobjects.isDictionary())
        {
            return;
        }
        ++result.xobject_dictionaries;

        for (auto const &[resource_name, value] : xobjects.getDictAsMap())
        {
            auto object = value;
            if (!object.isStream())
            {
                continue;
            }

            auto dictionary = object.getDict();
            auto subtype = pdfName(dictionary.getKey("/Subtype"));
            if (subtype == "Image")
            {
                ++result.image_xobjects_seen;
                collectImage(
                    object,
                    resource_name,
                    result,
                    image_index,
                    placements_by_image,
                    placements_attached);
                continue;
            }

            if (subtype != "Form")
            {
                continue;
            }

            ++result.form_xobjects_seen;
            auto form_key = pdfObjectKey(object);
            if (form_key != 0 && !active_forms.insert(form_key).second)
            {
                continue;
            }

            auto form_resources = dictionary.getKey("/Resources");
            if (form_resources.isNull())
            {
                form_resources = resources;
            }
            scanResources(
                form_resources,
                result,
                image_index,
                placements_by_image,
                placements_attached,
                active_forms);

            if (form_key != 0)
            {
                active_forms.erase(form_key);
            }
        }
    }

} // namespace

bool PdfAnalyzer::analyze(
    QPDF &qpdf,
    int32_t target_dpi,
    int32_t dpi_threshold,
    AnalysisResult &result,
    std::string &error,
    std::atomic<bool> *cancelled,
    const std::function<void(int32_t, int32_t)> &progress)
{
    try
    {
        result = AnalysisResult();
        result.page_count = static_cast<int32_t>(qpdf.getAllPages().size());
        checkDocumentProperties(qpdf, result);

        ImageIndexMap image_index;
        auto pages = qpdf.getAllPages();
        auto total_pages = static_cast<int32_t>(pages.size());
        int32_t page_index = 0;
        for (auto const &page : pages)
        {
            if (cancelled && cancelled->load(std::memory_order_acquire))
            {
                error = "cancelled";
                return false;
            }
            if (result.images.size() >= kMaxImageCandidates)
            {
                break;
            }
            processPage(qpdf, page, page_index, result, image_index);
            ++page_index;
            if (progress)
            {
                progress(page_index, total_pages);
            }
        }

        finalize(result, target_dpi, dpi_threshold);
        return true;
    }
    catch (std::exception const &exception)
    {
        error = std::string("Analysis failed: ") + exception.what();
        return false;
    }
    catch (...)
    {
        error = "Analysis failed with unknown error";
        return false;
    }
}

void PdfAnalyzer::checkDocumentProperties(QPDF &qpdf, AnalysisResult &result)
{
    result.is_encrypted = qpdf.isEncrypted();
    result.has_signatures = false;

    try
    {
        auto root = qpdf.getTrailer().getKey("/Root");
        auto acroform = root.getKey("/AcroForm");
        auto fields = acroform.getKey("/Fields");
        if (!fields.isArray())
        {
            return;
        }
        auto count = fields.getArrayNItems();
        for (decltype(count) i = 0; i < count; ++i)
        {
            auto field = fields.getArrayItem(i);
            if (field.isDictionary() && pdfName(field.getKey("/FT")) == "Sig")
            {
                result.has_signatures = true;
                return;
            }
        }
    }
    catch (...)
    {
    }
}

const char *PdfAnalyzer::buildId()
{
    return "stream-dict";
}

void PdfAnalyzer::processPage(
    QPDF &qpdf,
    QPDFObjectHandle page,
    int32_t page_index,
    AnalysisResult &result,
    ImageIndexMap &image_index)
{
    QPDFPageObjectHelper helper(page);
    auto resources = helper.getAttribute("/Resources", false);

    std::unordered_map<uint64_t, std::vector<ImagePlacement>> placements_by_image;
    if (resources.isDictionary())
    {
        ++result.pages_with_resources;
        std::unordered_set<uint64_t> active_forms;
        ContentInterpreter interpreter(
            qpdf, page_index, 0, 0, pageUserUnit(helper),
            [&](const ImagePlacement &placement)
            {
                auto key = pdfObjectKey(
                    placement.object_number, placement.generation);
                if (key == 0 || result.placement_count >= kMaxTotalPlacements)
                {
                    return;
                }
                placements_by_image[key].push_back(placement);
                ++result.placement_count;
            });
        interpreter.setResources(resources);
        interpreter.setActiveForms(&active_forms);
        interpreter.interpretPage(page);
    }

    std::unordered_set<uint64_t> placements_attached;
    std::unordered_set<uint64_t> active_forms;
    scanResources(
        resources,
        result,
        image_index,
        placements_by_image,
        placements_attached,
        active_forms);
}

void PdfAnalyzer::finalize(
    AnalysisResult &result,
    int32_t target_dpi,
    int32_t dpi_threshold)
{
    result.image_count = static_cast<int32_t>(result.images.size());
    result.high_dpi_count = 0;
    result.total_image_bytes = 0;
    result.placement_count = 0;

    for (auto &candidate : result.images)
    {
        result.total_image_bytes += candidate.encoded_bytes;
        result.placement_count +=
            static_cast<int32_t>(candidate.placements.size());

        candidate.max_effective_dpi = 0;
        int32_t required_width = 0;
        int32_t required_height = 0;
        for (auto const &placement : candidate.placements)
        {
            candidate.max_effective_dpi = std::max(
                candidate.max_effective_dpi, placement.effective_dpi);
            required_width = std::max(
                required_width,
                static_cast<int32_t>(std::ceil(
                    placement.displayed_width_pts * target_dpi / 72.0)));
            required_height = std::max(
                required_height,
                static_cast<int32_t>(std::ceil(
                    placement.displayed_height_pts * target_dpi / 72.0)));
        }

        candidate.required_width = candidate.placements.empty()
                                       ? candidate.width
                                       : std::clamp(required_width, 1, candidate.width);
        candidate.required_height = candidate.placements.empty()
                                        ? candidate.height
                                        : std::clamp(required_height, 1, candidate.height);

        if (candidate.max_effective_dpi > dpi_threshold)
        {
            ++result.high_dpi_count;
        }

        candidate.processable = false;
        candidate.skip_reason = ImageSkipReason::none;
        if (candidate.is_image_mask)
        {
            candidate.skip_reason = ImageSkipReason::image_mask;
        }
        else if (candidate.is_inline)
        {
            candidate.skip_reason = ImageSkipReason::inline_image;
        }
        else if (candidate.color_model != ImageColorModel::gray &&
                 candidate.color_model != ImageColorModel::rgb)
        {
            candidate.skip_reason = ImageSkipReason::unsupported_color_space;
        }
        else if (candidate.color_components != 1 &&
                 candidate.color_components != 3)
        {
            candidate.skip_reason = ImageSkipReason::unsupported_components;
        }
        else if (candidate.filter != "DCTDecode" &&
                 candidate.filter != "FlateDecode" &&
                 !candidate.filter.empty())
        {
            candidate.skip_reason = ImageSkipReason::unsupported_filter;
        }
        else if (candidate.bits_per_component != 8)
        {
            candidate.skip_reason = ImageSkipReason::unsupported_bit_depth;
        }
        else
        {
            candidate.processable = true;
        }

        if (candidate.bits_per_component == 1 || candidate.is_image_mask)
        {
            candidate.kind = ImageCandidate::Kind::monochrome;
        }
        else if (candidate.color_model == ImageColorModel::gray)
        {
            candidate.kind = ImageCandidate::Kind::scanned_text;
        }
        else if (candidate.max_effective_dpi >= 150 &&
                 static_cast<int64_t>(candidate.width) * candidate.height > 500000)
        {
            candidate.kind = ImageCandidate::Kind::photograph;
        }
        else
        {
            candidate.kind = ImageCandidate::Kind::mixed;
        }
    }
}
