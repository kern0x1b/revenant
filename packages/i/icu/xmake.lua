package("icu")
    set_homepage("https://icu.unicode.org")
    set_description("ICU as static libraries for armv7 and iOS 6, and for the Mac that tests its data: the prebuilt data archive of the release, cut down with ICU's own icupkg, genrb and derb to the languages its install script lists and without the RBNF and transliteration trees")
    set_license("Unicode-3.0")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/unicode-org/icu/releases/download/release-$(version)/icu4c-$(version)-sources.tgz")
    add_versions("78.3", "3a2e7a47604ba702f345878308e6fefeca612ee895cf4a5f222e7955fabfe0c0")
    add_links("icui18n", "icuuc", "icudata")
    add_defines("U_STATIC_IMPLEMENTATION", "U_DISABLE_RENAMING=1")
    add_configs("recipe", {description = "The digest of this recipe, so a changed build flag is a different ICU.", default = hash.strhash128(hash.sha256(path.join(os.scriptdir(), "xmake.lua"))), type = "string", readonly = true})

    on_load(function (package)
        if package:is_plat("iphoneos") then
            package:add("deps", "revenant@libcxx", {alias = "libcxx"})
        end
    end)

    on_install("iphoneos", "macosx", function (package)
        local parallel = import("@addon.revenant.parallel", {anonymous = true})
        local icu_data = import("@addon.revenant.icu_data", {anonymous = true})
        local function make(dir, targets)
            parallel.hold(nil, function (width)
                os.vrunv("make", table.join({"-j" .. width}, targets or {}), {curdir = dir})
            end)
        end


        local configure = path.absolute(path.join("source", "configure"))
        local archive = path.absolute(path.join("source", "data", "in", "icudt" .. package:version():major() .. "l.dat"))
        local options = {"--enable-static", "--disable-shared", "--disable-tests", "--disable-samples", "--disable-extras", "ac_cv_prog_PYTHON="}
        local base = {SOURCE_DATE_EPOCH = "0"}
        local host = path.absolute("build-host")
        os.mkdir(host)
        local hostenvs = table.join(base, {CC = "cc", CXX = "c++"})
        if package:is_plat("macosx") then
            local flags = "-arch " .. package:arch()
            hostenvs = table.join(hostenvs, {CFLAGS = flags, CXXFLAGS = flags, LDFLAGS = flags})
        end
        os.vrunv("sh", table.join({configure}, options, package:is_plat("macosx") and {"--disable-renaming", "--prefix=" .. package:installdir()} or {}),
                 {curdir = host, envs = hostenvs})
        make(host)
        icu_data.trim(path.join(host, "bin"), archive)
        if package:is_plat("macosx") then
            make(path.join(host, "data"), {"clean"})
            make(host)
            make(host, {"install"})
        else
            local cmake = import("@addon.revenant.apple.cmake", {anonymous = true})
            local chosen = cmake.toolchain(package)
            local target = {"-target", package:arch() .. "-apple-ios" .. chosen:config("deployment"), "-isysroot", chosen:config("sdkdir")}
            if chosen:config("linker_version") then
                table.insert(target, "-mlinker-version=" .. chosen:config("linker_version"))
            end
            local compiled = table.join(target, {"-O2"}, chosen:config("emulated_tls") and {"-femulated-tls"} or {})
            local linked = table.copy(target)
            for _, flag in ipairs(table.wrap(chosen:get("shflags"))) do
                if flag:startswith("-fuse-ld=") then
                    table.insert(linked, flag)
                end
            end
            local libcxx = import("@addon.revenant.apple.deps", {anonymous = true}).flags(package, "libcxx")
            local hosts = {armv7 = "arm-apple-darwin", armv7s = "arm-apple-darwin", arm64 = "aarch64-apple-darwin"}
            local cross = path.absolute("build-cross")
            os.mkdir(cross)
            local envs = table.join(base, {
                CC = chosen:tool("cc"),
                CXX = chosen:tool("cxx"),
                CFLAGS = table.concat(compiled, " "),
                CXXFLAGS = table.concat(table.join(compiled, libcxx.cflags, libcxx.cxxflags), " "),
                LDFLAGS = table.concat(linked, " "),
                IPHONEOS_DEPLOYMENT_TARGET = chosen:config("deployment")
            })
            os.vrunv("sh", table.join({configure, "--host=" .. assert(hosts[package:arch()], "ICU builds armv7, armv7s and arm64 for iPhoneOS"),
                                       "--with-cross-build=" .. host, "--disable-tools", "--disable-renaming",
                                       "--prefix=" .. package:installdir()}, options),
                     {curdir = cross, envs = envs})
            make(cross)
            make(cross, {"install"})
        end
        import("@addon.revenant.apple.install", {anonymous = true}).finish(package, {
            licenses = "LICENSE", prune = {"lib/icu", "share", "bin", "sbin"}})
    end)

    on_test(function (package)
        for _, library in ipairs({"icudata", "icuuc", "icui18n"}) do
            assert(os.isfile(path.join(package:installdir("lib"), "lib" .. library .. ".a")), library .. " is not installed")
        end
        assert(os.isfile(path.join(package:installdir("include"), "unicode", "utypes.h")))
    end)
