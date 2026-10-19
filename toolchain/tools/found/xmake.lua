set_project("found")
set_defaultmode("release")
set_languages("c++20")

add_repositories("revenant ../..")
add_requires("llvm-clang-c 21.1.0")

local clang_lib = "/Library/Developer/CommandLineTools/usr/lib"

option("clang-lib")
    set_default(clang_lib)
    set_description("Directory of the libclang.dylib the extractor links against (the Command Line Tools' by default)")
option_end()

target("decls")
    set_kind("binary")
    add_files("decls.cc")
    add_packages("llvm-clang-c")
    add_linkdirs(get_config("clang-lib") or clang_lib)
    add_rpathdirs(get_config("clang-lib") or clang_lib)
    add_links("clang")
