#include "content_interpreter.h"

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <cstring>

#include <qpdf/QPDFPageObjectHelper.hh>

#include "pdf_name_utils.h"

namespace {

bool parseMatrix(
    const std::vector<std::string>& operands,
    double& a,
    double& b,
    double& c,
    double& d,
    double& e,
    double& f)
{
    if (operands.size() < 6) {
        return false;
    }
    auto offset = operands.size() - 6;
    char* end = nullptr;
    double values[6];
    for (size_t i = 0; i < 6; ++i) {
        end = nullptr;
        values[i] = std::strtod(operands[offset + i].c_str(), &end);
        if (end == operands[offset + i].c_str() || *end != '\0' ||
            !std::isfinite(values[i])) {
            return false;
        }
    }
    a = values[0];
    b = values[1];
    c = values[2];
    d = values[3];
    e = values[4];
    f = values[5];
    return true;
}

class ContentStreamCallback final : public QPDFObjectHandle::ParserCallbacks {
public:
    explicit ContentStreamCallback(ContentInterpreter& interpreter)
        : interpreter_(interpreter) {}

    void handleObject(QPDFObjectHandle object, size_t, size_t) override
    {
        if (object.isOperator()) {
            interpreter_.dispatchOperator(object.getOperatorValue());
        } else if (object.isName()) {
            interpreter_.pushOperand(object.getName());
        } else if (object.isInteger()) {
            interpreter_.pushOperand(std::to_string(object.getIntValue()));
        } else if (object.isReal()) {
            interpreter_.pushOperand(object.getRealValue());
        } else {
            interpreter_.pushOperand(object.unparseResolved());
        }
    }

    void handleEOF() override {}

private:
    ContentInterpreter& interpreter_;
};

} // namespace

GraphicsState::GraphicsState()
{
    ctm[0] = 1;
    ctm[1] = 0;
    ctm[2] = 0;
    ctm[3] = 1;
    ctm[4] = 0;
    ctm[5] = 0;
}

void GraphicsState::multiplyMatrix(const double matrix[6])
{
    double result[6];
    result[0] = matrix[0] * ctm[0] + matrix[1] * ctm[2];
    result[1] = matrix[0] * ctm[1] + matrix[1] * ctm[3];
    result[2] = matrix[2] * ctm[0] + matrix[3] * ctm[2];
    result[3] = matrix[2] * ctm[1] + matrix[3] * ctm[3];
    result[4] = matrix[4] * ctm[0] + matrix[5] * ctm[2] + ctm[4];
    result[5] = matrix[4] * ctm[1] + matrix[5] * ctm[3] + ctm[5];
    std::memcpy(ctm, result, sizeof(ctm));
}

void GraphicsState::concatCTM(
    double a, double b, double c, double d, double e, double f)
{
    double matrix[6] = {a, b, c, d, e, f};
    multiplyMatrix(matrix);
}

void GraphicsState::getTransformedSize(double& width, double& height) const
{
    width = std::hypot(ctm[0], ctm[1]);
    height = std::hypot(ctm[2], ctm[3]);
}

ContentInterpreter::ContentInterpreter(
    QPDF& qpdf,
    int32_t page_index,
    int32_t form_object_number,
    int32_t form_depth,
    double user_unit,
    const ImagePlacementCallback& callback)
    : qpdf_(qpdf), page_index_(page_index),
      form_object_number_(form_object_number), form_depth_(form_depth),
      user_unit_(user_unit > 0 ? user_unit : 1.0), callback_(callback),
      active_forms_(nullptr)
{
    graphics_stack_.emplace_back();
}

void ContentInterpreter::setResources(QPDFObjectHandle resources)
{
    resources_ = resources;
}

void ContentInterpreter::setActiveForms(
    std::unordered_set<uint64_t>* active_forms)
{
    active_forms_ = active_forms;
}

void ContentInterpreter::pushState()
{
    graphics_stack_.push_back(graphics_stack_.back());
}

void ContentInterpreter::popState()
{
    if (graphics_stack_.size() > 1) {
        graphics_stack_.pop_back();
    }
}

GraphicsState& ContentInterpreter::current()
{
    return graphics_stack_.back();
}

void ContentInterpreter::pushOperand(const std::string& value)
{
    operands_.push_back(value);
}

void ContentInterpreter::dispatchOperator(const std::string& op)
{
    if (op == "q") {
        pushState();
    } else if (op == "Q") {
        popState();
    } else if (op == "cm") {
        double a, b, c, d, e, f;
        if (parseMatrix(operands_, a, b, c, d, e, f)) {
            current().concatCTM(a, b, c, d, e, f);
        }
    } else if (op == "Do" && !operands_.empty()) {
        handleDo(operands_.back());
    }
    operands_.clear();
}

void ContentInterpreter::interpretPage(QPDFObjectHandle page)
{
    operands_.clear();
    ContentStreamCallback callback(*this);
    QPDFPageObjectHelper(page).parseContents(&callback);
}

void ContentInterpreter::interpret(QPDFObjectHandle content)
{
    if (!content.isStream()) {
        return;
    }
    operands_.clear();
    ContentStreamCallback callback(*this);
    QPDFObjectHandle::parseContentStream(content, &callback);
}

void ContentInterpreter::handleDo(const std::string& name)
{
    if (name.empty() || resources_.isNull() || !resources_.isDictionary()) {
        return;
    }

    auto xobjects = resources_.getKey("/XObject");
    if (xobjects.isNull() || !xobjects.isDictionary()) {
        return;
    }

    auto key = pdfDictionaryKey(name);
    auto xobject = xobjects.getKey(key);
    if (xobject.isNull() || !xobject.isStream()) {
        return;
    }

    auto dictionary = xobject.getDict();
    auto subtype = pdfName(dictionary.getKey("/Subtype"));
    if (subtype == "Image") {
        processImageXObject(xobject, normalizePdfName(key));
    } else if (subtype == "Form") {
        processFormXObject(xobject);
    }
}

void ContentInterpreter::processImageXObject(
    QPDFObjectHandle image,
    const std::string& resource_name)
{
    auto dictionary = image.getDict();
    auto width_object = dictionary.getKey("/Width");
    auto height_object = dictionary.getKey("/Height");
    if (!width_object.isInteger() || !height_object.isInteger()) {
        return;
    }

    int32_t width = width_object.getIntValueAsInt();
    int32_t height = height_object.getIntValueAsInt();
    if (width <= 0 || height <= 0 || width > 65535 || height > 65535) {
        return;
    }

    double displayed_width = 0;
    double displayed_height = 0;
    current().getTransformedSize(displayed_width, displayed_height);
    displayed_width *= user_unit_;
    displayed_height *= user_unit_;
    if (displayed_width <= 0 || displayed_height <= 0) {
        return;
    }

    ImagePlacement placement;
    placement.page_index = page_index_;
    placement.form_depth = form_depth_;
    placement.form_object_number = form_object_number_;
    placement.object_number = image.isIndirect() ? image.getObjectID() : 0;
    placement.generation = image.isIndirect() ? image.getGeneration() : 0;
    placement.resource_name = resource_name;
    std::memcpy(placement.matrix, current().ctm, sizeof(placement.matrix));
    placement.displayed_width_pts = displayed_width;
    placement.displayed_height_pts = displayed_height;
    placement.horizontal_dpi = width * 72.0 / displayed_width;
    placement.vertical_dpi = height * 72.0 / displayed_height;
    placement.effective_dpi =
        std::max(placement.horizontal_dpi, placement.vertical_dpi);
    callback_(placement);
}

void ContentInterpreter::processFormXObject(QPDFObjectHandle form)
{
    if (form_depth_ >= kMaxFormDepth) {
        return;
    }

    auto form_key = pdfObjectKey(form);
    if (form_key != 0 && active_forms_ != nullptr &&
        !active_forms_->insert(form_key).second) {
        return;
    }

    auto dictionary = form.getDict();
    auto resources = dictionary.getKey("/Resources");
    if (resources.isNull()) {
        resources = resources_;
    }

    ContentInterpreter child(
        qpdf_, page_index_, form.isIndirect() ? form.getObjectID() : 0,
        form_depth_ + 1, user_unit_, callback_);
    child.setResources(resources);
    child.setActiveForms(active_forms_);
    child.current() = current();

    auto matrix = dictionary.getKey("/Matrix");
    if (matrix.isArray() && matrix.getArrayNItems() == 6) {
        double values[6];
        bool valid = true;
        for (int i = 0; i < 6; ++i) {
            auto item = matrix.getArrayItem(i);
            if (!item.isNumber()) {
                valid = false;
                break;
            }
            values[i] = item.getNumericValue();
        }
        if (valid) {
            child.current().multiplyMatrix(values);
        }
    }

    child.interpret(form);
    if (form_key != 0 && active_forms_ != nullptr) {
        active_forms_->erase(form_key);
    }
}
