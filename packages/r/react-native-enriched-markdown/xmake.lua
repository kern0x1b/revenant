package("react-native-enriched-markdown")
    set_kind("library", {headeronly = true})
    set_homepage("https://www.npmjs.com/package/react-native-enriched-markdown")
    set_description("react-native-enriched-markdown 1.2.0-nightly-20261014-766fc0e67, the markdown view of the chat, from its npm tarball: the published build with its own C++ parser and code highlighting, without the EnrichedMarkdownCore pod; patches for armv7 iOS 6 (BOOL to bool in brace initializers, block signatures, a type cast)")
    set_license("MIT")

    add_urls("https://registry.npmjs.org/react-native-enriched-markdown/-/react-native-enriched-markdown-$(version).tgz")
    add_versions("1.2.0-nightly-20261014-766fc0e67", "ef090a8941dce4a9848ae343391a9c5315fb0a8cca1be8d764fe51253a00607b")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "1", readonly = true})

    local patches = {
        "0001-Cast-the-custom-edit-menu-actions-to-UIMenuElement.patch",
        "0002-Convert-the-BOOL-fields-to-bool-in-the-input-event-emitter.patch",
        "0003-Convert-the-BOOL-checked-state-to-bool-in-the-task-list-events.patch",
        "0004-Give-the-link-press-blocks-the-two-parameters-of-their-type.patch",
        "0005-Give-the-tap-handler-block-in-EnrichedMarkdownText-the-type-s-two-parameters.patch",
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
        os.cp("*", package:installdir() .. "/")
    end)

    on_test(function (package)
        local json = import("core.base.json")
        local manifest = json.decode(io.readfile(path.join(package:installdir(), "package.json")))
        assert(manifest.name == "react-native-enriched-markdown" and manifest.version == "1.2.0-nightly-20261014-766fc0e67", "the package is " .. manifest.name .. " " .. manifest.version)
        assert(os.isfile(path.join(package:installdir(), "cpp", "highlight", "CodeBlockHighlighter.cpp")), "the code highlighter sources are not installed")
    end)
