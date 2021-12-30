cmake_minimum_required(VERSION 3.11)

project("Shepherd Client" LANGUAGES C CXX)

set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)

add_subdirectory(${PROJECT_SOURCE_DIR}/../rpclib ${CMAKE_BINARY_DIR}/rpclib)

add_executable(client client.cpp)

target_include_directories(client PRIVATE ${PROJECT_SOURCE_DIR}/../rpclib/include)

target_link_libraries(client rpc Threads::Threads)

set_property(TARGET client PROPERTY CXX_STANDARD 14)