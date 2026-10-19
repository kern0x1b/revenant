package("openssl")
    set_homepage("https://www.openssl.org")
    set_description("OpenSSL, the newest release, through its own Configure targets with the ARM assembly kept; armv7 carries a perlasm fix for OPENSSL_armcap_P on Mach-O")
    set_license("Apache-2.0")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/openssl/openssl.git")
    add_versions("4.0.2", "f089acdf4bc7ba94a79f4bf6eb7362c3e7d14aa9")
    add_patches("4.0.2", "patches/arm-xlate-ios32-hidden-extern-data.patch")
    add_links("ssl", "crypto")

    local targets = {
        iphoneos = {armv7 = "ios-xcrun", arm64 = "ios64-xcrun"},
        macosx = {arm64 = "darwin64-arm64-cc", x86_64 = "darwin64-x86_64-cc"}
    }

    on_install("iphoneos", "macosx", function (package)
        local target = (targets[package:plat()] or {})[package:arch()]
        if not target then
            raise("OpenSSL has no %s Configure target for %s", package:plat(), package:arch())
        end
        local options = {target, "CC=cc", "no-shared", "no-dso", "no-tests", "no-docs", "no-apps", "no-ui-console",
                         "no-engine", "no-async"}
        local envs = {SOURCE_DATE_EPOCH = os.iorunv("git", {"log", "-1", "--format=%ct"}):trim()}
        if package:is_plat("iphoneos") then
            local toolchain = assert(package:toolchains(), "an iPhoneOS OpenSSL is built with the platform's toolchain")[1]
            toolchain:load()
            envs.SDKROOT = assert(toolchain:config("sdkdir"), "the toolchain names no SDK")
            table.insert(options, "-mios-version-min=" .. assert(toolchain:config("deployment"), "the toolchain names no minimum release"))
            if package:is_arch("armv7") then
                table.insert(options, "-DBROKEN_CLANG_ATOMICS")
            end
        end
        os.vrunv("./Configure", options, {envs = envs})
        os.vrunv("make", {"-j" .. os.cpuinfo("ncpu"), "build_libs"}, {envs = envs})
        os.cp("libcrypto.a", package:installdir("lib"))
        os.cp("libssl.a", package:installdir("lib"))
        os.cp("include/openssl", package:installdir("include"))
        os.cp("LICENSE.txt", package:installdir("licenses"))
    end)

    on_test(function (package)
        assert(package:has_cfuncs("OPENSSL_version_major", {includes = "openssl/crypto.h"}))
    end)
