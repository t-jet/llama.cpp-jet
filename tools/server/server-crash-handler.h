#pragma once

#include <string>

namespace server_crash {

// install_crash_dump_handler wires up a Windows unhandled-exception
// filter that writes a minidump to <dump_dir>/llama-server-<pid>-<ts>.dmp
// when the OS terminates the process on an unhandled exception.
//
// On non-Windows builds this is a no-op so call sites can stay
// unconditional.
void install_crash_dump_handler(const std::string & dump_dir);

// clear_crash_dump_dir removes the stored dump dir so a subsequent
// process (e.g. a worker child) does not inherit the parent's path.
void clear_crash_dump_dir();

} // namespace server_crash