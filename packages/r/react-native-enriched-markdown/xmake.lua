package("react-native-enriched-markdown")
    set_kind("library", {headeronly = true})
    set_homepage("https://www.npmjs.com/package/react-native-enriched-markdown")
    set_description("react-native-enriched-markdown 1.2.0-nightly-20261014-766fc0e67, the markdown view of the chat, from its npm tarball: the published build with its own C++ parser and code highlighting, without the EnrichedMarkdownCore pod; patches for armv7 iOS 6 (BOOL to bool in brace initializers, a type cast)")
    set_license("MIT")

    add_urls("https://registry.npmjs.org/react-native-enriched-markdown/-/react-native-enriched-markdown-$(version).tgz")
    add_versions("1.2.0-nightly-20261014-766fc0e67", "ef090a8941dce4a9848ae343391a9c5315fb0a8cca1be8d764fe51253a00607b")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "2", readonly = true})

    local GRAMMAR_PACKAGES = {
        {"tree-sitter-json", "0.24.8", {"json"}},
        {"tree-sitter-html", "0.23.2", {"html"}},
        {"tree-sitter-css", "0.23.2", {"css"}},
        {"tree-sitter-grammars-tree-sitter-markdown", "0.3.2", {"markdown"}},
        {"tree-sitter-grammars-tree-sitter-yaml", "0.7.1", {"yaml"}},
        {"tree-sitter-go", "0.23.4", {"go"}},
        {"tree-sitter-java", "0.23.5", {"java"}},
        {"tree-sitter-javascript", "0.23.1", {"javascript"}},
        {"tree-sitter-python", "0.23.6", {"python"}},
        {"tree-sitter-c", "0.23.5", {"c"}},
        {"tree-sitter-rust", "0.23.2", {"rust"}},
        {"tree-sitter-bash", "0.23.3", {"bash"}},
        {"tree-sitter-typescript", "0.23.2", {"typescript", "tsx"}},
    }
    add_deps("revenant@tree-sitter-runtime 0.26.3", {alias = "tree-sitter-runtime"})
    for _, dep in ipairs(GRAMMAR_PACKAGES) do
        add_deps("revenant@" .. dep[1] .. " " .. dep[2], {alias = dep[1]})
    end

    local patches = {
        "0001-Cast-the-custom-edit-menu-actions-to-UIMenuElement.patch",
        "0002-Convert-the-BOOL-fields-to-bool-in-the-input-event-emitter.patch",
        "0003-Convert-the-BOOL-checked-state-to-bool-in-the-task-list-events.patch",
        "0004-Guard-the-Dynamic-Type-observer-to-iOS-7-and-later.patch",
        "0006-Keep-the-live-text-container-width-while-measuring.patch",
    }
    local digests = {"xmake.lua=" .. hash.sha256(path.join(os.scriptdir(), "xmake.lua"))}
    for _, name in ipairs(patches) do
        local file = path.join(os.scriptdir(), "patches", name)
        local digest = hash.sha256(file)
        add_patches("1.2.0-nightly-20261014-766fc0e67", file, digest)
        table.insert(digests, name .. "=" .. digest)
    end
    add_configs("recipe", {description = "The digest of this recipe and the patches it applies, so a changed patch is a different build.",
                           default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

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
        os.cp("*", package:installdir() .. "/")
        local vendor = path.join(package:installdir(), "cpp", "highlight", "vendor")
        copy_tree(package:dep("tree-sitter-runtime"):installdir("tree-sitter"), path.join(vendor, "tree-sitter"))
        for _, dep in ipairs(GRAMMAR_PACKAGES) do
            for _, id in ipairs(dep[3]) do
                copy_tree(package:dep(dep[1]):installdir("grammars", id), path.join(vendor, "grammars", id))
            end
        end
    end)

    on_test(function (package)
        local json = import("core.base.json")
        local manifest = json.decode(io.readfile(path.join(package:installdir(), "package.json")))
        assert(manifest.name == "react-native-enriched-markdown" and manifest.version == "1.2.0-nightly-20261014-766fc0e67", "the package is " .. manifest.name .. " " .. manifest.version)
        local vendor = path.join(package:installdir(), "cpp", "highlight", "vendor")
        assert(os.isfile(path.join(package:installdir(), "cpp", "highlight", "CodeBlockHighlighter.cpp")), "the code highlighter sources are not installed")
        assert(os.isfile(path.join(vendor, "tree-sitter", "src", "lib.c")), "the tree-sitter runtime is not vendored")
        for _, dep in ipairs(GRAMMAR_PACKAGES) do
            for _, id in ipairs(dep[3]) do
                assert(os.isfile(path.join(vendor, "grammars", id, "parser.c")), "the grammar " .. id .. " is not vendored")
            end
        end
    end)
