package("llvm-clang-c")
    set_kind("library", {headeronly = true})
    set_homepage("https://clang.llvm.org/docs/External.html")
    set_description("The clang-c headers: the C API of libclang, installed as include/clang-c and nothing else of clang. The declaration extractor reads the iOS SDK through it, against the libclang the Command Line Tools ship.")
    set_license("Apache-2.0 WITH LLVM-exception")

    -- The clang release tarball is 27 MB; the whole llvm-project release is 159 MB, and only include/clang-c is kept. The
    -- sha256 is the release asset's own, computed from the download of llvmorg-21.1.0.
    add_urls("https://github.com/llvm/llvm-project/releases/download/llvmorg-$(version)/clang-$(version).src.tar.xz")
    add_versions("21.1.0", "4c8d148d4c5931c65116d1a5fdebd9d9579c3d135f36551b1cad53e220986cb2")

    on_install(function (package)
        local headers = package:installdir("include", "clang-c")
        os.mkdir(headers)
        os.cp("include/clang-c/*.h", headers .. "/")
        os.mkdir(package:installdir("licenses"))
        os.cp("LICENSE.TXT", package:installdir("licenses") .. "/")
    end)
