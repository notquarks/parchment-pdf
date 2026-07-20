#ifndef QPDF_OPTIMIZER_BRIDGE_H
#define QPDF_OPTIMIZER_BRIDGE_H

#if defined(_WIN32)
#define QPDF_OPTIMIZER_EXPORT __declspec(dllexport)
#else
#define QPDF_OPTIMIZER_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Returns 0 on success, 1 for invalid arguments, and 2 when qpdf fails.
// error_message is allocated with malloc and must be released with
// qpdf_optimizer_free_string.
QPDF_OPTIMIZER_EXPORT int qpdf_optimizer_optimize(
    char const* input_path,
    char const* output_path,
    int jpeg_quality,
    char** error_message);

QPDF_OPTIMIZER_EXPORT void qpdf_optimizer_free_string(char* value);

#ifdef __cplusplus
}
#endif

#endif
