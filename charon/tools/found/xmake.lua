-- The declaration extractor (decls.cc): libclang's C API, read from the Command Line Tools' libclang.dylib (the toolchain pin,
-- recorded in the spec snapshot and checked by ir.lua). The clang-c headers come from the pinned package llvm-clang-c (packages/l),
-- which is include/clang-c of the llvm-project 21.1.0 release: the Command Line Tools do not ship them.
-- Build: xmake -P tools/found; the binary is in the build directory (build/), never in the source tree.
set_project("found")
set_defaultmode("release")
set_languages("c++20")

add_repositories("charon ../..")
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
