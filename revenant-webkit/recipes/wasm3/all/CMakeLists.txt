cmake_minimum_required(VERSION 3.21)
project(wasm3 C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED YES)
set(CMAKE_C_EXTENSIONS YES)

include(CheckCSourceCompiles)
check_c_source_compiles("static __thread int value; int main(void) { return value; }" M3_TOOLCHAIN_HAS_THREAD_LOCAL)

add_subdirectory(src/source)

if(NOT M3_TOOLCHAIN_HAS_THREAD_LOCAL)
    target_compile_definitions(m3 PRIVATE "M3_THREAD_LOCAL=" M3_HAS_THREAD_LOCAL=0)
endif()

file(GLOB M3_HEADERS src/source/*.h)
install(TARGETS m3 ARCHIVE DESTINATION lib)
install(FILES ${M3_HEADERS} DESTINATION include)
