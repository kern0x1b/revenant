cmake_minimum_required(VERSION 3.21)
project(test_package LANGUAGES CXX)

find_package(libcxx REQUIRED CONFIG)

add_executable(test_package test_package.cpp)
target_compile_features(test_package PRIVATE cxx_std_23)
target_link_libraries(test_package PRIVATE libcxx::libcxx)
