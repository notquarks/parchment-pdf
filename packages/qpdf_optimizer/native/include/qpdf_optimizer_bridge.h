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

#define QPDF_OPT_MODE_STRUCTURAL 0
#define QPDF_OPT_MODE_IMAGE_OPTIMIZED 1
#define QPDF_OPT_MODE_EXTREME_RASTER 2

#define QPDF_OPT_OPTIONS_V2_VERSION 2

    struct qpdf_optimizer_options_v2
    {
        /* Size of this struct in bytes. Enables forward compatibility: newer
           library versions can accept larger structs from newer callers and
           ignore trailing fields when struct_size < their expected size. */
        uint32_t struct_size;
        uint32_t api_version;

        int32_t mode; /* QPDF_OPT_MODE_* */

        int32_t jpeg_quality;  /* 1–100, default 75 */
        int32_t target_dpi;    /* Downsample target, default 144 */
        int32_t dpi_threshold; /* Only process images above this DPI, default 180 */

        int32_t minimum_width;        /* Skip images narrower than this (px), default 64 */
        int32_t minimum_height;       /* Skip images shorter than this (px), default 64 */
        int64_t minimum_area;         /* Skip images smaller than this (px²), default 4096 */
        int64_t minimum_stream_bytes; /* Skip images with encoded bytes below this, default 1024 */

        int32_t downsample_images;
        int32_t recompress_jpeg;
        int32_t convert_to_grayscale;
        int32_t strip_metadata;
        int32_t strip_document_info;
        int32_t remove_unused_resources;
        int32_t deduplicate_images;
        int32_t preserve_transparency;

        int64_t maximum_decoded_pixels; /* Per image, default 150 000 000 */
        int64_t memory_budget_bytes;    /* Working memory limit, default 512 MB */
    };

#define QPDF_OPT_RESULT_V2_VERSION 2

    struct qpdf_optimizer_result_v2
    {
        uint32_t struct_size;
        uint32_t api_version;

        /* Status: 0 = ok, 1 = invalid args, 2 = processing error,
                  3 = cancelled, 4 = visual validation failed */
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

        /* Null-terminated diagnostic/warning message (malloc'd, caller frees). */
        char *message;
    };

    typedef struct qpdf_optimizer_job qpdf_optimizer_job;

    /* Create a job from options and file paths. Returns NULL on allocation failure.
       The job owns copies of *options and the path strings; the caller may free
       them after this. */
    QPDF_OPTIMIZER_EXPORT qpdf_optimizer_job *
    qpdf_optimizer_create_job(
        const char *input_path,
        const char *output_path,
        const struct qpdf_optimizer_options_v2 *options);

    /* Run the job synchronously on the calling thread.
       Returns a pointer to the job's internal result (valid until the job is
       destroyed). Check is_cancelled between pages/images for cooperative
       cancellation. */
    QPDF_OPTIMIZER_EXPORT const struct qpdf_optimizer_result_v2 *qpdf_optimizer_run(
        qpdf_optimizer_job *job);

    /* Set the cancellation flag. The job will stop at the next cooperative
       checkpoint and report status == 3 (cancelled). Safe to call from any
       thread. */
    QPDF_OPTIMIZER_EXPORT void qpdf_optimizer_cancel(qpdf_optimizer_job *job);

    /* Check whether cancellation has been requested. */
    QPDF_OPTIMIZER_EXPORT int32_t qpdf_optimizer_is_cancelled(
        const qpdf_optimizer_job *job);

    /* Query progress. current/total are set to a 0-based counter pair. */
    QPDF_OPTIMIZER_EXPORT void qpdf_optimizer_get_progress(
        const qpdf_optimizer_job *job,
        int32_t *phase_id,
        int32_t *current,
        int32_t *total);

    /* Destroy the job and release all associated resources. */
    QPDF_OPTIMIZER_EXPORT void qpdf_optimizer_destroy_job(
        qpdf_optimizer_job *job);

    /* Return a human-readable name for a status code. */
    QPDF_OPTIMIZER_EXPORT const char *qpdf_optimizer_status_name(int32_t status);

    typedef struct qpdf_optimizer_analysis qpdf_optimizer_analysis;

    /* Analyze a PDF file. Returns NULL on failure and sets *error_message.
       The caller must destroy the result with qpdf_optimizer_destroy_analysis.
       dpi_threshold: only flag images above this DPI as high-DPI. */
    QPDF_OPTIMIZER_EXPORT qpdf_optimizer_analysis *qpdf_optimizer_analyze(
        const char *input_path,
        int32_t dpi_threshold,
        char **error_message);

    QPDF_OPTIMIZER_EXPORT int32_t qpdf_optimizer_analysis_page_count(
        const qpdf_optimizer_analysis *a);
    QPDF_OPTIMIZER_EXPORT int32_t qpdf_optimizer_analysis_image_count(
        const qpdf_optimizer_analysis *a);
    QPDF_OPTIMIZER_EXPORT int32_t qpdf_optimizer_analysis_high_dpi_count(
        const qpdf_optimizer_analysis *a);
    QPDF_OPTIMIZER_EXPORT int64_t qpdf_optimizer_analysis_total_image_bytes(
        const qpdf_optimizer_analysis *a);
    QPDF_OPTIMIZER_EXPORT int32_t qpdf_optimizer_analysis_is_encrypted(
        const qpdf_optimizer_analysis *a);
    QPDF_OPTIMIZER_EXPORT int32_t qpdf_optimizer_analysis_has_signatures(
        const qpdf_optimizer_analysis *a);

    /* index must be in [0, image_count). */
    QPDF_OPTIMIZER_EXPORT int32_t qpdf_optimizer_analysis_image_object_number(
        const qpdf_optimizer_analysis *a, int32_t index);
    QPDF_OPTIMIZER_EXPORT int32_t qpdf_optimizer_analysis_image_width(
        const qpdf_optimizer_analysis *a, int32_t index);
    QPDF_OPTIMIZER_EXPORT int32_t qpdf_optimizer_analysis_image_height(
        const qpdf_optimizer_analysis *a, int32_t index);
    QPDF_OPTIMIZER_EXPORT double qpdf_optimizer_analysis_image_max_dpi(
        const qpdf_optimizer_analysis *a, int32_t index);
    QPDF_OPTIMIZER_EXPORT int64_t qpdf_optimizer_analysis_image_encoded_bytes(
        const qpdf_optimizer_analysis *a, int32_t index);
    QPDF_OPTIMIZER_EXPORT int32_t qpdf_optimizer_analysis_image_processable(
        const qpdf_optimizer_analysis *a, int32_t index);
    QPDF_OPTIMIZER_EXPORT const char *qpdf_optimizer_analysis_image_color_space(
        const qpdf_optimizer_analysis *a, int32_t index);
    QPDF_OPTIMIZER_EXPORT const char *qpdf_optimizer_analysis_image_filter(
        const qpdf_optimizer_analysis *a, int32_t index);
    QPDF_OPTIMIZER_EXPORT int32_t qpdf_optimizer_analysis_image_has_smask(
        const qpdf_optimizer_analysis *a, int32_t index);

    QPDF_OPTIMIZER_EXPORT void qpdf_optimizer_destroy_analysis(
        qpdf_optimizer_analysis *a);

    QPDF_OPTIMIZER_EXPORT const char *
    qpdf_optimizer_build_id(void);

    /* Old single-function API. Internally creates a v2 job with defaults and
       delegates. Callers must free *error_message with qpdf_optimizer_free_string. */
    QPDF_OPTIMIZER_EXPORT int qpdf_optimizer_optimize(
        const char *input_path,
        const char *output_path,
        int jpeg_quality,
        char **error_message);

    QPDF_OPTIMIZER_EXPORT void qpdf_optimizer_free_string(char *value);

    /* V2 single-call optimization API. Returns 0 on success, 1 for invalid
       arguments, 2 for processing error. Caller frees *error_message with
       qpdf_optimizer_free_string. */
    QPDF_OPTIMIZER_EXPORT int qpdf_optimizer_optimize_v2(
        const char *input_path,
        const char *output_path,
        const struct qpdf_optimizer_options_v2 *options,
        struct qpdf_optimizer_result_v2 *result,
        char **error_message);

#ifdef __cplusplus
}
#endif

#endif /* QPDF_OPTIMIZER_BRIDGE_H */
