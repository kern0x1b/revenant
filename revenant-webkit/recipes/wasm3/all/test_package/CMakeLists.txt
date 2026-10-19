cmake_minimum_required(VERSION 3.21)
project(test_package LANGUAGES C)

find_package(wasm3 REQUIRED CONFIG)

add_executable(test_package test_package.c)
target_link_libraries(test_package PRIVATE wasm3::wasm3)
