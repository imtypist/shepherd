# Copyright (c) Open Enclave SDK contributors.
# Licensed under the MIT License.

# Use the edger8r to generate C bindings from the EDL file.
add_custom_command(
  OUTPUT shepherd_t.h shepherd_t.c shepherd_args.h
  DEPENDS ${CMAKE_SOURCE_DIR}/shepherd.edl
  COMMAND
    openenclave::oeedger8r --trusted ${CMAKE_SOURCE_DIR}/shepherd.edl
    --search-path ${OE_INCLUDEDIR} --search-path
    ${OE_INCLUDEDIR}/openenclave/edl/sgx)

set(EEVM_INCLUDE_DIRS
  ${CMAKE_SOURCE_DIR}/eEVM/3rdparty
  ${CMAKE_SOURCE_DIR}/eEVM/include
)

set(EEVM_SIMPLE_SRCS
  ${CMAKE_SOURCE_DIR}/eEVM/src/simple/simpleaccount.cpp
  ${CMAKE_SOURCE_DIR}/eEVM/src/simple/simpleglobalstate.cpp
  ${CMAKE_SOURCE_DIR}/eEVM/src/simple/simplestorage.cpp
)

set(EEVM_CORE_SRCS
  ${CMAKE_SOURCE_DIR}/eEVM/src/disassembler.cpp
  ${CMAKE_SOURCE_DIR}/eEVM/src/processor.cpp
  ${CMAKE_SOURCE_DIR}/eEVM/src/stack.cpp
  ${CMAKE_SOURCE_DIR}/eEVM/src/transaction.cpp
  ${CMAKE_SOURCE_DIR}/eEVM/src/util.cpp
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

if (LVI_MITIGATION MATCHES ControlFlow)
  # Helper to enable compiler options for LVI mitigation.
  apply_lvi_mitigation(enclave)
  # Link against LVI-mitigated libraries.
  target_link_libraries(
    enclave openenclave::oeenclave-lvi-cfg
    openenclave::oecrypto${OE_CRYPTO_LIB}-lvi-cfg openenclave::oelibcxx-lvi-cfg eevm)
else ()
  target_link_libraries(
    enclave openenclave::oeenclave openenclave::oecrypto${OE_CRYPTO_LIB}
    openenclave::oelibcxx eevm)
endif ()
