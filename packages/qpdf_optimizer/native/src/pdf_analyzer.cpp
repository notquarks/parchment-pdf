#include "pdf_analyzer.h"

#include <algorithm>
#include <cmath>
#include <cstring>
#include <unordered_map>
#include <unordered_set>

#include <qpdf/QPDF.hh>
#include <qpdf/QPDFPageObjectHelper.hh>

#include "content_interpreter.h"
#include "image_candidate.h"

/* ── PdfAnalyzer ──────────────────────────────────────────────────────── */

bool PdfAnalyzer::analyze(
    QPDF& qpdf,
    int32_t dpi_threshold,
    AnalysisResult& result,
    std::string& error)
{
    try {
        result.page_count =
            static_cast<int32_t>(qpdf.getAllPages().size());
        result.file_bytes = 0;

        checkDocumentProperties(qpdf, result);
        discoverImages(qpdf, result, dpi_threshold);
        finalize(result, dpi_threshold);

        return true;
    } catch (std::exception const& e) {
        error = std::string("Analysis failed: ") + e.what();
        return false;
    } catch (...) {
        error = "Analysis failed with unknown error";
        return false;
    }
}

/* ── Document properties ─────────────────────────────────────────────── */

void PdfAnalyzer::checkDocumentProperties(
    QPDF& qpdf, AnalysisResult& result)
{
    result.is_encrypted = qpdf.isEncrypted();


    result.has_signatures = false;
    try {
        auto trailer = qpdf.getTrailer();
        if (!trailer.isNull()) {
            auto root = trailer.getKey("/Root");
            if (!root.isNull() && root.isDictionary()) {
                auto acroform = root.getKey("/AcroForm");
                if (!acroform.isNull() && acroform.isDictionary()) {
                    auto fields = acroform.getKey("/Fields");
                    if (!fields.isNull() && fields.isArray()) {
                        auto n = fields.getArrayNItems();
                        for (decltype(n) i = 0; i < n && !result.has_signatures; ++i) {
                            auto field = fields.getArrayItem(i);
                            if (field.isNull() || !field.isDictionary()) continue;
                            auto ft = field.getKey("/FT");
                            if (!ft.isNull() && ft.getName() == "Sig") {
                                result.has_signatures = true;
                            }
                        }
                    }
                }
            }
        }
    } catch (...) {}
}

/* ── Image discovery ─────────────────────────────────────────────────── */


using ImageIndexMap = std::unordered_map<int32_t, size_t>;

void PdfAnalyzer::discoverImages(
    QPDF& qpdf,
    AnalysisResult& result,
    int32_t dpi_threshold)
{
    ImageIndexMap obj_index;
    std::unordered_set<int32_t> visited_forms;
    int32_t page_idx = 0;

    auto pages = qpdf.getAllPages();
    for (auto const& page : pages) {
        processPage(qpdf, page, page_idx, dpi_threshold, result);
        ++page_idx;
    }


}

/* ── Page processing ─────────────────────────────────────────────────── */

void PdfAnalyzer::processPage(
    QPDF& qpdf,
    QPDFObjectHandle page,
    int32_t page_index,
    int32_t dpi_threshold,
    AnalysisResult& result)
{

    auto resources = page.getKey("/Resources");
    if (resources.isNull() || !resources.isDictionary()) return;


    auto contents = page.getKey("/Contents");
    if (contents.isNull()) return;


    struct RawPlacement {
        int32_t obj_num;
        int32_t gen;
        std::string resource_name;
        ImagePlacement placement;
    };
    std::vector<RawPlacement> raw_placements;


    auto callback = [&](const ImagePlacement& placement) {
        /* We need the object number — get it from the Do operand.
           The interpreter handles Do but we don't have the object
           reference in the callback.  We'll need to restructure. */

        /* For now, use a simpler approach: scan XObject resources
           directly and compare against placements. */
    };


    std::vector<ImagePlacement> page_placements;
    auto placement_cb = [&](const ImagePlacement& p) {
        page_placements.push_back(p);
    };

    ContentInterpreter ci(qpdf, page_index, 0, 0, placement_cb);
    ci.setVisited(&visited_forms);

    if (contents.isStream()) {
        ci.interpret(contents);
    } else if (contents.isArray()) {
        ci.interpretArray(contents);
    }


    auto xobjects = resources.getKey("/XObject");
    if (xobjects.isNull() || !xobjects.isDictionary()) return;

    auto xobj_dict = xobjects.getDictAsMap();
    for (auto& [name, xobj_handle] : xobj_dict) {
        auto xobj = xobj_handle;
        if (xobj.isIndirect()) xobj = xobj.dereference();
        if (xobj.isNull() || !xobj.isDictionary()) continue;

        auto subtype = xobj.getKey("/Subtype");
        if (subtype.isNull()) continue;
        auto sub_name = subtype.getName();
        if (sub_name != "Image") continue;


        auto w = xobj.getKey("/Width");
        auto h = xobj.getKey("/Height");
        if (w.isNull() || h.isNull()) continue;

        int32_t img_w = 0, img_h = 0;
        try {
            img_w = w.getIntValueAsInt();
            img_h = h.getIntValueAsInt();
        } catch (...) { continue; }
        if (img_w <= 0 || img_h <= 0) continue;


        int32_t obj_num = xobj.isIndirect()
            ? xobj.getObjectGenerationNumber() : 0;
        int32_t gen = xobj.isIndirect() ? xobj.getGeneration() : 0;


        double best_dpi = 72;
        for (auto& p : page_placements) {
            double img_area = img_w * img_h;
            double disp_area = p.displayed_width_pts * p.displayed_height_pts;
            if (disp_area > 0) {
                double implied_w = p.displayed_width_pts * img_w /
                    (p.displayed_width_pts > 0 ? img_w : 1);
                if (p.effective_dpi > best_dpi) {
                    best_dpi = p.effective_dpi;
                }
            }
        }


        int64_t encoded_bytes = 0;
        try {
            auto stream = xobj.getStream();
            encoded_bytes = stream->getSize();
        } catch (...) {}


        auto it = obj_index.find(obj_num);
        if (it != obj_index.end()) {

            auto& cand = result.images[it->second];
            if (best_dpi > cand.max_effective_dpi) {
                cand.max_effective_dpi = best_dpi;
            }
            cand.encoded_bytes += encoded_bytes;
        } else {

            ImageCandidate cand;
            cand.object_number = obj_num;
            cand.generation = gen;
            cand.resource_name = name;
            cand.width = img_w;
            cand.height = img_h;
            cand.encoded_bytes = encoded_bytes;
            cand.max_effective_dpi = best_dpi;


            auto cs = xobj.getKey("/ColorSpace");
            if (!cs.isNull()) {
                if (cs.isName()) {
                    cand.color_space = cs.getName();
                } else if (cs.isArray() && cs.getArrayNItems() > 0) {
                    auto first = cs.getArrayItem(0);
                    if (first.isName()) cand.color_space = first.getName();
                }
            }


            auto filt = xobj.getKey("/Filter");
            if (!filt.isNull()) {
                if (filt.isName()) {
                    cand.filter = filt.getName();
                }
            }


            auto bpc = xobj.getKey("/BitsPerComponent");
            if (!bpc.isNull()) {
                try { cand.bits_per_component = bpc.getIntValueAsInt(); }
                catch (...) {}
            }


            auto smask = xobj.getKey("/SMask");
            cand.has_smask = !smask.isNull();


            auto img_mask = xobj.getKey("/ImageMask");
            cand.is_image_mask = (!img_mask.isNull() &&
                                  img_mask.getIntValue() != 0);


            ImagePlacement p;
            p.page_index = page_index;
            p.form_depth = 0;
            p.form_object_number = 0;
            p.effective_dpi = best_dpi;

            p.displayed_width_pts = img_w * 72.0 / best_dpi;
            p.displayed_height_pts = img_h * 72.0 / best_dpi;
            std::memset(p.matrix, 0, sizeof(p.matrix));
            p.matrix[0] = p.displayed_width_pts / img_w;
            p.matrix[3] = p.displayed_height_pts / img_h;
            cand.placements.push_back(p);

            size_t idx = result.images.size();
            result.images.push_back(cand);
            if (obj_num > 0) obj_index[obj_num] = idx;
        }
    }
}

/* ── Finalize: derived fields, classification, processability ──────────── */

void PdfAnalyzer::finalize(AnalysisResult& result, int32_t dpi_threshold)
{
    result.image_count = static_cast<int32_t>(result.images.size());
    result.placement_count = 0;
    result.high_dpi_count = 0;
    result.total_image_bytes = 0;

    for (auto& cand : result.images) {
        result.placement_count +=
            static_cast<int32_t>(cand.placements.size());
        result.total_image_bytes += cand.encoded_bytes;


        int32_t max_req_w = cand.width;
        int32_t max_req_h = cand.height;
        for (auto& p : cand.placements) {
            int32_t req_w = static_cast<int32_t>(
                std::ceil(cand.width * 72.0 / p.effective_dpi));
            int32_t req_h = static_cast<int32_t>(
                std::ceil(cand.height * 72.0 / p.effective_dpi));
            if (req_w > max_req_w) max_req_w = req_w;
            if (req_h > max_req_h) max_req_h = req_h;
        }

        cand.required_width = std::min(max_req_w, cand.width);
        cand.required_height = std::min(max_req_h, cand.height);


        if (cand.max_effective_dpi > dpi_threshold) {
            result.high_dpi_count++;
        }


        cand.processable = false;
        if (cand.is_image_mask || cand.is_inline) {
            cand.processable = false;
        } else if (cand.filter == "DCTDecode") {
            cand.processable = true;
        } else if (cand.filter == "FlateDecode" || cand.filter.empty()) {

            if ((cand.color_space == "DeviceRGB" ||
                 cand.color_space == "DeviceGray") &&
                cand.bits_per_component == 8) {
                cand.processable = true;
            }
        }

        if (cand.bits_per_component == 1 || cand.is_image_mask) {
            cand.kind = ImageCandidate::Kind::monochrome;
        } else if (cand.color_space == "DeviceGray" &&
                   cand.bits_per_component == 8) {
            cand.kind = ImageCandidate::Kind::scanned_text;
        } else if (cand.color_space == "DeviceRGB" &&
                   cand.bits_per_component == 8) {
            if (cand.max_effective_dpi >= 150 &&
                cand.width * cand.height > 500000) {
                cand.kind = ImageCandidate::Kind::photograph;
            } else {
                cand.kind = ImageCandidate::Kind::mixed;
            }
        } else {
            cand.kind = ImageCandidate::Kind::mixed;
        }
    }
}
