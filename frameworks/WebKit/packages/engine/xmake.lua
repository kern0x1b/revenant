package("webkit-engine")
    set_homepage("https://github.com/kern0x1b/revenant/tree/main/frameworks/WebKit")
    set_description("JavaScriptCore, WebCore and WebKitLegacy for armv7 and iOS 6, built from the webkit package's patched tree with CMake against the port's libraries: system stages the frameworks under usr/lib/rev-fw in place of the phone's own, prefixed lays them out for an application's Frameworks folder with every class renamed")
    set_license("LGPL-2.1-or-later AND BSD-2-Clause")
    set_policy("package.strict_compatibility", true)

    local member = path.join(os.scriptdir(), "..", "..")
    local digests = {}
    local inputs = table.join({path.join(os.scriptdir(), "xmake.lua"), path.join(member, "carry-symbols.txt")},
                              os.files(path.join(member, "modules", "*.lua")), os.files(path.join(member, "compat", "**")))
    table.sort(inputs)
    for _, file in ipairs(inputs) do
        table.insert(digests, path.relative(file, member) .. "=" .. hash.sha256(file))
    end
    add_configs("sources", {description = "The digest of this recipe, the engine module, the compat library and the symbol baseline, so a changed flag or stub is a different engine.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})
    add_configs("variant", {description = "system replaces the phone's frameworks beneath Mobile Safari; prefixed renames every class for an application that carries its own engine.", default = "system", type = "string", values = {"system", "prefixed"}})

    add_deps("cmake", "ninja", {kind = "binary"})
    add_deps("webkit", "icu", "brotli", "libpsl", "libwebp", "libxml2", "libxslt", "woff2")
    add_deps("revenant@openssl", {alias = "openssl"})
    add_deps("revenant@libcxx", {alias = "libcxx"})
    add_deps("revenant@ldid 2.1.5-procursus7+23.gaf86971", {alias = "ldid"})

    on_install("iphoneos", function (package)
        import("engine", {rootdir = path.join(package:scriptdir(), "..", "..", "modules"), anonymous = true}).install(package)
    end)

    on_test(function (package)
        if package:config("variant") == "prefixed" then
            for _, framework in ipairs({"JavaScriptCore", "WebCore", "WebKitLegacy"}) do
                assert(os.isfile(path.join(package:installdir("bundle"), "Frameworks", framework .. ".framework", framework)), framework .. " is not in the bundle")
                assert(os.isdir(path.join(package:installdir("frameworks"), framework .. ".framework")), framework .. " is not linkable")
            end
        else
            for _, framework in ipairs({"JavaScriptCore", "WebCore", "WebKit"}) do
                assert(os.isfile(path.join(package:installdir("stage"), "usr", "lib", "rev-fw", framework .. ".framework", framework)), framework .. " is not staged")
            end
            assert(os.isfile(path.join(package:installdir("stage"), "usr", "lib", "librev-c++.1.dylib")), "the C++ runtime is not staged")
        end
    end)
