# Copyright (c) Open Enclave SDK contributors.
# Licensed under the MIT License.

cmake_minimum_required(VERSION 3.11)

# Setting the cmake compiler when LVI mitigation is not enabled. If the CC
# environment variable has been specified or the if CMAKE_C_COMPILER cmake
# variable has been passed to cmake, use the C compiler that has been specified.
# Otherwise, prefer clang. Same for C++ compiler. This must be done before
# the `project` command.
if (UNIX)
  if (NOT DEFINED ENV{CC} AND NOT DEFINED CMAKE_C_COMPILER)
    find_program(CMAKE_C_COMPILER clang-10 clang)
  endif ()
  if (NOT DEFINED ENV{CXX} AND NOT DEFINED CMAKE_CXX_COMPILER)
    find_program(CMAKE_CXX_COMPILER clang++-10 clang++)
  endif ()
endif ()

# set(CMAKE_C_COMPILER "/usr/bin/gcc")
# set(CMAKE_CXX_COMPILER "/usr/bin/g++")

project("Shepherd Server" LANGUAGES C CXX)

# Currently the `OpenEnclave` package depends on `project()`.
find_package(OpenEnclave CONFIG REQUIRED)

set(CMAKE_CXX_STANDARD 17)

set(OE_CRYPTO_LIB
    mbedtls
    CACHE STRING "Crypto library used by enclaves.")

add_subdirectory(eEVM)
add_subdirectory(enclave)
add_subdirectory(${PROJECT_SOURCE_DIR}/../rpclib ${CMAKE_BINARY_DIR}/rpclib)
add_subdirectory(host)

# Generate key
add_custom_command(
  OUTPUT private.pem public.pem
  COMMAND openssl genrsa -out private.pem -3 3072
  COMMAND openssl rsa -in private.pem -pubout -out public.pem)

# Sign enclave
add_custom_command(
  OUTPUT enclave/enclave.signed
  DEPENDS enclave enclave/shepherd.conf private.pem
  COMMAND openenclave::oesign sign -e $<TARGET_FILE:enclave> -c
          ${PROJECT_SOURCE_DIR}/enclave/shepherd.conf -k private.pem)

add_custom_target(sign ALL DEPENDS enclave/enclave.signed)

if ((NOT DEFINED ENV{OE_SIMULATION}) OR (NOT $ENV{OE_SIMULATION}))
  add_custom_target(
    run
    DEPENDS shepherd_host sign
    COMMAND shepherd_host ${CMAKE_BINARY_DIR}/enclave/enclave.signed)
endif ()

add_custom_target(
  simulate
  DEPENDS shepherd_host sign
  COMMAND shepherd_host ${CMAKE_BINARY_DIR}/enclave/enclave.signed --simulate)
