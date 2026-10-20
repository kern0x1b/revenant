package("blocksruntime")
    set_kind("library", {headeronly = true})
    set_homepage("https://github.com/mackyle/blocksruntime")
    set_description("The Blocks runtime of compiler-rt as mackyle packages it, its sources only: recompiler compiles them into every translated app's guest library")
    set_license("MIT")

    add_urls("https://github.com/mackyle/blocksruntime.git")
    add_versions("2017.10.27", "9cc93ae2b58676c23fd02cf0c686fa15b7a3ff81")

    on_install(function (package)
        local sources = package:installdir("src")
        for _, file in ipairs({"Block.h", "Block_private.h", "data.c", "runtime.c"}) do
            os.cp(path.join("BlocksRuntime", file), sources .. "/")
        end
        io.writefile(path.join(sources, "config.h"), "#define HAVE_SYNC_BOOL_COMPARE_AND_SWAP_INT 1\n#define HAVE_SYNC_BOOL_COMPARE_AND_SWAP_LONG 1\n")
        os.cp("BlocksRuntime/LICENSE.TXT", package:installdir("licenses") .. "/")
    end)

    on_test(function (package)
        for _, file in ipairs({"Block.h", "Block_private.h", "config.h", "data.c", "runtime.c"}) do
            assert(os.isfile(path.join(package:installdir("src"), file)), file .. " is not installed")
        end
    end)
