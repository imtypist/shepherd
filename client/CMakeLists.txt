cmake_minimum_required(VERSION 3.11)

project("Shepherd Client" LANGUAGES C CXX)

set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)
add_subdirectory(rpclib-2.3.0)

add_executable(client client.cpp)

target_include_directories(client PRIVATE rpclib-2.3.0/include)

target_link_libraries(client rpc Threads::Threads)

set_property(TARGET client PROPERTY CXX_STANDARD 14)