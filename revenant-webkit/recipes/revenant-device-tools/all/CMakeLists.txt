cmake_minimum_required(VERSION 3.21)
project(revenant_device_tools C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED YES)
set(CMAKE_C_EXTENSIONS YES)
set(CMAKE_MACOSX_BUNDLE OFF)

foreach(tool revmem revpid revtouch raise-memory-limit)
    add_executable(${tool} tools/${tool}.c)
    install(TARGETS ${tool} RUNTIME DESTINATION bin)
endforeach()

target_link_libraries(revtouch PRIVATE "-framework IOKit" "-framework CoreFoundation")
