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
    void push(const GraphicsState& parent);
    void concatCTM(double a, double b, double c, double d, double e, double f);
    void multiplyMatrix(const double m[6]);
    void getTransformedSize(
        double& width_pts, double& height_pts,
        double img_w, double img_h) const;
};

class ContentInterpreter {
public:
    ContentInterpreter(
        QPDF& qpdf,
        int32_t page_index,
        int32_t form_object_number,
        int32_t form_depth,
        const ImagePlacementCallback& callback);

    void interpret(QPDFObjectHandle content);
    void interpretArray(QPDFObjectHandle contents_array);
    void setVisited(std::unordered_set<int32_t>* visited);

private:
    QPDF& qpdf_;
    int32_t page_index_;
    int32_t form_object_number_;
    int32_t form_depth_;
    ImagePlacementCallback callback_;
    std::unordered_set<int32_t>* visited_;

    std::vector<GraphicsState> gstack_;
    QPDFObjectHandle resources_;

    void pushState();
    void popState();
    GraphicsState& current();

    void handleDo(const std::string& name);
    void handleInlineImage(QPDFObjectHandle::Token const& bi_token);
    void processImageXObject(
        QPDFObjectHandle image,
        const std::string& resource_name);
    void processFormXObject(QPDFObjectHandle form);
    QPDFObjectHandle resolveResources(QPDFObjectHandle xobject);
};

bool parseDouble(const std::string& s, double& out);
bool parseCM(const std::vector<std::string>& stack,
             double& a, double& b, double& c,
             double& d, double& e, double& f);

#endif /* CONTENT_INTERPRETER_H */
