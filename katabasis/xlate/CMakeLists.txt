cmake_minimum_required(VERSION 3.21)
project(xlate C CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(LLVM CONFIG REQUIRED)

# A checkout other than the shared deps/rellume -- scripts/deps.sh's own clean-room reproduction,
# say -- passes -DRELLUME_DIR=... on the command line; nothing else has to change to build against it.
if(NOT DEFINED RELLUME_DIR)
  set(RELLUME_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../deps/rellume)
endif()
add_executable(xlate src/xlate.cpp src/macho.cpp src/objc.cpp src/exports.cpp src/tsd_scan.cpp)
# farmdec.h only: xlate calls the decoder directly for tsd_scan.cpp's own static analysis (the
# lift itself goes through rellume/rellume.h as before); librellume.dylib already exports
# fad_decode and friends, so this links against the same decoder rellume uses rather than a
# second, separately built copy.
target_include_directories(xlate PRIVATE ${LLVM_INCLUDE_DIRS} ${RELLUME_DIR}/include ${RELLUME_DIR}/build/data/rellume ${RELLUME_DIR}/subprojects/farmdec)
target_link_libraries(xlate PRIVATE LLVM ${RELLUME_DIR}/build/src/librellume.dylib)
set_target_properties(xlate PROPERTIES BUILD_RPATH ${RELLUME_DIR}/build/src)
find_package(Clang CONFIG REQUIRED)
add_executable(xlgen src/xlgen.cpp)
target_link_libraries(xlgen PRIVATE clang-cpp LLVM)
target_include_directories(xlgen PRIVATE ${LLVM_INCLUDE_DIRS} ${CLANG_INCLUDE_DIRS})
