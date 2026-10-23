toolchain("apple-ios")
    set_kind("standalone")
    set_homepage("https://github.com/kern0x1b/revenant/tree/main/toolchain")
    set_description("iPhoneOS through the llvm package's clang, an SDK package and, for armv7, cctools-port ld64")

    set_toolset("cc", "clang")
    set_toolset("cxx", "clang", "clang++")
    set_toolset("mm", "clang")
    set_toolset("mxx", "clang", "clang++")
    set_toolset("as", "clang")
    set_toolset("ld", "clang", "clang++")
    set_toolset("sh", "clang", "clang++")
    set_toolset("ar", "ar")
    set_toolset("scld", "clang", "clang++")
    set_toolset("scsh", "clang", "clang++")
    set_toolset("scar", "ar")
    set_toolset("strip", "strip")

    local function parts(toolchain, project, apple_sdk)
        local required = project.required_packages() or {}
        local found = {}
        local sdk = required["iphoneos-sdk"]
        if sdk and toolchain:config("sdk") then
            found.sdk = apple_sdk.folder(sdk:installdir(), toolchain:config("sdk"))
        end
        local ld64 = required["ld64"]
        if ld64 and toolchain:config("ld64") then
            found.linker = path.join(ld64:installdir(), "bin", "ld")
        end
        local llvm = required["llvm"]
        if llvm and toolchain:config("llvm") then
            found.clang = path.join(llvm:installdir(), "bin", "clang")
        end
        return found
    end

    on_check(function (toolchain)
        local found = parts(toolchain, import("core.project.project"), import("@self.apple.sdk"))
        if not toolchain:config("minimum") or not found.clang then
            return false
        end
        return not toolchain:is_arch("armv6", "armv7", "armv7s") or found.linker ~= nil
    end)

    on_load(function (toolchain)
        import("core.base.semver")
        local found = parts(toolchain, import("core.project.project"), import("@self.apple.sdk"))
        local declared = toolchain:config("minimum")
        if not declared or not found.clang then
            raise("toolchain(apple-ios) needs the SDK and llvm packages and apple_minimum; includes(\"@addon/revenant/apple-ios\") provides them")
        end
        if not found.sdk then
            raise("the iphoneos-sdk %s package has no install folder in this configuration: --require=n registers packages without locating them, so configure without it", toolchain:config("sdk"))
        end
        if not os.isfile(path.join(found.sdk, "SDKSettings.json")) then
            raise("the iphoneos-sdk %s package is incomplete: %s has no SDKSettings.json, so configure again and xmake installs it", toolchain:config("sdk"), found.sdk)
        end
        local minimum = import("@self.apple.architectures").deployment(toolchain:arch(), declared)
        local clangxx = found.clang .. "++"
        toolchain:set("toolset", "cc", found.clang)
        toolchain:set("toolset", "cxx", found.clang, clangxx)
        toolchain:set("toolset", "mm", found.clang)
        toolchain:set("toolset", "mxx", found.clang, clangxx)
        toolchain:set("toolset", "as", found.clang)
        toolchain:set("toolset", "ld", found.clang, clangxx)
        toolchain:set("toolset", "sh", found.clang, clangxx)
        toolchain:set("toolset", "scld", found.clang, clangxx)
        toolchain:set("toolset", "scsh", found.clang, clangxx)
        toolchain:config_set("sdkdir", found.sdk)
        toolchain:config_set("deployment", minimum)
        toolchain:add("runenvs", "IPHONEOS_DEPLOYMENT_TARGET", minimum)
        local target = table.join({"-target", toolchain:arch() .. "-apple-ios", "-miphoneos-version-min=" .. minimum, "-isysroot", found.sdk},
                                  found.linker and {"-mlinker-version=" .. toolchain:config("ld64")} or {})
        local native_tls = toolchain:is_arch("arm64") and "8.0" or "9.0"
        local emulated_tls = semver.compare(minimum, native_tls) < 0
        local thread_local = emulated_tls and {"-femulated-tls"} or {}
        toolchain:config_set("emulated_tls", emulated_tls)
        toolchain:config_set("atomic_libcalls", semver.compare(minimum, "7.0") < 0)
        toolchain:config_set("linker_version", found.linker and toolchain:config("ld64") or nil)
        local linked = table.join(target, found.linker and {"-fuse-ld=" .. found.linker} or {})
        if semver.compare(minimum, "3.2") < 0 then
            table.join2(linked, {"-lBlocksRuntime", "-lobjc"})
        end
        local neon = toolchain:is_arch("armv7") and {"-isystem", path.join(os.scriptdir(), "..", "..", "..", "neon", "include")} or {}
        local compiled = table.join(target, thread_local, neon, toolchain:config("optimize") == "packages" and {"-O2"} or {})
        toolchain:add("cxflags", compiled)
        local objc = semver.compare(minimum, "5.0") < 0 and {"-Xclang", "-fobjc-runtime-has-weak"} or {}
        toolchain:add("mxflags", table.join(compiled, objc))
        toolchain:add("asflags", target)
        toolchain:add("ldflags", linked)
        toolchain:add("shflags", linked)
        toolchain:add("scldflags", linked)
        toolchain:add("scshflags", linked)
    end)
