#ifndef PDF_ANALYZER_H
#define PDF_ANALYZER_H

#include <cstdint>
#include <string>

#include <qpdf/QPDF.hh>

#include "image_candidate.h"

class PdfAnalyzer {
public:
    static bool analyze(
        QPDF& qpdf,
        int32_t dpi_threshold,
        AnalysisResult& result,
        std::string& error);

private:
    static void discoverImages(
        QPDF& qpdf,
        AnalysisResult& result,
        int32_t dpi_threshold);

    static void processPage(
        QPDF& qpdf,
        QPDFObjectHandle page,
        int32_t page_index,
        int32_t dpi_threshold,
        AnalysisResult& result);

    static void finalize(AnalysisResult& result, int32_t dpi_threshold);
    static void checkDocumentProperties(QPDF& qpdf, AnalysisResult& result);
};

#endif /* PDF_ANALYZER_H */
