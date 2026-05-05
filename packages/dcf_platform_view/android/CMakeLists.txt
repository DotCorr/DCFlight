cmake_minimum_required(VERSION 3.10)
project(dcf_platform_view_ffi)

add_library(dcf_platform_view_ffi SHARED src/main/cpp/dcf_platform_view_ffi.c)
target_include_directories(dcf_platform_view_ffi PRIVATE ${ANDROID_NDK}/toolchains/llvm/prebuilt/${ANDROID_HOST_TAG}/sysroot/usr/include)
find_library(log-lib log)
target_link_libraries(dcf_platform_view_ffi ${log-lib})
