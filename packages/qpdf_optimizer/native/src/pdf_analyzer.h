#ifndef PDF_ANALYZER_H
#define PDF_ANALYZER_H

#include <atomic>
#include <cstdint>
#include <functional>
#include <string>
#include <unordered_map>

#include <qpdf/QPDF.hh>

#include "image_candidate.h"

class PdfAnalyzer {
public:
    static const char* buildId();

    static bool analyze(
        QPDF& qpdf,
        int32_t target_dpi,
        int32_t dpi_threshold,
        AnalysisResult& result,
        std::string& error,
        std::atomic<bool>* cancelled = nullptr,
        const std::function<void(int32_t, int32_t)>& progress = {});

private:
    using ImageIndexMap = std::unordered_map<uint64_t, size_t>;

    static void processPage(
        QPDF& qpdf,
        QPDFObjectHandle page,
        int32_t page_index,
        AnalysisResult& result,
        ImageIndexMap& image_index);

    static void finalize(
        AnalysisResult& result,
        int32_t target_dpi,
        int32_t dpi_threshold);

    static void checkDocumentProperties(QPDF& qpdf, AnalysisResult& result);
};

#endif
