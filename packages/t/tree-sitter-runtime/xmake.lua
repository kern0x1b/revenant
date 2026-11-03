package("tree-sitter-runtime")
    set_kind("library", {headeronly = true})
    set_homepage("https://tree-sitter.github.io/tree-sitter/")
    set_description("The tree-sitter 0.26.3 runtime, from its tagged source archive: the C amalgamation of lib/src with the public api.h, the parser that the code highlighter of react-native-enriched-markdown runs; WASM is left out, as the runtime build leaves it out")
    set_license("MIT")

    add_urls("https://github.com/tree-sitter/tree-sitter/archive/refs/tags/v$(version).tar.gz")
    add_versions("0.26.3", "7f4a7cf0a2cd217444063fe2a4d800bc9d21ed609badc2ac20c0841d67166550")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "1", readonly = true})

    on_install(function (package)
        local function copy_tree(from, to)
            os.mkdir(to)
            for _, file in ipairs(os.files(path.join(from, "*"))) do
                os.cp(file, to)
            end
            for _, dir in ipairs(os.dirs(path.join(from, "*"))) do
                copy_tree(dir, path.join(to, path.filename(dir)))
            end
        end
        local lib = "lib"
        assert(os.isdir(path.join(lib, "src")), "the runtime archive has no lib/src")
        local out = package:installdir("tree-sitter")
        copy_tree(path.join(lib, "src"), path.join(out, "src"))
        os.mkdir(path.join(out, "include", "tree_sitter"))
        os.cp(path.join(lib, "include", "tree_sitter", "api.h"), path.join(out, "include", "tree_sitter"))
        if os.isfile("LICENSE") then
            os.cp("LICENSE", out)
        end
    end)

    on_test(function (package)
        local out = package:installdir("tree-sitter")
        assert(os.isfile(path.join(out, "src", "lib.c")), "src/lib.c is not installed")
        assert(os.isfile(path.join(out, "include", "tree_sitter", "api.h")), "api.h is not installed")
    end)
