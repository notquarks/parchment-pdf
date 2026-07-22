#include "content_interpreter.h"

#include <cmath>
#include <cstring>
#include <limits>
#include <sstream>

#include <qpdf/QPDFObjectHandle.hh>

/* ── Utilities ───────────────────────────────────────────────────────── */

bool parseDouble(const std::string& s, double& out)
{
    if (s.empty()) return false;
    char* end = nullptr;
    out = std::strtod(s.c_str(), &end);
    return end != s.c_str() && *end == '\0' &&
           std::isfinite(out);
}

bool parseCM(
    const std::vector<std::string>& stack,
    double& a, double& b, double& c,
    double& d, double& e, double& f)
{
    if (stack.size() < 6) return false;
    auto it = stack.end();
    --it; f = std::strtod(it->c_str(), nullptr); --it;
    --it; e = std::strtod(it->c_str(), nullptr); --it;
    --it; d = std::strtod(it->c_str(), nullptr); --it;
    --it; c = std::strtod(it->c_str(), nullptr); --it;
    --it; b = std::strtod(it->c_str(), nullptr); --it;
    --it; a = std::strtod(it->c_str(), nullptr);
    return std::isfinite(a) && std::isfinite(b) && std::isfinite(c) &&
           std::isfinite(d) && std::isfinite(e) && std::isfinite(f);
}

/* ── GraphicsState ────────────────────────────────────────────────────── */

GraphicsState::GraphicsState()
{
    ctm[0] = 1; ctm[1] = 0;
    ctm[2] = 0; ctm[3] = 1;
    ctm[4] = 0; ctm[5] = 0;
}

void GraphicsState::push(const GraphicsState& parent)
{
    std::memcpy(ctm, parent.ctm, sizeof(ctm));
}

void GraphicsState::multiplyMatrix(const double m[6])
{
    double r[6];
    r[0] = m[0]*ctm[0] + m[1]*ctm[2];
    r[1] = m[0]*ctm[1] + m[1]*ctm[3];
    r[2] = m[2]*ctm[0] + m[3]*ctm[2];
    r[3] = m[2]*ctm[1] + m[3]*ctm[3];
    r[4] = m[4]*ctm[0] + m[5]*ctm[2] + ctm[4];
    r[5] = m[4]*ctm[1] + m[5]*ctm[3] + ctm[5];
    std::memcpy(ctm, r, sizeof(ctm));
}

void GraphicsState::concatCTM(
    double a, double b, double c, double d, double e, double f)
{
    double m[6] = {a, b, c, d, e, f};
    multiplyMatrix(m);
}

void GraphicsState::getTransformedSize(
    double& width_pts, double& height_pts,
    double img_w, double img_h) const
{
    width_pts  = std::sqrt(ctm[0]*ctm[0] + ctm[1]*ctm[1]) * img_w;
    height_pts = std::sqrt(ctm[2]*ctm[2] + ctm[3]*ctm[3]) * img_h;
}

/* ── ContentInterpreter ──────────────────────────────────────────────── */

ContentInterpreter::ContentInterpreter(
    QPDF& qpdf,
    int32_t page_index,
    int32_t form_object_number,
    int32_t form_depth,
    const ImagePlacementCallback& callback)
    : qpdf_(qpdf),
      page_index_(page_index),
      form_object_number_(form_object_number),
      form_depth_(form_depth),
      callback_(callback),
      visited_(nullptr)
{
    gstack_.emplace_back();
}

void ContentInterpreter::setVisited(std::unordered_set<int32_t>* visited)
{
    visited_ = visited;
}

void ContentInterpreter::pushState()
{
    gstack_.push_back(gstack_.back());
}

void ContentInterpreter::popState()
{
    if (gstack_.size() > 1) {
        gstack_.pop_back();
    }
}

GraphicsState& ContentInterpreter::current()
{
    return gstack_.back();
}

void ContentInterpreter::interpret(QPDFObjectHandle content)
{
    if (!content.isStream()) return;



    std::vector<std::string> operand_stack;

    auto parse_cb = [&](QPDFObjectHandle::Token const& token) {
        auto const& val = token.value;

        if (token.type == QPDFObjectHandle::Token::tt_operator) {
            if (val == "q") {
                pushState();
            } else if (val == "Q") {
                popState();
            } else if (val == "cm" && operand_stack.size() >= 6) {
                double a,b,c,d,e,f;
                if (parseCM(operand_stack, a, b, c, d, e, f)) {
                    current().concatCTM(a, b, c, d, e, f);
                }
                operand_stack.clear();
            } else if (val == "Do" && !operand_stack.empty()) {
                handleDo(operand_stack.back());
                operand_stack.clear();
            } else if (val == "BI") {
                handleInlineImage(token);
                operand_stack.clear();
            } else {
                operand_stack.clear();
            }
        } else if (token.type == QPDFObjectHandle::Token::tt_integer ||
                   token.type == QPDFObjectHandle::Token::tt_real) {
            operand_stack.push_back(val);
        } else if (token.type == QPDFObjectHandle::Token::tt_name) {
            operand_stack.push_back(val);
        } else if (token.type == QPDFObjectHandle::Token::tt_start_array ||
                   token.type == QPDFObjectHandle::Token::tt_start_dictionary) {
            operand_stack.clear();
        }
    };

    try {
        QPDFObjectHandle::parseContentStream(content, parse_cb);
    } catch (...) {}
}

void ContentInterpreter::interpretArray(QPDFObjectHandle contents_array)
{
    if (!contents_array.isArray()) return;
    auto count = contents_array.getArrayNItems();
    for (decltype(count) i = 0; i < count; ++i) {
        auto item = contents_array.getArrayItem(i);
        if (item.isStream()) {
            interpret(item);
        }
    }
}

void ContentInterpreter::handleDo(const std::string& name)
{
    if (name.empty() || name[0] != '/') return;
    auto xname = name.substr(1);

    auto xobjects = resources_.getKey("/XObject");
    if (xobjects.isNull() || !xobjects.isDictionary()) return;

    auto xobj = xobjects.getKey("/" + xname);
    if (xobj.isNull()) return;

    if (xobj.isIndirect()) {
        xobj = xobj.dereference();
    }

    if (xobj.isNull() || !xobj.isDictionary()) return;

    auto type = xobj.getKey("/Type");
    auto subtype = xobj.getKey("/Subtype");

    if (subtype.isNull()) return;
    auto subtype_name = subtype.getName();
    if (subtype_name.empty()) return;

    if (subtype_name == "Image") {
        processImageXObject(xobj, xname);
    } else if (subtype_name == "Form") {
        processFormXObject(xobj);
    }
}

void ContentInterpreter::handleInlineImage(
    QPDFObjectHandle::Token const& /* bi_token */)
{
}

void ContentInterpreter::processImageXObject(
    QPDFObjectHandle image,
    const std::string& resource_name)
{
    auto w = image.getKey("/Width");
    auto h = image.getKey("/Height");
    if (w.isNull() || h.isNull()) return;

    int32_t img_w = 0, img_h = 0;
    try {
        img_w = w.getIntValueAsInt();
        img_h = h.getIntValueAsInt();
    } catch (...) { return; }

    if (img_w <= 0 || img_h <= 0) return;
    if (img_w > 65535 || img_h > 65535) return;

    double display_w_pts = 0, display_h_pts = 0;
    current().getTransformedSize(display_w_pts, display_h_pts, img_w, img_h);

    if (display_w_pts <= 0 || display_h_pts <= 0) return;

    double h_dpi = img_w * 72.0 / display_w_pts;
    double v_dpi = img_h * 72.0 / display_h_pts;
    double max_dpi = (h_dpi > v_dpi) ? h_dpi : v_dpi;

    ImagePlacement placement;
    placement.page_index = page_index_;
    placement.form_depth = form_depth_;
    placement.form_object_number = form_object_number_;
    std::memcpy(placement.matrix, current().ctm, sizeof(placement.matrix));
    placement.displayed_width_pts = display_w_pts;
    placement.displayed_height_pts = display_h_pts;
    placement.effective_dpi = max_dpi;

    int32_t obj_num = 0;
    int32_t gen = 0;
    if (image.isIndirect()) {
        obj_num = image.getObjectGenerationNumber();
        gen = image.getGeneration();
    }

    callback_(placement);
    (void)obj_num;
    (void)gen;
}

void ContentInterpreter::processFormXObject(QPDFObjectHandle form)
{
    if (form_depth_ >= kMaxFormDepth) return;
    int32_t form_obj = form.isIndirect()
        ? form.getObjectGenerationNumber() : 0;
    if (form_obj > 0 && visited_) {
        if (visited_->count(form_obj)) return;
        visited_->insert(form_obj);
    }

    auto child_resources = form.getKey("/Resources");
    if (child_resources.isNull()) child_resources = resources_;

    ContentInterpreter child(
        qpdf_, page_index_, form_obj, form_depth_ + 1, callback_);
    child.resources_ = child_resources;
    if (visited_) child.setVisited(visited_);

    auto matrix = form.getKey("/Matrix");
    if (matrix.isArray() && matrix.getArrayNItems() == 6) {
        double m[6];
        for (int i = 0; i < 6; ++i) {
            auto item = matrix.getArrayItem(i);
            m[i] = item.isNull() ? 0 : item.getNumericValue();
        }
        child.current().multiplyMatrix(m);
    }

    auto contents = form.getKey("/Contents");
    if (!contents.isNull()) {
        if (contents.isStream()) {
            child.interpret(contents);
        } else if (contents.isArray()) {
            child.interpretArray(contents);
        }
    }
}

/* ── Resource resolution ──────────────────────────────────────────────── */

QPDFObjectHandle ContentInterpreter::resolveResources(
    QPDFObjectHandle xobject)
{
    auto r = xobject.getKey("/Resources");
    if (!r.isNull() && r.isDictionary()) return r;
    return resources_;
}
