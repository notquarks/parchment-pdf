#include "qpdf_optimizer_bridge.h"

#include <qpdf/Pl_String.hh>
#include <qpdf/QPDF.hh>
#include <qpdf/QPDFJob.hh>
#include <qpdf/QPDFLogger.hh>
#include <qpdf/QPDFWriter.hh>

#include "image_candidate.h"
#include "pdf_analyzer.h"
#include "pdf_image_rewriter.h"

#include <atomic>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <exception>
#include <memory>
#include <new>
#include <string>
#include <sys/stat.h>

#ifdef __ANDROID__
#include <android/log.h>

#define QPDF_LOGI(...) \
    __android_log_print(ANDROID_LOG_INFO, "QpdfOptimizer", __VA_ARGS__)

#define QPDF_LOGE(...) \
    __android_log_print(ANDROID_LOG_ERROR, "QpdfOptimizer", __VA_ARGS__)
#else
#define QPDF_LOGI(...)                            \
    do                                            \
    {                                             \
        std::fprintf(stderr, "[QpdfOptimizer] "); \
        std::fprintf(stderr, __VA_ARGS__);        \
        std::fprintf(stderr, "\n");               \
    } while (0)

#define QPDF_LOGE(...) QPDF_LOGI(__VA_ARGS__)
#endif

/* ── Helpers ─────────────────────────────────────────────────────────── */

namespace
{

    constexpr char kOptimizerBuildId[] = "image-pipeline";

    struct PipelineControl
    {
        std::atomic<bool> *cancelled = nullptr;

        bool isCancelled() const
        {
            return cancelled && cancelled->load(std::memory_order_acquire);
        }
    };

    void set_error(char **dest, std::string const &msg)
    {
        if (!dest)
            return;
        *dest = nullptr;
        if (msg.empty())
            return;
        auto *s = static_cast<char *>(std::malloc(msg.size() + 1));
        if (s)
        {
            std::memcpy(s, msg.c_str(), msg.size() + 1);
            *dest = s;
        }
    }

    char *dup_string(std::string const &s)
    {
        auto *buf = static_cast<char *>(std::malloc(s.size() + 1));
        if (buf)
            std::memcpy(buf, s.c_str(), s.size() + 1);
        return buf;
    }

    void set_result_message(qpdf_optimizer_result &result, std::string const &message)
    {
        if (result.message != nullptr)
        {
            std::free(result.message);
            result.message = nullptr;
        }
        if (!message.empty())
        {
            result.message = dup_string(message);
        }
    }

    void normalize_options(qpdf_optimizer_options &opts)
    {
        if (opts.jpeg_quality == 0)
            opts.jpeg_quality = 75;
        if (opts.target_dpi == 0)
            opts.target_dpi = 144;
        if (opts.dpi_threshold == 0)
            opts.dpi_threshold = 180;
        if (opts.minimum_width == 0)
            opts.minimum_width = 64;
        if (opts.minimum_height == 0)
            opts.minimum_height = 64;
        if (opts.minimum_area == 0)
            opts.minimum_area = 4096;
        if (opts.minimum_stream_bytes == 0)
            opts.minimum_stream_bytes = 1024;
        if (opts.maximum_decoded_pixels == 0)
        {
            opts.maximum_decoded_pixels = 150'000'000;
        }
        if (opts.memory_budget_bytes == 0)
            opts.memory_budget_bytes = 512'000'000;
    }

    bool validate_options(
        const qpdf_optimizer_options *opts,
        std::string &reason)
    {
        if (!opts)
        {
            reason = "Options pointer is null";
            return false;
        }
        if (opts->struct_size < sizeof(qpdf_optimizer_options))
        {
            reason = "Options ABI size mismatch: caller=" +
                     std::to_string(opts->struct_size) + ", native=" +
                     std::to_string(sizeof(qpdf_optimizer_options));
            return false;
        }
        if (opts->abi_version != QPDF_OPTIMIZER_ABI_VERSION)
        {
            reason = "Options ABI version mismatch: caller=" +
                     std::to_string(opts->abi_version) + ", native=" +
                     std::to_string(QPDF_OPTIMIZER_ABI_VERSION);
            return false;
        }
        if (opts->mode < QPDF_OPT_MODE_STRUCTURAL ||
            opts->mode > QPDF_OPT_MODE_IMAGE_OPTIMIZED)
        {
            reason = "Compression mode is out of range";
            return false;
        }
        if (opts->jpeg_quality < 1 || opts->jpeg_quality > 100)
        {
            reason = "JPEG quality must be between 1 and 100";
            return false;
        }
        if (opts->target_dpi < 1)
        {
            reason = "Target DPI must be positive";
            return false;
        }
        if (opts->dpi_threshold < 1)
        {
            reason = "DPI threshold must be positive";
            return false;
        }
        if (opts->minimum_width < 0 || opts->minimum_height < 0 ||
            opts->minimum_area < 0 || opts->minimum_stream_bytes < 0 ||
            opts->maximum_decoded_pixels < 1 || opts->memory_budget_bytes < 1)
        {
            reason = "One or more resource limits are invalid";
            return false;
        }
        return true;
    }

    std::string qpdf_error(std::string const &diag, std::string const &fallback)
    {
        return diag.empty() ? fallback : diag;
    }

} // anonymous namespace

/* ── Job ─────────────────────────────────────────────────────────────── */

struct qpdf_optimizer_job
{
    /* Options (copied by value) */
    qpdf_optimizer_options opts;

    /* File paths (stored for deferred run) */
    std::string input_path;
    std::string output_path;

    /* Cancellation */
    std::atomic<bool> cancelled{false};

    /* Result */
    qpdf_optimizer_result result{};

    /* Diagnostics accumulated during run */
    std::string diagnostics;
};

/* ── Internal: qpdf structural pass ──────────────────────────────────── */

namespace
{

    int run_qpdf_pass(
        char const *input_path,
        char const *output_path,
        qpdf_optimizer_options const &opts,
        std::string &diagnostics)
    {
        std::string captured_output;
        try
        {
            QPDFJob job;
            auto logger = QPDFLogger::create();
            auto info_stream =
                std::make_shared<Pl_String>("qpdf_optimizer", nullptr, captured_output);
            logger->setInfo(logger->discard());
            logger->setWarn(info_stream);
            logger->setError(info_stream);
            job.setLogger(logger);

            auto cfg = job.config();
            cfg->inputFile(input_path)
                ->outputFile(output_path)
                ->compressStreams("y")
                ->decodeLevel("generalized")
                ->recompressFlate()
                ->compressionLevel("9")
                ->objectStreams("generate");

            if (opts.mode == QPDF_OPT_MODE_STRUCTURAL)
            {
                cfg->optimizeImages()
                    ->jpegQuality(std::to_string(opts.jpeg_quality));
            }

            if (opts.strip_document_info)
            {
                cfg->removeInfo();
            }
            if (opts.strip_metadata)
            {
                cfg->removeMetadata();
            }

            if (opts.remove_unused_resources)
            {
                cfg->removeUnreferencedResources("auto");
            }

            cfg->checkConfiguration();

            job.run();

            auto const exit_code = job.getExitCode();
            if (exit_code == QPDFJob::EXIT_ERROR)
            {
                diagnostics = qpdf_error(
                    captured_output,
                    "qpdf failed with a configuration or input error");
                return 2;
            }
            else if (exit_code != 0 && exit_code != 3)
            {
                diagnostics = qpdf_error(
                    captured_output,
                    "qpdf failed while writing output (exit code: " + std::to_string(exit_code) + ")");
                return 2;
            }
            if (exit_code == 3 && !captured_output.empty())
            {
                diagnostics = captured_output;
            }
            return 0;
        }
        catch (std::exception const &e)
        {
            diagnostics =
                qpdf_error(captured_output, std::string("qpdf exception: ") + e.what());
            return 2;
        }
        catch (...)
        {
            diagnostics = qpdf_error(captured_output, "qpdf threw an unknown exception");
            return 2;
        }
    }

} // anonymous namespace

/* ── Core optimization pipeline ─────────────────────────────────────── */

namespace
{

    int run_pipeline(
        const char *input_path,
        const char *output_path,
        const qpdf_optimizer_options &opts,
        qpdf_optimizer_result &result,
        std::string &diagnostics,
        PipelineControl *control = nullptr)
    {

        QPDF_LOGI(
            "build=%s analyzer=%s mode=%d quality=%d "
            "targetDpi=%d threshold=%d downsample=%d recompress=%d",
            kOptimizerBuildId,
            PdfAnalyzer::buildId(),
            opts.mode,
            opts.jpeg_quality,
            opts.target_dpi,
            opts.dpi_threshold,
            opts.downsample_images,
            opts.recompress_jpeg);

        QPDF qpdf;
        try
        {
            qpdf.processFile(input_path);
        }
        catch (std::exception const &e)
        {
            diagnostics = std::string("Failed to open PDF: ") + e.what();
            return 2;
        }

        struct stat st;
        if (stat(input_path, &st) == 0)
            result.original_bytes = st.st_size;

        AnalysisResult analysis;
        std::string analysis_err;
        if (!PdfAnalyzer::analyze(
                qpdf, opts.target_dpi, opts.dpi_threshold,
                analysis, analysis_err,
                control ? control->cancelled : nullptr))
        {
            if (control && control->isCancelled())
                return 3;
            diagnostics = analysis_err.empty()
                              ? "PDF analysis failed"
                              : analysis_err;
            return 2;
        }
        result.images_found = analysis.image_count;
        result.pages_processed = analysis.page_count;

        QPDF_LOGI(
            "analysis pages=%d resources=%d xobjectDicts=%d imageXObjects=%d "
            "formXObjects=%d images=%d highDpi=%d imageBytes=%lld",
            analysis.page_count,
            analysis.pages_with_resources,
            analysis.xobject_dictionaries,
            analysis.image_xobjects_seen,
            analysis.form_xobjects_seen,
            analysis.image_count,
            analysis.high_dpi_count,
            static_cast<long long>(analysis.total_image_bytes));

        for (auto const &image : analysis.images)
        {
            QPDF_LOGI(
                "image obj=%d gen=%d source=%dx%d required=%dx%d dpi=%.1f "
                "placements=%d filter=%s colorSpace=%s processable=%d "
                "skip=%s bytes=%lld",
                image.object_number,
                image.generation,
                image.width,
                image.height,
                image.required_width,
                image.required_height,
                image.max_effective_dpi,
                static_cast<int>(image.placements.size()),
                image.filter.c_str(),
                image.color_space.c_str(),
                image.processable ? 1 : 0,
                imageSkipReasonName(image.skip_reason),
                static_cast<long long>(image.encoded_bytes));
        }

        if (control && control->isCancelled())
        {
            QPDF_LOGI("cancelled after analysis");
            return 3;
        }

        if (opts.mode == QPDF_OPT_MODE_IMAGE_OPTIMIZED)
        {
            RewriteOptions rewrite_opts;
            rewrite_opts.jpeg_quality = opts.jpeg_quality;
            rewrite_opts.target_dpi = opts.target_dpi;
            rewrite_opts.dpi_threshold = opts.dpi_threshold;
            rewrite_opts.minimum_width = opts.minimum_width;
            rewrite_opts.minimum_height = opts.minimum_height;
            rewrite_opts.minimum_area = opts.minimum_area;
            rewrite_opts.minimum_stream_bytes = opts.minimum_stream_bytes;
            rewrite_opts.maximum_decoded_pixels = opts.maximum_decoded_pixels;
            rewrite_opts.memory_budget_bytes = opts.memory_budget_bytes;
            rewrite_opts.recompress_jpeg = opts.recompress_jpeg != 0;
            rewrite_opts.downsample_images = opts.downsample_images != 0;
            rewrite_opts.convert_to_grayscale =
                opts.convert_to_grayscale != 0;
            rewrite_opts.preserve_transparency =
                opts.preserve_transparency != 0;

            std::string rewrite_err;
            auto stats = PdfImageRewriter::rewriteImages(
                qpdf, analysis, rewrite_opts, rewrite_err,
                control ? control->cancelled : nullptr);
            result.images_replaced = stats.images_replaced;
            result.images_skipped = stats.images_skipped;
            result.images_failed = stats.images_failed;
            result.image_bytes_before = stats.bytes_before;
            result.image_bytes_after = stats.bytes_after;

            QPDF_LOGI(
                "rewrite found=%d replaced=%d skipped=%d failed=%d "
                "imageBytes=%lld->%lld error=%s",
                stats.images_found,
                stats.images_replaced,
                stats.images_skipped,
                stats.images_failed,
                static_cast<long long>(stats.bytes_before),
                static_cast<long long>(stats.bytes_after),
                rewrite_err.c_str());

            if (!rewrite_err.empty())
            {
                result.warning_count += 1;
                set_result_message(result, rewrite_err);
            }
            if (stats.cancelled)
                return 3;
        }

        if (control && control->isCancelled())
        {
            QPDF_LOGI("cancelled after image rewrite");
            return 3;
        }

        std::string temp_path = std::string(output_path) + ".qpdf-intermediate";
        std::remove(temp_path.c_str());
        {
            QPDFWriter writer(qpdf, temp_path.c_str());
            writer.setCompressStreams(true);
            writer.setDecodeLevel(qpdf_dl_generalized);
            writer.setRecompressFlate(true);
            writer.setObjectStreamMode(qpdf_o_generate);
            try
            {
                writer.write();
            }
            catch (std::exception const &e)
            {
                diagnostics = std::string("QPDFWriter failed: ") + e.what();
                std::remove(temp_path.c_str());
                return 2;
            }
        }

        if (control && control->isCancelled())
        {
            std::remove(temp_path.c_str());
            QPDF_LOGI("cancelled before structural pass");
            return 3;
        }

        std::string struct_err;
        int rc = run_qpdf_pass(
            temp_path.c_str(), output_path, opts, struct_err);
        std::remove(temp_path.c_str());

        if (rc != 0)
        {
            diagnostics = struct_err;
            QPDF_LOGE("structural pass failed: %s", diagnostics.c_str());
            return rc;
        }
        if (control && control->isCancelled())
        {
            std::remove(output_path);
            QPDF_LOGI("cancelled after structural pass");
            return 3;
        }

        if (stat(output_path, &st) == 0)
            result.output_bytes = st.st_size;

        QPDF_LOGI(
            "complete originalBytes=%lld outputBytes=%lld",
            static_cast<long long>(result.original_bytes),
            static_cast<long long>(result.output_bytes));

        try
        {
            QPDF output_check;
            output_check.processFile(output_path);
            auto output_pages =
                static_cast<int32_t>(output_check.getAllPages().size());
            if (output_pages != analysis.page_count)
            {
                diagnostics = "Output page count does not match input";
                std::remove(output_path);
                return 4;
            }
            result.pages_processed = output_pages;
        }
        catch (std::exception const &e)
        {
            diagnostics =
                std::string("Output validation failed: ") + e.what();
            std::remove(output_path);
            return 4;
        }

        if (result.output_bytes <= 0)
        {
            diagnostics = "Output PDF is empty";
            std::remove(output_path);
            return 4;
        }

        result.status = QPDF_OPTIMIZER_STATUS_COMPLETED;
        return QPDF_OPTIMIZER_STATUS_COMPLETED;
    }

} // anonymous namespace

/* ── Job lifecycle ───────────────────────────────────────────────────── */

extern "C" qpdf_optimizer_job *
qpdf_optimizer_create_job(
    const char *input_path,
    const char *output_path,
    const qpdf_optimizer_options *options)
{
    if (!input_path || !output_path || input_path[0] == '\0' || output_path[0] == '\0' || !options)
        return nullptr;

    qpdf_optimizer_options normalized = *options;
    normalize_options(normalized);
    std::string validation_error;
    if (!validate_options(&normalized, validation_error))
        return nullptr;

    auto *job = new (std::nothrow) qpdf_optimizer_job();
    if (!job)
        return nullptr;

    job->opts = normalized;
    job->input_path = input_path ? input_path : "";
    job->output_path = output_path ? output_path : "";

    return job;
}

extern "C" const qpdf_optimizer_result *
qpdf_optimizer_run(qpdf_optimizer_job *job)
{
    if (!job)
        return nullptr;

    auto &res = job->result;
    if (res.message != nullptr)
    {
        std::free(res.message);
        res.message = nullptr;
    }
    std::memset(&res, 0, sizeof(res));
    res.struct_size = sizeof(qpdf_optimizer_result);
    res.abi_version = QPDF_OPTIMIZER_ABI_VERSION;

    job->diagnostics.clear();
    PipelineControl control{&job->cancelled};
    int rc = run_pipeline(
        job->input_path.c_str(),
        job->output_path.c_str(),
        job->opts, res, job->diagnostics,
        &control);

    if (rc == QPDF_OPTIMIZER_STATUS_CANCELLED)
        res.status = QPDF_OPTIMIZER_STATUS_CANCELLED;
    else if (rc == QPDF_OPTIMIZER_STATUS_VALIDATION_FAILED)
        res.status = QPDF_OPTIMIZER_STATUS_VALIDATION_FAILED;
    else if (rc != QPDF_OPTIMIZER_STATUS_COMPLETED)
        res.status = QPDF_OPTIMIZER_STATUS_PROCESSING_ERROR;
    else
        res.status = QPDF_OPTIMIZER_STATUS_COMPLETED;

    if (!job->diagnostics.empty())
        set_result_message(res, job->diagnostics);
    return &res;
}

extern "C" void
qpdf_optimizer_cancel(qpdf_optimizer_job *job)
{
    if (job)
        job->cancelled.store(true, std::memory_order_release);
}

extern "C" int32_t
qpdf_optimizer_is_cancelled(const qpdf_optimizer_job *job)
{
    return job ? static_cast<int32_t>(
                     job->cancelled.load(std::memory_order_acquire))
               : 0;
}

extern "C" void
qpdf_optimizer_destroy_job(qpdf_optimizer_job *job)
{
    if (!job)
        return;
    if (job->result.message)
    {
        std::free(job->result.message);
        job->result.message = nullptr;
    }
    delete job;
}

extern "C" const char *
qpdf_optimizer_build_id(void)
{
    return kOptimizerBuildId;
}

extern "C" void
qpdf_optimizer_free_string(char *value)
{
    std::free(value);
}

/* ── Analysis API ────────────────────────────────────────────────────── */

struct qpdf_optimizer_analysis
{
    AnalysisResult result;
};

extern "C" qpdf_optimizer_analysis *
qpdf_optimizer_analyze(
    const char *input_path,
    int32_t dpi_threshold,
    char **error_message)
{
    if (error_message)
        *error_message = nullptr;

    if (!input_path || input_path[0] == '\0')
    {
        set_error(error_message, "Input path is required");
        return nullptr;
    }
    if (dpi_threshold <= 0)
        dpi_threshold = 180;

    try
    {
        auto *analysis = new (std::nothrow) qpdf_optimizer_analysis();
        if (!analysis)
        {
            set_error(error_message, "Allocation failed");
            return nullptr;
        }

        std::string error;
        QPDF qpdf;
        qpdf.processFile(input_path);

        if (!PdfAnalyzer::analyze(
                qpdf, dpi_threshold, dpi_threshold,
                analysis->result, error))
        {
            set_error(error_message, error);
            delete analysis;
            return nullptr;
        }

        struct stat st;
        if (stat(input_path, &st) == 0)
        {
            analysis->result.file_bytes = st.st_size;
        }

        return analysis;
    }
    catch (std::exception const &e)
    {
        set_error(error_message, std::string("Analysis failed: ") + e.what());
        return nullptr;
    }
    catch (...)
    {
        set_error(error_message, "Analysis failed with unknown error");
        return nullptr;
    }
}

extern "C" int32_t
qpdf_optimizer_analysis_page_count(const qpdf_optimizer_analysis *a)
{
    return a ? a->result.page_count : 0;
}

extern "C" int32_t
qpdf_optimizer_analysis_image_count(const qpdf_optimizer_analysis *a)
{
    return a ? a->result.image_count : 0;
}

extern "C" int32_t
qpdf_optimizer_analysis_high_dpi_count(const qpdf_optimizer_analysis *a)
{
    return a ? a->result.high_dpi_count : 0;
}

extern "C" int64_t
qpdf_optimizer_analysis_total_image_bytes(const qpdf_optimizer_analysis *a)
{
    return a ? a->result.total_image_bytes : 0;
}

extern "C" int32_t
qpdf_optimizer_analysis_is_encrypted(const qpdf_optimizer_analysis *a)
{
    return a ? (a->result.is_encrypted ? 1 : 0) : 0;
}

extern "C" int32_t
qpdf_optimizer_analysis_has_signatures(const qpdf_optimizer_analysis *a)
{
    return a ? (a->result.has_signatures ? 1 : 0) : 0;
}

static const ImageCandidate *get_image(const qpdf_optimizer_analysis *a, int32_t index)
{
    if (!a || index < 0 ||
        index >= static_cast<int32_t>(a->result.images.size()))
        return nullptr;
    return &a->result.images[index];
}

extern "C" int32_t
qpdf_optimizer_analysis_image_object_number(
    const qpdf_optimizer_analysis *a, int32_t index)
{
    auto *img = get_image(a, index);
    return img ? img->object_number : 0;
}

extern "C" int32_t
qpdf_optimizer_analysis_image_width(
    const qpdf_optimizer_analysis *a, int32_t index)
{
    auto *img = get_image(a, index);
    return img ? img->width : 0;
}

extern "C" int32_t
qpdf_optimizer_analysis_image_height(
    const qpdf_optimizer_analysis *a, int32_t index)
{
    auto *img = get_image(a, index);
    return img ? img->height : 0;
}

extern "C" double
qpdf_optimizer_analysis_image_max_dpi(
    const qpdf_optimizer_analysis *a, int32_t index)
{
    auto *img = get_image(a, index);
    return img ? img->max_effective_dpi : 0;
}

extern "C" int64_t
qpdf_optimizer_analysis_image_encoded_bytes(
    const qpdf_optimizer_analysis *a, int32_t index)
{
    auto *img = get_image(a, index);
    return img ? img->encoded_bytes : 0;
}

extern "C" int32_t
qpdf_optimizer_analysis_image_processable(
    const qpdf_optimizer_analysis *a, int32_t index)
{
    auto *img = get_image(a, index);
    return img ? (img->processable ? 1 : 0) : 0;
}

extern "C" const char *
qpdf_optimizer_analysis_image_color_space(
    const qpdf_optimizer_analysis *a, int32_t index)
{
    auto *img = get_image(a, index);
    return img ? img->color_space.c_str() : "";
}

extern "C" const char *
qpdf_optimizer_analysis_image_filter(
    const qpdf_optimizer_analysis *a, int32_t index)
{
    auto *img = get_image(a, index);
    return img ? img->filter.c_str() : "";
}

extern "C" int32_t
qpdf_optimizer_analysis_image_has_smask(
    const qpdf_optimizer_analysis *a, int32_t index)
{
    auto *img = get_image(a, index);
    return img ? (img->has_smask ? 1 : 0) : 0;
}

extern "C" void
qpdf_optimizer_destroy_analysis(qpdf_optimizer_analysis *a)
{
    delete a;
}
