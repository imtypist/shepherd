# Copyright (c) Open Enclave SDK contributors.
# Licensed under the MIT License.
add_custom_command(
  OUTPUT shepherd_u.h shepherd_u.c shepherd_args.h
  DEPENDS ${PROJECT_SOURCE_DIR}/shepherd.edl
  COMMAND
    openenclave::oeedger8r --untrusted ${PROJECT_SOURCE_DIR}/shepherd.edl
    --search-path ${OE_INCLUDEDIR} --search-path
    ${OE_INCLUDEDIR}/openenclave/edl/sgx)

set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)

add_executable(shepherd_host host.cpp
                               ${CMAKE_CURRENT_BINARY_DIR}/shepherd_u.c)

if (WIN32)
  copy_oedebugrt_target(shepherd_host_oedebugrt)
  add_dependencies(shepherd_host shepherd_host_oedebugrt)
endif ()

target_include_directories(
  shepherd_host PRIVATE # Needed for the generated file shepherd_u.h
                          ${CMAKE_CURRENT_BINARY_DIR} ${PROJECT_SOURCE_DIR}/../rpclib/include)

target_link_libraries(shepherd_host openenclave::oehost rpc Threads::Threads)
