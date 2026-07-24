#ifndef QPDF_OPTIMIZER_BRIDGE_H
#define QPDF_OPTIMIZER_BRIDGE_H

#include <stdint.h>

#if defined(_WIN32)
#define QPDF_OPTIMIZER_EXPORT __declspec(dllexport)
#else
#define QPDF_OPTIMIZER_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C"
{
#endif

#define QPDF_OPTIMIZER_ABI_VERSION 3

    enum qpdf_optimizer_mode
    {
        QPDF_OPT_MODE_STRUCTURAL = 0,
        QPDF_OPT_MODE_IMAGE_OPTIMIZED = 1,
    };

    enum qpdf_optimizer_status
    {
        QPDF_OPTIMIZER_STATUS_COMPLETED = 0,
        QPDF_OPTIMIZER_STATUS_INVALID_ARGUMENTS = 1,
        QPDF_OPTIMIZER_STATUS_PROCESSING_ERROR = 2,
        QPDF_OPTIMIZER_STATUS_CANCELLED = 3,
        QPDF_OPTIMIZER_STATUS_VALIDATION_FAILED = 4,
    };

    struct qpdf_optimizer_options
    {
        /*
         * Size of this struct in bytes. The native library accepts the current
         * size or a larger struct with trailing fields, but rejects smaller
         * layouts. abi_version must match QPDF_OPTIMIZER_ABI_VERSION.
         */
        uint32_t struct_size;
        uint32_t abi_version;

        int32_t mode; /* qpdf_optimizer_mode */

        int32_t jpeg_quality;  /* 1-100, default 75 */
        int32_t target_dpi;    /* Downsample target, default 144 */
        int32_t dpi_threshold; /* Process images above this DPI, default 180 */

        int32_t minimum_width;        /* Default 64 px */
        int32_t minimum_height;       /* Default 64 px */
        int64_t minimum_area;         /* Default 4096 px^2 */
        int64_t minimum_stream_bytes; /* Default 1024 bytes */

        int32_t downsample_images;
        int32_t recompress_jpeg;
        int32_t convert_to_grayscale;
        int32_t strip_metadata;
        int32_t strip_document_info;
        int32_t remove_unused_resources;
        int32_t preserve_transparency;

        int64_t maximum_decoded_pixels; /* Per image, default 150,000,000 */
        int64_t memory_budget_bytes;    /* Default 512 MB */
    };

    struct qpdf_optimizer_result
    {
        uint32_t struct_size;
        uint32_t abi_version;

        int32_t status;
        int32_t warning_count;

        int32_t pages_processed;
        int32_t images_found;
        int32_t images_replaced;
        int32_t images_skipped;
        int32_t images_failed;

        int64_t original_bytes;
        int64_t output_bytes;
        int64_t image_bytes_before;
        int64_t image_bytes_after;

        /*
         * Null-terminated diagnostic or warning message owned by the job.
         * Valid until qpdf_optimizer_destroy_job is called.
         */
        char *message;
    };

    typedef struct qpdf_optimizer_job qpdf_optimizer_job;

    QPDF_OPTIMIZER_EXPORT qpdf_optimizer_job *
    qpdf_optimizer_create_job(
        const char *input_path,
        const char *output_path,
        const struct qpdf_optimizer_options *options);

    /*
     * Runs synchronously on the calling thread. The returned result is owned by
     * the job and remains valid until the next run or job destruction.
     */
    QPDF_OPTIMIZER_EXPORT const struct qpdf_optimizer_result *
    qpdf_optimizer_run(qpdf_optimizer_job *job);

    /* Safe to call from another thread while qpdf_optimizer_run is active. */
    QPDF_OPTIMIZER_EXPORT void
    qpdf_optimizer_cancel(qpdf_optimizer_job *job);

    QPDF_OPTIMIZER_EXPORT int32_t
    qpdf_optimizer_is_cancelled(const qpdf_optimizer_job *job);

    QPDF_OPTIMIZER_EXPORT void
    qpdf_optimizer_destroy_job(qpdf_optimizer_job *job);

    typedef struct qpdf_optimizer_analysis qpdf_optimizer_analysis;

    QPDF_OPTIMIZER_EXPORT qpdf_optimizer_analysis *
    qpdf_optimizer_analyze(
        const char *input_path,
        int32_t dpi_threshold,
        char **error_message);

    QPDF_OPTIMIZER_EXPORT int32_t
    qpdf_optimizer_analysis_page_count(const qpdf_optimizer_analysis *analysis);
    QPDF_OPTIMIZER_EXPORT int32_t
    qpdf_optimizer_analysis_image_count(const qpdf_optimizer_analysis *analysis);
    QPDF_OPTIMIZER_EXPORT int32_t
    qpdf_optimizer_analysis_high_dpi_count(
        const qpdf_optimizer_analysis *analysis);
    QPDF_OPTIMIZER_EXPORT int64_t
    qpdf_optimizer_analysis_total_image_bytes(
        const qpdf_optimizer_analysis *analysis);
    QPDF_OPTIMIZER_EXPORT int32_t
    qpdf_optimizer_analysis_is_encrypted(
        const qpdf_optimizer_analysis *analysis);
    QPDF_OPTIMIZER_EXPORT int32_t
    qpdf_optimizer_analysis_has_signatures(
        const qpdf_optimizer_analysis *analysis);

    QPDF_OPTIMIZER_EXPORT int32_t
    qpdf_optimizer_analysis_image_object_number(
        const qpdf_optimizer_analysis *analysis,
        int32_t index);
    QPDF_OPTIMIZER_EXPORT int32_t
    qpdf_optimizer_analysis_image_width(
        const qpdf_optimizer_analysis *analysis,
        int32_t index);
    QPDF_OPTIMIZER_EXPORT int32_t
    qpdf_optimizer_analysis_image_height(
        const qpdf_optimizer_analysis *analysis,
        int32_t index);
    QPDF_OPTIMIZER_EXPORT double
    qpdf_optimizer_analysis_image_max_dpi(
        const qpdf_optimizer_analysis *analysis,
        int32_t index);
    QPDF_OPTIMIZER_EXPORT int64_t
    qpdf_optimizer_analysis_image_encoded_bytes(
        const qpdf_optimizer_analysis *analysis,
        int32_t index);
    QPDF_OPTIMIZER_EXPORT int32_t
    qpdf_optimizer_analysis_image_processable(
        const qpdf_optimizer_analysis *analysis,
        int32_t index);
    QPDF_OPTIMIZER_EXPORT const char *
    qpdf_optimizer_analysis_image_color_space(
        const qpdf_optimizer_analysis *analysis,
        int32_t index);
    QPDF_OPTIMIZER_EXPORT const char *
    qpdf_optimizer_analysis_image_filter(
        const qpdf_optimizer_analysis *analysis,
        int32_t index);
    QPDF_OPTIMIZER_EXPORT int32_t
    qpdf_optimizer_analysis_image_has_smask(
        const qpdf_optimizer_analysis *analysis,
        int32_t index);

    QPDF_OPTIMIZER_EXPORT void
    qpdf_optimizer_destroy_analysis(qpdf_optimizer_analysis *analysis);

    QPDF_OPTIMIZER_EXPORT const char *
    qpdf_optimizer_build_id(void);

    /*
     * Frees messages returned through qpdf_optimizer_analyze's error_message.
     * Job result messages are job-owned and must not be freed separately.
     */
    QPDF_OPTIMIZER_EXPORT void
    qpdf_optimizer_free_string(char *value);

#ifdef __cplusplus
}
#endif

#endif /* QPDF_OPTIMIZER_BRIDGE_H */
