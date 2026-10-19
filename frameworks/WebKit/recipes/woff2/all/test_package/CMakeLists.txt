cmake_minimum_required(VERSION 3.21)
project(test_package LANGUAGES CXX)

find_package(woff2 REQUIRED CONFIG)

add_executable(test_package test_package.cpp)
target_compile_features(test_package PRIVATE cxx_std_17)
target_link_libraries(test_package PRIVATE woff2::woff2)
