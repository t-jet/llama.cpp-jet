include_directories(${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_BINARY_DIR})

# server-context containing the core server logic, used by llama-server and CLI

set(TARGET server-context)

option(LLAMA_STAGE39_LIVE_TEST_SEAM "Enable the guarded Stage 39 live pressure test seam" OFF)

add_library(${TARGET} STATIC
    server-chat.cpp
    server-chat.h
    server-task.cpp
    server-task.h
    server-queue.cpp
    server-queue.h
    server-common.cpp
    server-common.h
    server-context.cpp
    server-context.h
    server-stream.cpp
    server-stream.h
    server-tools.cpp
    server-tools.h
    server-cache-controller.cpp
    server-cache-controller.h
    server-cache-legacy.h
    server-cache-policy-lru.cpp
    server-cache-policy-lru.h
    server-cache-graph.cpp
    server-cache-graph.h
    server-cache-hybrid.cpp
    server-cache-hybrid.h
    server-cache-store-cold.cpp
    server-cache-store-cold.h
    server-cache-io-worker.cpp
    server-cache-io-worker.h
    server-mcp.cpp
    server-mcp.h
    server-schema.cpp
    server-schema.h
)

if (BUILD_SHARED_LIBS)
    set_target_properties(${TARGET} PROPERTIES POSITION_INDEPENDENT_CODE ON)
endif()

if (WIN32)
    target_sources(${TARGET} PRIVATE
        server-crash-handler.cpp
        server-crash-handler.h
    )
    target_link_libraries(${TARGET} PUBLIC dbghelp bcrypt)
endif()

target_include_directories(${TARGET} PRIVATE ../mtmd)
target_include_directories(${TARGET} PRIVATE ${CMAKE_SOURCE_DIR})
target_compile_definitions(${TARGET} PRIVATE LLAMA_SERVER_CACHE_TESTS)
if (LLAMA_STAGE39_LIVE_TEST_SEAM)
    target_compile_definitions(${TARGET} PUBLIC LLAMA_STAGE39_LIVE_TEST_SEAM)
endif()
target_link_libraries(${TARGET} PUBLIC llama-common mtmd ${CMAKE_THREAD_LIBS_INIT})

# llama-server-impl: server logic, reusable by app

set(TARGET llama-server-impl)

add_library(${TARGET}
    server.cpp
    server-http.cpp
    server-http.h
    server-models.cpp
    server-models.h
)
set_target_properties(${TARGET} PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)

target_include_directories(${TARGET} PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_include_directories(${TARGET} PRIVATE ../mtmd ${CMAKE_SOURCE_DIR})
target_link_libraries(${TARGET} PUBLIC server-context llama-ui cpp-httplib ${CMAKE_THREAD_LIBS_INIT})

if(LLAMA_TOOLS_INSTALL)
    install(TARGETS ${TARGET} LIBRARY)
endif()

# llama-server executable

set(TARGET llama-server)

add_executable(${TARGET} main.cpp)
install(TARGETS ${TARGET} RUNTIME)

target_link_libraries(${TARGET} PRIVATE llama-server-impl)
target_compile_features(${TARGET} PRIVATE cxx_std_17)
