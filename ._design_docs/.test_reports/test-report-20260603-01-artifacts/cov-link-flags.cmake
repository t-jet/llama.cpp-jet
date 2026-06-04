set(CLANG_RT_PROFILE_LIB "C:/PROGRA~1/MIB055~1/18/Community/VC/Tools/Llvm/x64/lib/clang/20/lib/windows/clang_rt.profile-x86_64.lib")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fprofile-instr-generate" CACHE STRING "" FORCE)
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -fprofile-instr-generate" CACHE STRING "" FORCE)
set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} -fprofile-instr-generate" CACHE STRING "" FORCE)
# Also force-link the runtime into every executable by injecting it via interface link.
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${CLANG_RT_PROFILE_LIB}" CACHE STRING "" FORCE)
