#include "qpdf_optimizer_bridge.h"

#include <qpdf/Pl_String.hh>
#include <qpdf/QPDFJob.hh>
#include <qpdf/QPDFLogger.hh>

#include <cstdlib>
#include <cstring>
#include <exception>
#include <memory>
#include <new>
#include <string>

namespace {

void set_error(char** destination, std::string const& message)
{
    if (destination == nullptr) {
        return;
    }
    *destination = nullptr;
    auto const size = message.size() + 1;
    auto* copy = static_cast<char*>(std::malloc(size));
    if (copy != nullptr) {
        std::memcpy(copy, message.c_str(), size);
        *destination = copy;
    }
}

std::string qpdf_error(std::string const& diagnostics, std::string const& fallback)
{
    return diagnostics.empty() ? fallback : diagnostics;
}

} // namespace

extern "C" int
qpdf_optimizer_optimize(
    char const* input_path, char const* output_path, int jpeg_quality, char** error_message)
{
    if (error_message != nullptr) {
        *error_message = nullptr;
    }
    if ((input_path == nullptr) || (output_path == nullptr) || (input_path[0] == '\0') ||
        (output_path[0] == '\0')) {
        set_error(error_message, "Input and output paths are required");
        return 1;
    }
    if ((jpeg_quality < 1) || (jpeg_quality > 100)) {
        set_error(error_message, "JPEG quality must be between 1 and 100");
        return 1;
    }

    std::string diagnostics;
    try {
        QPDFJob job;
        auto logger = QPDFLogger::create();
        auto captured_output = std::make_shared<Pl_String>(
            "qpdf_optimizer", nullptr, diagnostics);
        logger->setInfo(logger->discard());
        logger->setWarn(captured_output);
        logger->setError(captured_output);
        job.setLogger(logger);

        job.config()
            ->inputFile(input_path)
            ->outputFile(output_path)
            ->compressStreams("y")
            ->decodeLevel("generalized")
            ->recompressFlate()
            ->compressionLevel("9")
            ->objectStreams("generate")
            ->optimizeImages()
            ->jpegQuality(std::to_string(jpeg_quality))
            ->checkConfiguration();
        job.run();

        auto const exit_code = job.getExitCode();
        if (exit_code == QPDFJob::EXIT_ERROR) {
            set_error(
                error_message,
                qpdf_error(diagnostics, "qpdf failed with a configuration or input error"));
            return 2;
        } else if (exit_code != 0 && exit_code != 3) {
            set_error(
                error_message,
                qpdf_error(
                    diagnostics,
                    "qpdf failed while optimizing the PDF (exit code: " +
                        std::to_string(exit_code) + ")"));
            return 2;
        }
        if (exit_code == 3 && !diagnostics.empty()) {
            set_error(error_message, diagnostics);
        }
        return 0;
    } catch (std::exception const& error) {
        set_error(
            error_message,
            qpdf_error(
                diagnostics, std::string("qpdf optimization failed: ") + error.what()));
        return 2;
    } catch (...) {
        set_error(error_message, "qpdf failed with an unknown native error");
        return 2;
    }
}

extern "C" void
qpdf_optimizer_free_string(char* value)
{
    std::free(value);
}
