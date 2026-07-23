#ifndef CONTENT_INTERPRETER_H
#define CONTENT_INTERPRETER_H

#include <cstdint>
#include <functional>
#include <string>
#include <unordered_set>
#include <vector>

#include <qpdf/QPDF.hh>
#include <qpdf/QPDFObjectHandle.hh>

#include "image_candidate.h"

using ImagePlacementCallback =
    std::function<void(const ImagePlacement& placement)>;

struct GraphicsState {
    double ctm[6];

    GraphicsState();
    void multiplyMatrix(const double matrix[6]);
    void concatCTM(double a, double b, double c, double d, double e, double f);
    void getTransformedSize(double& width, double& height) const;
};

class ContentInterpreter {
public:
    ContentInterpreter(
        QPDF& qpdf,
        int32_t page_index,
        int32_t form_object_number,
        int32_t form_depth,
        double user_unit,
        const ImagePlacementCallback& callback);

    void interpretPage(QPDFObjectHandle page);
    void interpret(QPDFObjectHandle content);
    void setResources(QPDFObjectHandle resources);
    void setActiveForms(std::unordered_set<uint64_t>* active_forms);
    void pushOperand(const std::string& value);
    void dispatchOperator(const std::string& op);

private:
    QPDF& qpdf_;
    int32_t page_index_;
    int32_t form_object_number_;
    int32_t form_depth_;
    double user_unit_;
    ImagePlacementCallback callback_;
    QPDFObjectHandle resources_;
    std::vector<GraphicsState> graphics_stack_;
    std::vector<std::string> operands_;
    std::unordered_set<uint64_t>* active_forms_;

    GraphicsState& current();
    void pushState();
    void popState();
    void handleDo(const std::string& name);
    void processImageXObject(QPDFObjectHandle image, const std::string& resource_name);
    void processFormXObject(QPDFObjectHandle form);
};

#endif
