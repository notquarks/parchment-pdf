#include "qpdf_optimizer_bridge.h"

#include <qpdf/Pl_String.hh>
#include <qpdf/QPDFJob.hh>
#include <qpdf/QPDFLogger.hh>

#include <atomic>
#include <cstring>
#include <exception>
#include <memory>
#include <new>
#include <string>
#include <sys/stat.h>

/* ── Helpers ─────────────────────────────────────────────────────────── */

namespace {

void set_error(char** dest, std::string const& msg)
{
    if (!dest) return;
    *dest = nullptr;
    if (msg.empty()) return;
    auto* s = static_cast<char*>(std::malloc(msg.size() + 1));
    if (s) {
        std::memcpy(s, msg.c_str(), msg.size() + 1);
        *dest = s;
    }
}

char* dup_string(std::string const& s)
{
    auto* buf = static_cast<char*>(std::malloc(s.size() + 1));
    if (buf) std::memcpy(buf, s.c_str(), s.size() + 1);
    return buf;
}

char* dup_cstring(const char* s)
{
    if (!s) return nullptr;
    auto const len = std::strlen(s);
    auto* buf = static_cast<char*>(std::malloc(len + 1));
    if (buf) std::memcpy(buf, s, len + 1);
    return buf;
}

bool is_valid_options(const qpdf_optimizer_options_v2* opts)
{
    if (!opts) return false;
    if (opts->struct_size < sizeof(qpdf_optimizer_options_v2)) return false;
    if (opts->api_version != QPDF_OPT_OPTIONS_V2_VERSION) return false;
    if (opts->mode < 0 || opts->mode > QPDF_OPT_MODE_EXTREME_RASTER) return false;
    if (opts->jpeg_quality < 1 || opts->jpeg_quality > 100) return false;
    if (opts->target_dpi < 1) return false;
    if (opts->dpi_threshold < 1) return false;
    return true;
}

std::string qpdf_error(std::string const& diag, std::string const& fallback)
{
    return diag.empty() ? fallback : diag;
}

/* Phase names for progress reporting */
static const char* phase_names[] = {
    "idle",
    "opening",
    "analyzing",
    "processing_images",
    "replacing_streams",
    "structural_cleanup",
    "writing",
    "done",
};
static constexpr int PHASE_COUNT =
    static_cast<int>(sizeof(phase_names) / sizeof(phase_names[0]));

} // anonymous namespace

/* ── Job ─────────────────────────────────────────────────────────────── */

struct qpdf_optimizer_job {
    /* Options (copied by value) */
    qpdf_optimizer_options_v2 opts;

    /* Cancellation */
    std::atomic<bool> cancelled{false};

    /* Progress */
    std::atomic<int> phase_id{0};
    std::atomic<int> progress_current{0};
    std::atomic<int> progress_total{0};

    /* Result */
    qpdf_optimizer_result_v2 result{};

    /* Diagnostics accumulated during run */
    std::string diagnostics;
    std::string warnings;
};

/* ── Internal: qpdf structural pass ──────────────────────────────────── */

namespace {


int run_qpdf_pass(
    char const* input_path,
    char const* output_path,
    qpdf_optimizer_options_v2 const& opts,
    std::string& diagnostics,
    bool& was_cancelled)
{
    std::string captured_output;
    try {
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


        if (opts.mode == QPDF_OPT_MODE_STRUCTURAL) {
            cfg->optimizeImages()
                ->jpegQuality(std::to_string(opts.jpeg_quality));
        }

        if (opts.strip_metadata) {
            cfg->removeStrings();
        }

        if (opts.remove_unused_resources) {
            cfg->removeUnreferencedResources();
        }

        cfg->checkConfiguration();


        if (was_cancelled) return 3;
        job.run();

        auto const exit_code = job.getExitCode();
        if (exit_code == QPDFJob::EXIT_ERROR) {
            diagnostics = qpdf_error(
                captured_output,
                "qpdf failed with a configuration or input error");
            return 2;
        } else if (exit_code != 0 && exit_code != 3) {
            diagnostics = qpdf_error(
                captured_output,
                "qpdf failed while writing output (exit code: "
                    + std::to_string(exit_code) + ")");
            return 2;
        }
        if (exit_code == 3 && !captured_output.empty()) {
            diagnostics = captured_output;
        }
        return 0;
    } catch (std::exception const& e) {
        diagnostics =
            qpdf_error(captured_output, std::string("qpdf exception: ") + e.what());
        return 2;
    } catch (...) {
        diagnostics = qpdf_error(captured_output, "qpdf threw an unknown exception");
        return 2;
    }
}

} // anonymous namespace

/* ── Job lifecycle ───────────────────────────────────────────────────── */

extern "C" qpdf_optimizer_job*
qpdf_optimizer_create_job(const qpdf_optimizer_options_v2* options)
{
    if (!options || !is_valid_options(options)) return nullptr;

    auto* job = new(std::nothrow) qpdf_optimizer_job();
    if (!job) return nullptr;

    job->opts = *options;


    if (job->opts.jpeg_quality == 0) job->opts.jpeg_quality = 75;
    if (job->opts.target_dpi == 0) job->opts.target_dpi = 144;
    if (job->opts.dpi_threshold == 0) job->opts.dpi_threshold = 180;
    if (job->opts.minimum_width == 0) job->opts.minimum_width = 64;
    if (job->opts.minimum_height == 0) job->opts.minimum_height = 64;
    if (job->opts.minimum_area == 0) job->opts.minimum_area = 4096;
    if (job->opts.minimum_stream_bytes == 0) job->opts.minimum_stream_bytes = 1024;
    if (job->opts.maximum_decoded_pixels == 0)
        job->opts.maximum_decoded_pixels = 150'000'000;
    if (job->opts.memory_budget_bytes == 0) job->opts.memory_budget_bytes = 512'000'000;

    return job;
}

extern "C" const qpdf_optimizer_result_v2*
qpdf_optimizer_run(qpdf_optimizer_job* job)
{
    if (!job) return nullptr;

    auto& res = job->result;
    std::memset(&res, 0, sizeof(res));
    res.struct_size = sizeof(qpdf_optimizer_result_v2);
    res.api_version = QPDF_OPT_RESULT_V2_VERSION;


    res.status = 0;
    return &res;
}

extern "C" void
qpdf_optimizer_cancel(qpdf_optimizer_job* job)
{
    if (job) job->cancelled.store(true, std::memory_order_release);
}

extern "C" int32_t
qpdf_optimizer_is_cancelled(const qpdf_optimizer_job* job)
{
    return job ? static_cast<int32_t>(
                     job->cancelled.load(std::memory_order_acquire))
              : 0;
}

extern "C" void
qpdf_optimizer_get_progress(
    const qpdf_optimizer_job* job,
    int32_t* phase_id,
    int32_t* current,
    int32_t* total)
{
    if (!job) {
        if (phase_id) *phase_id = 0;
        if (current) *current = 0;
        if (total) *total = 0;
        return;
    }
    if (phase_id) *phase_id = job->phase_id.load(std::memory_order_acquire);
    if (current) *current = job->progress_current.load(std::memory_order_acquire);
    if (total) *total = job->progress_total.load(std::memory_order_acquire);
}

extern "C" void
qpdf_optimizer_destroy_job(qpdf_optimizer_job* job)
{
    if (!job) return;
    if (job->result.message) {
        std::free(job->result.message);
        job->result.message = nullptr;
    }
    delete job;
}

extern "C" const char*
qpdf_optimizer_status_name(int32_t status)
{
    switch (status) {
    case 0: return "completed";
    case 1: return "invalid_arguments";
    case 2: return "processing_error";
    case 3: return "cancelled";
    case 4: return "validation_failed";
    default: return "unknown";
    }
}

/* ── V2 optimization pipeline ────────────────────────────────────────── */

extern "C" int
qpdf_optimizer_optimize_v2(
    const char* input_path,
    const char* output_path,
    const qpdf_optimizer_options_v2* options,
    qpdf_optimizer_result_v2* result,
    char** error_message)
{
    if (error_message) *error_message = nullptr;
    if (!result) return 1;
    std::memset(result, 0, sizeof(*result));
    result->struct_size = sizeof(qpdf_optimizer_result_v2);
    result->api_version = QPDF_OPT_RESULT_V2_VERSION;

    if (!input_path || !output_path ||
        input_path[0] == '\0' || output_path[0] == '\0') {
        set_error(error_message, "Input and output paths are required");
        result->status = 1;
        return 1;
    }
    if (!options || !is_valid_options(options)) {
        set_error(error_message, "Invalid options");
        result->status = 1;
        return 1;
    }

    try {
        QPDF qpdf;
        qpdf.processFile(input_path);

        struct stat st;
        if (stat(input_path, &st) == 0) {
            result->original_bytes = st.st_size;
        }


        if (options->mode == QPDF_OPT_MODE_IMAGE_OPTIMIZED &&
            options->downsample_images) {
            RewriteOptions rewrite_opts;
            rewrite_opts.jpeg_quality = options->jpeg_quality;
            rewrite_opts.target_dpi = options->target_dpi;
            rewrite_opts.dpi_threshold = options->dpi_threshold;
            rewrite_opts.minimum_width = options->minimum_width;
            rewrite_opts.minimum_height = options->minimum_height;
            rewrite_opts.minimum_area = options->minimum_area;
            rewrite_opts.minimum_stream_bytes = options->minimum_stream_bytes;
            rewrite_opts.maximum_decoded_pixels = options->maximum_decoded_pixels;
            rewrite_opts.recompress_jpeg = options->recompress_jpeg != 0;
            rewrite_opts.downsample_images = options->downsample_images != 0;

            std::string rewrite_error;
            auto stats = PdfImageRewriter::rewriteImages(
                qpdf, rewrite_opts, rewrite_error);

            result->images_found = stats.images_found;
            result->images_replaced = stats.images_replaced;
            result->images_skipped = stats.images_skipped;
            result->images_failed = stats.images_failed;
            result->image_bytes_before = stats.bytes_before;
            result->image_bytes_after = stats.bytes_after;

            if (!rewrite_error.empty()) {
                set_error(error_message, rewrite_error);
            }
        } else {
            AnalysisResult analysis;
            std::string a_err;
            PdfAnalyzer::analyze(qpdf, options->dpi_threshold, analysis, a_err);
            result->images_found = analysis.image_count;
            result->images_skipped = analysis.image_count;
        }


        {
            QPDFJob job;
            auto logger = QPDFLogger::create();
            std::string diagnostics;
            auto info_stream = std::make_shared<Pl_String>(
                "qpdf_optimizer", nullptr, diagnostics);
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

            if (options->mode == QPDF_OPT_MODE_STRUCTURAL) {
                cfg->optimizeImages()
                    ->jpegQuality(std::to_string(options->jpeg_quality));
            }
            if (options->strip_metadata) cfg->removeStrings();
            if (options->remove_unused_resources) cfg->removeUnreferencedResources();
            cfg->checkConfiguration();
            job.run();

            if (job.getExitCode() == QPDFJob::EXIT_ERROR) {
                set_error(error_message,
                    qpdf_error(diagnostics, "qpdf structural pass failed"));
                result->status = 2;
                return 2;
            }
        }

        if (stat(output_path, &st) == 0) {
            result->output_bytes = st.st_size;
        }
        result->pages_processed = 0;
        result->status = 0;
        return 0;

    } catch (std::exception const& e) {
        set_error(error_message,
            std::string("Optimization failed: ") + e.what());
        result->status = 2;
        return 2;
    } catch (...) {
        set_error(error_message, "Unknown error during optimization");
        result->status = 2;
        return 2;
    }
}

/* ── Backward-compatible v1 wrapper ──────────────────────────────────── */

extern "C" int
qpdf_optimizer_optimize(
    const char* input_path,
    const char* output_path,
    int jpeg_quality,
    char** error_message)
{
    if (error_message) *error_message = nullptr;

    if (!input_path || !output_path || input_path[0] == '\0' ||
        output_path[0] == '\0') {
        set_error(error_message, "Input and output paths are required");
        return 1;
    }
    if (jpeg_quality < 1 || jpeg_quality > 100) {
        set_error(error_message, "JPEG quality must be between 1 and 100");
        return 1;
    }


    qpdf_optimizer_options_v2 opts{};
    opts.struct_size = sizeof(opts);
    opts.api_version = QPDF_OPT_OPTIONS_V2_VERSION;
    opts.mode = QPDF_OPT_MODE_STRUCTURAL;
    opts.jpeg_quality = jpeg_quality;
    opts.target_dpi = 144;
    opts.dpi_threshold = 180;
    opts.minimum_width = 64;
    opts.minimum_height = 64;
    opts.minimum_area = 4096;
    opts.minimum_stream_bytes = 1024;
    opts.downsample_images = 0;
    opts.recompress_jpeg = 1;
    opts.convert_to_grayscale = 0;
    opts.strip_metadata = 0;
    opts.strip_document_info = 0;
    opts.remove_unused_resources = 0;
    opts.deduplicate_images = 1;
    opts.preserve_transparency = 1;
    opts.maximum_decoded_pixels = 150'000'000;
    opts.memory_budget_bytes = 512'000'000;

    auto* job = qpdf_optimizer_create_job(&opts);
    if (!job) {
        set_error(error_message, "Failed to create optimizer job");
        return 1;
    }

    std::string diagnostics;
    bool cancelled = false;
    auto const rc = run_qpdf_pass(
        input_path, output_path, opts, diagnostics, cancelled);

    if (rc == 3) {
        qpdf_optimizer_destroy_job(job);
        return 0;
    }
    if (rc == 2) {
        set_error(error_message, diagnostics);
        qpdf_optimizer_destroy_job(job);
        return 2;
    }

    qpdf_optimizer_destroy_job(job);
    return 0;
}

extern "C" void
qpdf_optimizer_free_string(char* value)
{
    std::free(value);
}

/* ── Analysis API ────────────────────────────────────────────────────── */

#include "pdf_analyzer.h"
#include "image_candidate.h"
#include "pdf_image_rewriter.h"

struct qpdf_optimizer_analysis {
    AnalysisResult result;
};

extern "C" qpdf_optimizer_analysis*
qpdf_optimizer_analyze(
    const char* input_path,
    int32_t dpi_threshold,
    char** error_message)
{
    if (error_message) *error_message = nullptr;

    if (!input_path || input_path[0] == '\0') {
        set_error(error_message, "Input path is required");
        return nullptr;
    }
    if (dpi_threshold <= 0) dpi_threshold = 180;

    try {
        auto* analysis = new(std::nothrow) qpdf_optimizer_analysis();
        if (!analysis) {
            set_error(error_message, "Allocation failed");
            return nullptr;
        }

        std::string error;
        QPDF qpdf;
        qpdf.processFile(input_path);

        analysis->result.file_bytes = 0;
        try {
            struct stat st;
            if (stat(input_path, &st) == 0) {
                analysis->result.file_bytes = st.st_size;
            }
        } catch (...) {}

        if (!PdfAnalyzer::analyze(qpdf, dpi_threshold, analysis->result, error)) {
            set_error(error_message, error);
            delete analysis;
            return nullptr;
        }

        return analysis;
    } catch (std::exception const& e) {
        set_error(error_message, std::string("Analysis failed: ") + e.what());
        return nullptr;
    } catch (...) {
        set_error(error_message, "Analysis failed with unknown error");
        return nullptr;
    }
}

extern "C" int32_t
qpdf_optimizer_analysis_page_count(const qpdf_optimizer_analysis* a)
{
    return a ? a->result.page_count : 0;
}

extern "C" int32_t
qpdf_optimizer_analysis_image_count(const qpdf_optimizer_analysis* a)
{
    return a ? a->result.image_count : 0;
}

extern "C" int32_t
qpdf_optimizer_analysis_high_dpi_count(const qpdf_optimizer_analysis* a)
{
    return a ? a->result.high_dpi_count : 0;
}

extern "C" int64_t
qpdf_optimizer_analysis_total_image_bytes(const qpdf_optimizer_analysis* a)
{
    return a ? a->result.total_image_bytes : 0;
}

extern "C" int32_t
qpdf_optimizer_analysis_is_encrypted(const qpdf_optimizer_analysis* a)
{
    return a ? (a->result.is_encrypted ? 1 : 0) : 0;
}

extern "C" int32_t
qpdf_optimizer_analysis_has_signatures(const qpdf_optimizer_analysis* a)
{
    return a ? (a->result.has_signatures ? 1 : 0) : 0;
}

static const ImageCandidate* get_image(const qpdf_optimizer_analysis* a, int32_t index)
{
    if (!a || index < 0 ||
        index >= static_cast<int32_t>(a->result.images.size()))
        return nullptr;
    return &a->result.images[index];
}

extern "C" int32_t
qpdf_optimizer_analysis_image_object_number(
    const qpdf_optimizer_analysis* a, int32_t index)
{
    auto* img = get_image(a, index);
    return img ? img->object_number : 0;
}

extern "C" int32_t
qpdf_optimizer_analysis_image_width(
    const qpdf_optimizer_analysis* a, int32_t index)
{
    auto* img = get_image(a, index);
    return img ? img->width : 0;
}

extern "C" int32_t
qpdf_optimizer_analysis_image_height(
    const qpdf_optimizer_analysis* a, int32_t index)
{
    auto* img = get_image(a, index);
    return img ? img->height : 0;
}

extern "C" double
qpdf_optimizer_analysis_image_max_dpi(
    const qpdf_optimizer_analysis* a, int32_t index)
{
    auto* img = get_image(a, index);
    return img ? img->max_effective_dpi : 0;
}

extern "C" int64_t
qpdf_optimizer_analysis_image_encoded_bytes(
    const qpdf_optimizer_analysis* a, int32_t index)
{
    auto* img = get_image(a, index);
    return img ? img->encoded_bytes : 0;
}

extern "C" int32_t
qpdf_optimizer_analysis_image_processable(
    const qpdf_optimizer_analysis* a, int32_t index)
{
    auto* img = get_image(a, index);
    return img ? (img->processable ? 1 : 0) : 0;
}

extern "C" const char*
qpdf_optimizer_analysis_image_color_space(
    const qpdf_optimizer_analysis* a, int32_t index)
{
    auto* img = get_image(a, index);
    return img ? img->color_space.c_str() : "";
}

extern "C" const char*
qpdf_optimizer_analysis_image_filter(
    const qpdf_optimizer_analysis* a, int32_t index)
{
    auto* img = get_image(a, index);
    return img ? img->filter.c_str() : "";
}

extern "C" int32_t
qpdf_optimizer_analysis_image_has_smask(
    const qpdf_optimizer_analysis* a, int32_t index)
{
    auto* img = get_image(a, index);
    return img ? (img->has_smask ? 1 : 0) : 0;
}

extern "C" void
qpdf_optimizer_destroy_analysis(qpdf_optimizer_analysis* a)
{
    delete a;
}
