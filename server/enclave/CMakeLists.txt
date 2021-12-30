# Copyright (c) Open Enclave SDK contributors.
# Licensed under the MIT License.

# Use the edger8r to generate C bindings from the EDL file.
add_custom_command(
  OUTPUT shepherd_t.h shepherd_t.c shepherd_args.h
  DEPENDS ${PROJECT_SOURCE_DIR}/shepherd.edl
  COMMAND
    openenclave::oeedger8r --trusted ${PROJECT_SOURCE_DIR}/shepherd.edl
    --search-path ${OE_INCLUDEDIR} --search-path
    ${OE_INCLUDEDIR}/openenclave/edl/sgx)

set(EEVM_INCLUDE_DIRS
  ${PROJECT_SOURCE_DIR}/eEVM/3rdparty
  ${PROJECT_SOURCE_DIR}/eEVM/include
)

set(EEVM_SIMPLE_SRCS
  ${PROJECT_SOURCE_DIR}/eEVM/src/simple/simpleaccount.cpp
  ${PROJECT_SOURCE_DIR}/eEVM/src/simple/simpleglobalstate.cpp
  ${PROJECT_SOURCE_DIR}/eEVM/src/simple/simplestorage.cpp
)

set(EEVM_CORE_SRCS
  ${PROJECT_SOURCE_DIR}/eEVM/src/disassembler.cpp
  ${PROJECT_SOURCE_DIR}/eEVM/src/processor.cpp
  ${PROJECT_SOURCE_DIR}/eEVM/src/stack.cpp
  ${PROJECT_SOURCE_DIR}/eEVM/src/transaction.cpp
  ${PROJECT_SOURCE_DIR}/eEVM/src/util.cpp
)

add_executable(enclave enc.c ${CMAKE_CURRENT_BINARY_DIR}/shepherd_t.c
                helloevm.cpp helloevm.h ${EEVM_SIMPLE_SRCS} ${EEVM_CORE_SRCS}
)

if (WIN32)
  maybe_build_using_clangw(enclave)
endif ()

target_compile_definitions(enclave PUBLIC OE_API_VERSION=2)

# Need for the generated file shepherd_t.h
target_include_directories(enclave PRIVATE ${CMAKE_CURRENT_BINARY_DIR} ${EEVM_INCLUDE_DIRS})


target_link_libraries(
    enclave openenclave::oeenclave openenclave::oecrypto${OE_CRYPTO_LIB}
    openenclave::oelibcxx eevm)
