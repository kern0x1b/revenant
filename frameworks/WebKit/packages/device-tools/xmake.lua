package("webkit-device-tools")
    set_homepage("https://github.com/kern0x1b/revenant/tree/main/frameworks/WebKit")
    set_description("The probes the WebKit port measures the phone with, docs/tools.md: revmem, revpid, revtouch and raise-memory-limit, built for the phone and signed with the entitlements each needs")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    local tools = path.join(os.scriptdir(), "..", "..", "tools")
    local digests = {}
    local inputs = table.join({path.join(os.scriptdir(), "xmake.lua"), path.join(tools, "CMakeLists.txt")},
                              os.files(path.join(tools, "*.c")), os.files(path.join(tools, "entitlements", "*.xml")))
    table.sort(inputs)
    for _, file in ipairs(inputs) do
        table.insert(digests, path.filename(file) .. "=" .. hash.sha256(file))
    end
    add_configs("sources", {description = "The digest of this recipe and the tools' sources and entitlements, so a changed probe is a different package.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    add_deps("cmake", "ninja", {kind = "binary"})
    add_deps("revenant@ldid 2.1.5-procursus7+23.gaf86971", {alias = "ldid"})

    on_install("iphoneos", function (package)
        local modules = path.join(package:scriptdir(), "..", "..", "..", "..", "toolchain", "modules")
        local member = path.join(package:scriptdir(), "..", "..")
        import("apple.cmake", {rootdir = modules, anonymous = true}).install(package, {},
            {sourcedir = path.join(member, "tools"), licenses = path.join(member, "LICENSE")})
        local signing = import("apple.signing", {rootdir = modules, anonymous = true})
        local ldid = path.join(package:dep("ldid"):installdir(), "bin", "ldid")
        for _, tool in ipairs({"revmem", "revpid", "revtouch", "raise-memory-limit"}) do
            local entitlements = path.join(member, "tools", "entitlements", tool .. ".xml")
            signing.sign(ldid, path.join(package:installdir("bin"), tool), {entitlements = os.isfile(entitlements) and entitlements or nil})
        end
    end)

    on_test(function (package)
        for _, tool in ipairs({"revmem", "revpid", "revtouch", "raise-memory-limit"}) do
            assert(os.isfile(path.join(package:installdir("bin"), tool)), tool .. " is not installed")
        end
    end)
