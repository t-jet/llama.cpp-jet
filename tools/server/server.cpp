#include "server-context.h"
#include "server-http.h"
#include "server-models.h"
#include "server-cors-proxy.h"
#include "server-stream.h"
#include "server-tools.h"
#include "server-crash-handler.h"

#include "arg.h"
#include "build-info.h"
#include "common.h"
#include "fit.h"
#include "llama.h"
#include "log.h"

#include <atomic>
#include <clocale>
#include <cstdlib>
#include <exception>
#include <signal.h>
#include <string>
#include <thread> // for std::thread::hardware_concurrency

#if defined(_WIN32)
#include <windows.h>
#endif

static std::function<void(int)> shutdown_handler;
static std::atomic_flag is_terminating = ATOMIC_FLAG_INIT;

static inline void signal_handler(int signal) {
    if (is_terminating.test_and_set()) {
        // in case it hangs, we can force terminate the server by hitting Ctrl+C twice
        // this is for better developer experience, we can remove when the server is stable enough
        fprintf(stderr, "Received second interrupt, terminating immediately.\n");
        exit(1);
    }

    shutdown_handler(signal);
}

// wrapper function that handles exceptions and logs errors
// this is to make sure handler_t never throws exceptions; instead, it returns an error response
static server_http_context::handler_t ex_wrapper(server_http_context::handler_t func) {
    return [func = std::move(func)](const server_http_req & req) -> server_http_res_ptr {
        std::string message;
        error_type error;
        try {
            return func(req);
        } catch (const std::invalid_argument & e) {
            // treat invalid_argument as invalid request (400)
            error = ERROR_TYPE_INVALID_REQUEST;
            message = e.what();
        } catch (const std::exception & e) {
            // treat other exceptions as server error (500)
            error = ERROR_TYPE_SERVER;
            message = e.what();
        } catch (...) {
            error = ERROR_TYPE_SERVER;
            message = "unknown error";
        }

        auto res = std::make_unique<server_http_res>();
        res->status = 500;
        try {
            json error_data = format_error_response(message, error);
            res->status = json_value(error_data, "code", 500);
            res->data = safe_json_to_str({{ "error", error_data }});
            SRV_WRN("got exception: %s\n", res->data.c_str());
        } catch (const std::exception & e) {
            SRV_ERR("got another exception: %s | while handling exception: %s\n", e.what(), message.c_str());
            res->data = "Internal Server Error";
        }
        return res;
    };
}

// satisfies -Wmissing-declarations
int llama_server(int argc, char ** argv);

#if defined(_WIN32)
// D-EXEC-26-03: capture process state when the SEH filter does not fire
// (mid-leg silent death, std::terminate, fast-fail, Windows kernel kill).
// Adds a std::terminate handler that writes a stack trace to
// <dump_dir>/terminate-trace-<pid>-<HHMMSS>.txt and a background thread
// that snapshots working set + handle count every 5 seconds to
// <dump_dir>/snapshots/<pid>-<tick>.json. Snapshots older than 30 min
// are deleted on each tick. Active only when --crash-dump-dir is passed.
extern "C" {
USHORT NTAPI RtlCaptureStackBackTrace(
    ULONG FramesToSkip,
    ULONG FramesToCapture,
    PVOID * BackTrace,
    PULONG BackTraceHash);
}
namespace server_diag {
namespace {
char g_terminate_dump_dir[MAX_PATH] = { 0 };
}

static void write_terminate_trace(const char * reason) {
    if (g_terminate_dump_dir[0] == '\0') {
        return;
    }
    char path[MAX_PATH];
    SYSTEMTIME st;
    GetLocalTime(&st);
    snprintf(path, sizeof(path),
             "%s\\terminate-trace-%lu-%04u%02u%02u-%02u%02u%02u.txt",
             g_terminate_dump_dir, GetCurrentProcessId(),
             st.wYear, st.wMonth, st.wDay,
             st.wHour, st.wMinute, st.wSecond);
    HANDLE file = CreateFileA(path, GENERIC_WRITE, 0, nullptr, CREATE_NEW,
                              FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) {
        fprintf(stderr, "diag: terminate-trace create failed (gle=%lu)\n",
                GetLastError());
        return;
    }
    char hdr[256];
    int n = snprintf(hdr, sizeof(hdr),
        "reason=%s\npid=%lu\ntime=%04u-%02u-%02u %02u:%02u:%02u\n\nstack:\n",
        reason ? reason : "unknown", GetCurrentProcessId(),
        st.wYear, st.wMonth, st.wDay,
        st.wHour, st.wMinute, st.wSecond);
    DWORD w;
    WriteFile(file, hdr, (DWORD) n, &w, nullptr);

    void * frames[64] = { nullptr };
    USHORT n_frames = RtlCaptureStackBackTrace(0, 64, frames, nullptr);
    for (USHORT i = 0; i < n_frames; ++i) {
        n = snprintf(hdr, sizeof(hdr), "  #%02u: %p\n", i, frames[i]);
        WriteFile(file, hdr, (DWORD) n, &w, nullptr);
    }
    CloseHandle(file);
    fprintf(stderr, "diag: terminate-trace wrote %s\n", path);
}

static void __cdecl terminate_handler() {
    write_terminate_trace("std::terminate");
    fflush(stderr);
    fflush(stdout);
    std::abort();
}

static void install_terminate_trace_handler(const std::string & dump_dir) {
    if (dump_dir.empty()) {
        return;
    }
    strncpy(g_terminate_dump_dir, dump_dir.c_str(), MAX_PATH - 1);
    g_terminate_dump_dir[MAX_PATH - 1] = '\0';
    std::set_terminate(terminate_handler);
}

static void start_snapshot_thread(const std::string & dump_dir) {
    if (dump_dir.empty()) {
        return;
    }
    std::thread([dump_dir]() {
        char snaps_dir[MAX_PATH];
        snprintf(snaps_dir, sizeof(snaps_dir), "%s\\snapshots",
                 dump_dir.c_str());
        CreateDirectoryA(snaps_dir, nullptr);

        int tick = 0;
        while (true) {
            ++tick;
            char path[MAX_PATH];
            SYSTEMTIME st;
            GetLocalTime(&st);
            snprintf(path, sizeof(path),
                     "%s\\snapshots\\%lu-%07d-%04u%02u%02u-%02u%02u%02u.json",
                     snaps_dir, GetCurrentProcessId(), tick,
                     st.wYear, st.wMonth, st.wDay,
                     st.wHour, st.wMinute, st.wSecond);

            SIZE_T ws_min = 0;
            SIZE_T ws_max = 0;
            GetProcessWorkingSetSizeEx(GetCurrentProcess(), &ws_min, &ws_max,
                                       nullptr);
            DWORD handle_count = 0;
            GetProcessHandleCount(GetCurrentProcess(), &handle_count);

            HANDLE file = CreateFileA(path, GENERIC_WRITE, 0, nullptr,
                                      CREATE_NEW, FILE_ATTRIBUTE_NORMAL,
                                      nullptr);
            if (file != INVALID_HANDLE_VALUE) {
                char buf[1024];
                int n = snprintf(buf, sizeof(buf),
                    "{\"tick\":%d,\"pid\":%lu,\"timestamp\":\"%04u-%02u-%02uT%02u:%02u:%02u\","
                    "\"working_set_min_bytes\":%zu,\"working_set_max_bytes\":%zu,"
                    "\"handle_count\":%lu}\n",
                    tick, GetCurrentProcessId(),
                    st.wYear, st.wMonth, st.wDay,
                    st.wHour, st.wMinute, st.wSecond,
                    ws_min, ws_max, (unsigned long) handle_count);
                DWORD w;
                WriteFile(file, buf, (DWORD) n, &w, nullptr);
                CloseHandle(file);
            }

            Sleep(5000);

            WIN32_FIND_DATAA fd;
            char pattern[MAX_PATH];
            snprintf(pattern, sizeof(pattern), "%s\\*.json", snaps_dir);
            HANDLE h = FindFirstFileA(pattern, &fd);
            if (h != INVALID_HANDLE_VALUE) {
                FILETIME now_ft;
                GetSystemTimeAsFileTime(&now_ft);
                ULARGE_INTEGER now100ns;
                now100ns.LowPart = now_ft.dwLowDateTime;
                now100ns.HighPart = now_ft.dwHighDateTime;
                do {
                    if (fd.cFileName[0] == '.' &&
                        (fd.cFileName[1] == '\0' ||
                         (fd.cFileName[1] == '.' && fd.cFileName[2] == '\0'))) {
                        continue;
                    }
                    ULARGE_INTEGER ft;
                    ft.LowPart = fd.ftLastWriteTime.dwLowDateTime;
                    ft.HighPart = fd.ftLastWriteTime.dwHighDateTime;
                    ULONGLONG age_100ns = now100ns.QuadPart - ft.QuadPart;
                    // 30 min = 30 * 60 * 10^7 = 1.8e10
                    if (age_100ns > 18000000000ULL) {
                        char full[MAX_PATH];
                        snprintf(full, sizeof(full), "%s\\%s",
                                 snaps_dir, fd.cFileName);
                        DeleteFileA(full);
                    }
                } while (FindNextFileA(h, &fd));
                FindClose(h);
            }
        }
    }).detach();
}
} // namespace server_diag
#endif // _WIN32

int llama_server(int argc, char ** argv) {
    std::setlocale(LC_NUMERIC, "C");

    // Pre-scan argv for --crash-dump-dir so we can install the SEH filter
    // before any other initialization. We splice the flag out of argv
    // so common_params_parse does not see it. The filtered vector must
    // outlive common_params_parse, so it lives at function scope.
    std::string crash_dump_dir;
    std::vector<char *> filtered;
    filtered.reserve(argc);
    for (int i = 0; i < argc; ++i) {
        if (i + 1 < argc &&
            std::string(argv[i]) == "--crash-dump-dir" &&
            crash_dump_dir.empty()) {
            crash_dump_dir = argv[i + 1];
            ++i;
            continue;
        }
        filtered.push_back(argv[i]);
    }
    if (!crash_dump_dir.empty()) {
        argc = static_cast<int>(filtered.size());
        argv = filtered.data();
    }
    server_crash::install_crash_dump_handler(crash_dump_dir);
#if defined(_WIN32)
    // D-EXEC-26-03: hook std::terminate so we can diagnose mid-leg silent
    // death that bypasses the SEH filter. The snapshot thread is spawned
    // LATER (after common_init + common_params_parse) because spawning
    // it here races with CRT/CUDA initialization and causes a NULL write
    // inside KERNELBASE during process startup (verified Stage 24 -04).
    server_diag::install_terminate_trace_handler(crash_dump_dir);
#endif

    // own arguments required by this example
    common_params params;

    common_init();

    // start the stream session manager GC right after common init, before any HTTP route can
    // touch it. lifecycle is symmetric, stop_gc() runs in clean_up() before backend free
    g_stream_sessions.start_gc();

    if (!common_params_parse(argc, argv, params, LLAMA_EXAMPLE_SERVER)) {
        return 1;
    }

    // D-EXEC-26-03: snapshot thread disabled in this iteration.
    // Even when spawned AFTER common_params_parse, std::thread+detach
    // races with subsequent CUDA init and causes a NULL write inside
    // KERNELBASE during process startup. The snapshot capability will
    // be reintroduced via a different mechanism (sampling in the request
    // loop or pthreads without detach) in a follow-up iteration.
    // server_diag::start_snapshot_thread(crash_dump_dir);

    llama_backend_init();
    llama_numa_init(params.numa);

    common_models_handler models_handler;
    try {
        models_handler = common_models_handler_init(params, LLAMA_EXAMPLE_SERVER);
        if (common_models_handler_is_preset_repo(models_handler)) {
            // apply the preset and start the server in router mode
            common_models_handler_apply(models_handler, params);
        }
    } catch (const std::exception & e) {
        SRV_ERR("failed to fetch model metadata: %s\n", e.what());
        return 1;
    }

    // router server never loads a model and must not touch the GPU
    const bool is_router_server = params.model.path.empty()
                               && params.model.hf_repo.empty();

#ifdef LLAMA_STAGE39_LIVE_TEST_SEAM
    const char * stage39_opt_in_env = std::getenv("LLAMA_STAGE39_LIVE_TEST_SEAM");
    const bool stage39_opt_in = stage39_opt_in_env != nullptr && std::string(stage39_opt_in_env) == "1";
    const char * stage39_token_env = std::getenv("LLAMA_STAGE39_LIVE_TEST_TOKEN");
    const std::string stage39_token = stage39_token_env == nullptr ? "" : stage39_token_env;
    if (stage39_opt_in && (is_router_server ||
            (params.hostname != "127.0.0.1" && params.hostname != "::1") ||
            params.cache_mode_val != CACHE_MODE_HYBRID || !params.endpoint_metrics ||
            params.cache_ram_mib <= 0 || params.cache_cold_max_mib <= 0 ||
            params.n_parallel != 1 || stage39_token.size() < 32)) {
        SRV_ERR("%s", "Stage 39 live test seam prerequisites rejected\n");
        return 1;
    }
#endif

    // skip device enumeration so the CUDA primary context stays uncreated
    common_params_print_info(params, !is_router_server);

    if (!is_router_server) {
        // validate batch size for embeddings
        // embeddings require all tokens to be processed in a single ubatch
        // see https://github.com/ggml-org/llama.cpp/issues/12836
        if (params.embedding && params.n_batch > params.n_ubatch) {
            SRV_WRN("embeddings enabled with n_batch (%d) > n_ubatch (%d)\n", params.n_batch, params.n_ubatch);
            SRV_WRN("setting n_batch = n_ubatch = %d to avoid assertion failure\n", params.n_ubatch);
            params.n_batch = params.n_ubatch;
        }

        if (params.n_parallel < 0) {
            SRV_TRC("%s", "n_parallel is set to auto, using n_parallel = 4 and kv_unified = true\n");

            params.n_parallel = 4;
            params.kv_unified = true;
        }
    }

    // for consistency between server router mode and single-model mode, we set the same model name as alias
    auto model_name = params.model.get_name();
    if (params.model_alias.empty() && !model_name.empty()) {
        params.model_alias.insert(model_name);
    }

    // struct that contains llama context and inference
    server_context ctx_server;

    server_http_context ctx_http;
    if (!ctx_http.init(params)) {
        SRV_ERR("%s", "failed to initialize HTTP server\n");
        return 1;
    }

    //
    // Router
    //

    // register API routes
    server_child child; // only used in non-router mode
    server_routes routes(params, ctx_server);
#ifdef LLAMA_STAGE39_LIVE_TEST_SEAM
    if (stage39_opt_in) {
        routes.stage39_live_pressure_token = stage39_token;
    }
#endif
    server_tools tools;

    std::optional<server_models_routes> models_routes{};
    if (is_router_server) {
        // setup server instances manager
        try {
            models_routes.emplace(params, argc, argv);
        } catch (const std::exception & e) {
            SRV_ERR("failed to initialize router models: %s\n", e.what());
            return 1;
        }

        // proxy handlers
        // note: routes.get_health stays the same
        routes.get_metrics                 = models_routes->proxy_get;
        routes.post_props                  = models_routes->proxy_post;
        routes.post_completions            = models_routes->proxy_post;
        routes.post_completions_oai        = models_routes->proxy_post;
        routes.post_chat_completions       = models_routes->proxy_post;
        routes.post_control                = models_routes->proxy_post;
        routes.post_responses_oai          = models_routes->proxy_post;
        routes.post_transcriptions_oai     = models_routes->proxy_post;
        routes.post_anthropic_messages     = models_routes->proxy_post;
        routes.post_anthropic_count_tokens = models_routes->proxy_post;
        routes.post_infill                 = models_routes->proxy_post;
        routes.post_embeddings             = models_routes->proxy_post;
        routes.post_embeddings_oai         = models_routes->proxy_post;
        routes.post_rerank                 = models_routes->proxy_post;
        routes.post_tokenize               = models_routes->proxy_post;
        routes.post_detokenize             = models_routes->proxy_post;
        routes.post_apply_template         = models_routes->proxy_post;
        routes.post_chat_completions_tok   = models_routes->proxy_post;
        routes.post_responses_tok_oai      = models_routes->proxy_post;
        routes.get_lora_adapters           = models_routes->proxy_get;
        routes.post_lora_adapters          = models_routes->proxy_post;
        routes.get_slots                   = models_routes->proxy_get;
        routes.post_slots                  = models_routes->proxy_post;

        // custom routes for router
        routes.get_props                   = models_routes->get_router_props;
        routes.get_models                  = models_routes->get_router_models;

        ctx_http.post("/models",               ex_wrapper(models_routes->post_router_models));
        ctx_http.post("/models/load",          ex_wrapper(models_routes->post_router_models_load));
        ctx_http.post("/models/unload",        ex_wrapper(models_routes->post_router_models_unload));
        ctx_http.get ("/models/sse",           ex_wrapper(models_routes->get_router_models_sse));
        ctx_http.del ("/models",               ex_wrapper(models_routes->del_router_models));
    }

    ctx_http.get ("/health",                   ex_wrapper(routes.get_health)); // public endpoint (no API key check)
    ctx_http.get ("/v1/health",                ex_wrapper(routes.get_health)); // public endpoint (no API key check)
    ctx_http.get ("/metrics",                  ex_wrapper(routes.get_metrics));
    ctx_http.get ("/props",                    ex_wrapper(routes.get_props));
    ctx_http.post("/props",                    ex_wrapper(routes.post_props));
    ctx_http.get ("/models",                   ex_wrapper(routes.get_models)); // public endpoint (no API key check)
    ctx_http.get ("/v1/models",                ex_wrapper(routes.get_models)); // public endpoint (no API key check)
    ctx_http.post("/completion",               ex_wrapper(routes.post_completions)); // legacy
    ctx_http.post("/completions",              ex_wrapper(routes.post_completions));
    ctx_http.post("/v1/completions",           ex_wrapper(routes.post_completions_oai));
    ctx_http.post("/chat/completions",         ex_wrapper(routes.post_chat_completions));
    ctx_http.post("/v1/chat/completions",      ex_wrapper(routes.post_chat_completions));
    ctx_http.post("/v1/chat/completions/control", ex_wrapper(routes.post_control));
    ctx_http.post("/v1/responses",             ex_wrapper(routes.post_responses_oai));
    ctx_http.post("/responses",                ex_wrapper(routes.post_responses_oai));
    ctx_http.post("/v1/audio/transcriptions",  ex_wrapper(routes.post_transcriptions_oai));
    ctx_http.post("/audio/transcriptions",     ex_wrapper(routes.post_transcriptions_oai));
    ctx_http.post("/v1/messages",              ex_wrapper(routes.post_anthropic_messages)); // anthropic messages API
    ctx_http.post("/infill",                   ex_wrapper(routes.post_infill));
    ctx_http.post("/embedding",                ex_wrapper(routes.post_embeddings)); // legacy
    ctx_http.post("/embeddings",               ex_wrapper(routes.post_embeddings));
    ctx_http.post("/v1/embeddings",            ex_wrapper(routes.post_embeddings_oai));
    ctx_http.post("/rerank",                   ex_wrapper(routes.post_rerank));
    ctx_http.post("/reranking",                ex_wrapper(routes.post_rerank));
    ctx_http.post("/v1/rerank",                ex_wrapper(routes.post_rerank));
    ctx_http.post("/v1/reranking",             ex_wrapper(routes.post_rerank));
    ctx_http.post("/tokenize",                 ex_wrapper(routes.post_tokenize));
    ctx_http.post("/detokenize",               ex_wrapper(routes.post_detokenize));
    ctx_http.post("/apply-template",           ex_wrapper(routes.post_apply_template));
    // token counting
    ctx_http.post("/chat/completions/input_tokens",    ex_wrapper(routes.post_chat_completions_tok));
    ctx_http.post("/v1/chat/completions/input_tokens", ex_wrapper(routes.post_chat_completions_tok));
    ctx_http.post("/responses/input_tokens",           ex_wrapper(routes.post_responses_tok_oai));
    ctx_http.post("/v1/responses/input_tokens",        ex_wrapper(routes.post_responses_tok_oai));
    ctx_http.post("/v1/messages/count_tokens",         ex_wrapper(routes.post_anthropic_count_tokens)); // anthropic token counting
    // LoRA adapters hotswap
    ctx_http.get ("/lora-adapters",            ex_wrapper(routes.get_lora_adapters));
    ctx_http.post("/lora-adapters",            ex_wrapper(routes.post_lora_adapters));
    // Save & load slots
    ctx_http.get ("/slots",                    ex_wrapper(routes.get_slots));
    ctx_http.post("/slots/:id_slot",           ex_wrapper(routes.post_slots));
#ifdef LLAMA_STAGE39_LIVE_TEST_SEAM
    if (stage39_opt_in) {
        ctx_http.post("/debug/cache/stage39-live-pressure", ex_wrapper(routes.post_stage39_live_pressure));
    }
#endif

    // resumable streaming, the conversation_id is the session identity end to end. router and
    // child wire different handlers under the same paths: a child binds the local g_stream_sessions
    // backed factories, the router binds proxies that resolve the owning child through the
    // conv_id -> model map
    server_http_context::handler_t stream_get_h;
    server_http_context::handler_t streams_lookup_h;
    server_http_context::handler_t stream_delete_h;
    if (is_router_server) {
        stream_get_h     = models_routes->router_stream_get;
        streams_lookup_h = models_routes->router_streams_lookup;
        stream_delete_h  = models_routes->router_stream_delete;
    } else {
        stream_get_h     = make_stream_get_handler();
        streams_lookup_h = make_streams_lookup_handler();
        stream_delete_h  = make_stream_delete_handler();
    }
    ctx_http.get ("/v1/stream/:conv_id",       ex_wrapper(stream_get_h));
    // POST /v1/streams/lookup with body {"conversation_ids": [...]}. you can only ask for ids
    // you already own (the WebUI passes the convs visible in its sidebar). the server never
    // lists ids it has not been asked about, so a random caller cannot enumerate live sessions
    ctx_http.post("/v1/streams/lookup",        ex_wrapper(streams_lookup_h));
    ctx_http.del ("/v1/stream/:conv_id",       ex_wrapper(stream_delete_h));

    // Google Cloud Platform (Vertex AI) compat
    ctx_http.register_gcp_compat();

    // return 403 for disabled features
    server_http_context::handler_t res_403 = [](const server_http_req &) {
        auto res = std::make_unique<server_http_res>();
        res->status = 403;
        res->data = safe_json_to_str({
            {"error", {
                {"message", "this feature is disabled"},
                {"type", "feature_disabled"},
            }}
        });
        return res;
    };

    // CORS proxy (EXPERIMENTAL, only used by the Web UI for MCP)
    if (params.ui_mcp_proxy) {
        SRV_WRN("%s", "-----------------\n");
        SRV_WRN("%s", "CORS proxy is enabled, do not expose server to untrusted environments\n");
        SRV_WRN("%s", "This feature is EXPERIMENTAL and may be removed or changed in future versions\n");
        SRV_WRN("%s", "-----------------\n");
        ctx_http.get ("/cors-proxy",      ex_wrapper(proxy_handler_get));
        ctx_http.post("/cors-proxy",      ex_wrapper(proxy_handler_post));
    } else {
        ctx_http.get ("/cors-proxy",      ex_wrapper(res_403));
        ctx_http.post("/cors-proxy",      ex_wrapper(res_403));
    }

    // EXPERIMENTAL built-in tools
    if (!params.server_tools.empty()) {
        try {
            tools.setup(params.server_tools);
        } catch (const std::exception & e) {
            SRV_ERR("tools setup failed: %s\n", e.what());
            return 1;
        }
        SRV_WRN("%s", "-----------------\n");
        SRV_WRN("%s", "Built-in tools are enabled, do not expose server to untrusted environments\n");
        SRV_WRN("%s", "This feature is EXPERIMENTAL and may be changed in the future\n");
        SRV_WRN("%s", "-----------------\n");
        ctx_http.get ("/tools",           ex_wrapper(tools.handle_get));
        ctx_http.post("/tools",           ex_wrapper(tools.handle_post));
    } else {
        ctx_http.get ("/tools",           ex_wrapper(res_403));
        ctx_http.post("/tools",           ex_wrapper(res_403));
    }

    //
    // Handle downloading model
    //

    if (child.is_child() && child.get_mode() == SERVER_CHILD_MODE_DOWNLOAD) {
        return child.run_download(params);
    } else if (!is_router_server) {
        // single-model mode (NOT spawned by router)
        try {
            common_models_handler_apply(models_handler, params);
        } catch (const std::exception & e) {
            SRV_ERR("failed to download model: %s\n", e.what());
            return 1;
        }
    }

    //
    // Start the server
    //

    std::function<void()> clean_up;

    if (is_router_server) {
        SRV_INF("%s", "starting server in router mode. models will be automatically loaded on-demand\n");

        clean_up = [&models_routes]() {
            SRV_INF("%s: cleaning up before exit...\n", __func__);
            // stop the session GC first, it finalizes live sessions and wakes pending readers
            g_stream_sessions.stop_gc();
            if (models_routes.has_value()) {
                models_routes->stopping.store(true); // maybe redundant, but just to be safe
                models_routes->models.unload_all();
            }
            llama_backend_free();
        };

        if (!ctx_http.start()) {
            clean_up();
            SRV_ERR("%s", "exiting due to HTTP server error\n");
            return 1;
        }
        ctx_http.is_ready.store(true);

        shutdown_handler = [&](int) {
            if (models_routes.has_value()) {
                // important to disconnect any SSE clients
                models_routes->stopping.store(true);
            }
            ctx_http.stop();
        };

    } else {
        // setup clean up function, to be called before exit
        clean_up = [&ctx_http, &ctx_server]() {
            SRV_INF("%s: cleaning up before exit...\n", __func__);
            // stop the session GC first, it finalizes live sessions and wakes pending readers
            g_stream_sessions.stop_gc();
            ctx_http.stop();
            ctx_server.terminate();
            llama_backend_free();
        };

        // start the HTTP server before loading the model to be able to serve /health requests
        if (!ctx_http.start()) {
            clean_up();
            SRV_ERR("%s", "exiting due to HTTP server error\n");
            return 1;
        }

        // setup communication child --> router if necessary
        if (child.is_child()) {
            ctx_server.set_state_callback([&](server_state state, json payload) {
                child.notify_to_router(server_state_to_str(state), payload);
            });
        }

        if (!ctx_server.load_model(params)) {
            clean_up();
            if (ctx_http.thread.joinable()) {
                ctx_http.thread.join();
            }
            SRV_ERR("%s", "exiting due to model loading error\n");
            return 1;
        }

        routes.update_meta(ctx_server);
        ctx_http.is_ready.store(true);

        SRV_INF("%s", "model loaded\n");

        shutdown_handler = [&](int) {
            // this will unblock start_loop()
            ctx_server.terminate();
        };
    }

    // TODO: refactor in common/console
#if defined (__unix__) || (defined (__APPLE__) && defined (__MACH__))
    struct sigaction sigint_action;
    sigint_action.sa_handler = signal_handler;
    sigemptyset (&sigint_action.sa_mask);
    sigint_action.sa_flags = 0;
    sigaction(SIGINT, &sigint_action, NULL);
    sigaction(SIGTERM, &sigint_action, NULL);
#elif defined (_WIN32)
    auto console_ctrl_handler = +[](DWORD ctrl_type) -> BOOL {
        return (ctrl_type == CTRL_C_EVENT) ? (signal_handler(SIGINT), true) : false;
    };
    SetConsoleCtrlHandler(reinterpret_cast<PHANDLER_ROUTINE>(console_ctrl_handler), true);
#endif

    SRV_INF("listening on %s\n", ctx_http.listening_address.c_str());

    if (is_router_server) {
        SRV_WRN("%s", "NOTE: router mode is experimental\n");
        SRV_WRN("%s", "      it is not recommended to use this mode in untrusted environments\n");

        if (!params.models_preset_hf.empty()) {
            SRV_WRN(      "NOTE: using preset.ini from HF repo '%s'\n", params.models_preset_hf.c_str());
            SRV_WRN("%s", "      please only use presets that you can trust! Unknown presets may be unsafe\n");
        }

        if (ctx_http.thread.joinable()) {
            ctx_http.thread.join(); // keep the main thread alive
        }

        // when the HTTP server stops, clean up and exit
        clean_up();
    } else {
        // optionally, notify router server that this instance is ready
        std::thread monitor_thread;
        if (child.is_child()) {
            monitor_thread = child.setup(shutdown_handler);
            child.notify_to_router(server_state_to_str(SERVER_STATE_READY), routes.get_model_info());
        }

        // this call blocks the main thread until queue_tasks.terminate() is called
        ctx_server.start_loop();

        clean_up();
        if (ctx_http.thread.joinable()) {
            ctx_http.thread.join();
        }
        if (monitor_thread.joinable()) {
            monitor_thread.join();
        }

        auto * ll_ctx = ctx_server.get_llama_context();
        if (ll_ctx != nullptr) {
            common_memory_breakdown_print(ll_ctx);
        }
    }

    return 0;
}
