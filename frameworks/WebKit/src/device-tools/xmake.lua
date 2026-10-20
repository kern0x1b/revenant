package("webkit-device-tools")
    set_homepage("https://github.com/kern0x1b/revenant/tree/main/frameworks/WebKit")
    set_description("The probes the WebKit port measures the phone with, docs/reference/webkit/tools.md: revmem, revpid, revtouch and raise-memory-limit, built for the phone and signed with the entitlements each needs")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    local digests = {}
    local inputs = table.join({path.join(os.scriptdir(), "xmake.lua")},
                              os.files(path.join(os.scriptdir(), "*.c")), os.files(path.join(os.scriptdir(), "entitlements", "*.xml")))
    table.sort(inputs)
    for _, file in ipairs(inputs) do
        table.insert(digests, path.filename(file) .. "=" .. hash.sha256(file))
    end
    add_configs("sources", {description = "The digest of this recipe and the tools' sources and entitlements, so a changed probe is a different package.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    add_deps("revenant@ldid 2.1.5-procursus7+23.gaf86971", {alias = "ldid"})

    local TOOLS = {"revmem", "revpid", "revtouch", "raise-memory-limit"}

    on_install("iphoneos", function (package)
        local toolchain = assert(package:toolchains(), "webkit-device-tools is built with the apple-ios toolchain")[1]
        toolchain:load()
        local common ={"-target", package:arch() .. "-apple-ios", "-miphoneos-version-min=" .. toolchain:config("deployment"),
                        "-isysroot", toolchain:config("sdkdir")}
        if toolchain:config("linker_version") then
            table.join2(common, {"-mlinker-version=" .. toolchain:config("linker_version")})
        end
        local compiled = table.join(common, toolchain:config("emulated_tls") and {"-femulated-tls"} or {},
                                    {"-std=gnu99", "-O3", "-DNDEBUG"})
        local linker = {}
        for _, flag in ipairs(table.wrap(toolchain:get("shflags"))) do
            if flag:startswith("-fuse-ld=") then
                table.insert(linker, flag)
            end
        end
        os.mkdir(package:installdir("bin"))
        for _, tool in ipairs(TOOLS) do
            local frameworks = tool == "revtouch" and {"-framework", "IOKit", "-framework", "CoreFoundation"} or {}
            os.vrunv(toolchain:tool("cc"), table.join(compiled, linker, {path.join(package:scriptdir(), tool .. ".c"), "-o", path.join(package:installdir("bin"), tool)}, frameworks))
        end
        os.mkdir(package:installdir("licenses"))
        os.vcp(path.join(package:scriptdir(), "..", "..", "LICENSE"), package:installdir("licenses"))
        local signing = import("@addon.revenant.apple.signing", {anonymous = true})
        local ldid = path.join(package:dep("ldid"):installdir(), "bin", "ldid")
        for _, tool in ipairs(TOOLS) do
            local entitlements = path.join(package:scriptdir(), "entitlements", tool .. ".xml")
            signing.sign(ldid, path.join(package:installdir("bin"), tool), {entitlements = os.isfile(entitlements) and entitlements or nil})
        end
    end)

    on_test(function (package)
        for _, tool in ipairs(TOOLS) do
            assert(os.isfile(path.join(package:installdir("bin"), tool)), tool .. " is not installed")
        end
    end)
