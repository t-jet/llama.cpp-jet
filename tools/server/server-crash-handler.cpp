#include "server-crash-handler.h"

#include <cstdio>
#include <string>

#if defined(_WIN32)
#include <windows.h>
#include <dbghelp.h>
#endif

namespace server_crash {

namespace {
std::string g_crash_dump_dir;

#if defined(_WIN32)
LONG WINAPI write_minidump_on_unhandled_exception(EXCEPTION_POINTERS * exception_pointers) {
    if (g_crash_dump_dir.empty() || exception_pointers == nullptr) {
        return EXCEPTION_EXECUTE_HANDLER;
    }

    char path[MAX_PATH] = { 0 };
    SYSTEMTIME st;
    GetLocalTime(&st);

    snprintf(path, sizeof(path), "%s\\llama-server-%lu-%04u%02u%02u-%02u%02u%02u.dmp",
             g_crash_dump_dir.c_str(),
             GetCurrentProcessId(),
             st.wYear, st.wMonth, st.wDay,
             st.wHour, st.wMinute, st.wSecond);

    HANDLE file = CreateFileA(path, GENERIC_WRITE, 0, nullptr, CREATE_NEW,
                              FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) {
        fprintf(stderr, "crash-dump: failed to create %s (GetLastError=%lu)\n",
                path, GetLastError());
        return EXCEPTION_EXECUTE_HANDLER;
    }

    MINIDUMP_EXCEPTION_INFORMATION exception_info;
    exception_info.ThreadId = GetCurrentThreadId();
    exception_info.ExceptionPointers = exception_pointers;
    exception_info.ClientPointers = FALSE;

    BOOL ok;
    __try {
        ok = MiniDumpWriteDump(GetCurrentProcess(), GetCurrentProcessId(), file,
                               static_cast<MINIDUMP_TYPE>(MiniDumpWithIndirectlyReferencedMemory |
                                                          MiniDumpWithThreadInfo),
                               &exception_info, nullptr, nullptr);
    } __except (GetExceptionCode() == EXCEPTION_EXECUTE_HANDLER
                ? EXCEPTION_EXECUTE_HANDLER : EXCEPTION_EXECUTE_HANDLER) {
        ok = FALSE;
        fprintf(stderr, "crash-dump: MiniDumpWriteDump threw %lu while writing %s\n",
                GetExceptionCode(), path);
    }

    CloseHandle(file);

    if (!ok) {
        fprintf(stderr, "crash-dump: MiniDumpWriteDump failed (GetLastError=%lu) for %s\n",
                GetLastError(), path);
    } else {
        fprintf(stderr, "crash-dump: wrote %s\n", path);
    }

    return EXCEPTION_EXECUTE_HANDLER;
}
#endif // _WIN32
} // namespace

void install_crash_dump_handler(const std::string & dump_dir) {
    g_crash_dump_dir = dump_dir;
#if defined(_WIN32)
    if (g_crash_dump_dir.empty()) {
        return;
    }
    SetUnhandledExceptionFilter(write_minidump_on_unhandled_exception);
#endif
}

void clear_crash_dump_dir() {
    g_crash_dump_dir.clear();
}

} // namespace server_crash