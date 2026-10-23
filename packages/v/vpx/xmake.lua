package("vpx")
    set_kind("library")
    set_homepage("https://www.webmproject.org")
    set_description("libvpx, the VP8 and VP9 codec as a static libvpx for armv7 iOS 6, at master commit e7bfd8b6 (1.13.0 plus 435 commits) that Telegram vendors")
    set_license("BSD-3-Clause")

    add_urls("https://github.com/webmproject/libvpx.git")
    add_versions("1.13.0-435", "e7bfd8b6c230a6824e7fd1efa2378a7322986128")
    add_links("vpx")
    add_deps("revenant@libcxx", {alias = "libcxx"})

    on_install("iphoneos", function (package)
        local parallel = import("@addon.revenant.parallel", {anonymous = true})
        local cmake = import("@addon.revenant.apple.cmake", {anonymous = true})
        local chosen = cmake.toolchain(package)
        local target = {"-target", package:arch() .. "-apple-ios" .. chosen:config("deployment"), "-isysroot", chosen:config("sdkdir")}
        local compiled = table.join(target, {"-O2", "-Wno-overriding-option"})
        local libcxx = import("@addon.revenant.apple.deps", {anonymous = true}).flags(package, "libcxx")
        local envs = {
            SOURCE_DATE_EPOCH = "0",
            CC = chosen:tool("cc"),
            CFLAGS = table.concat(compiled, " "),
            CXX = chosen:tool("cxx"),
            CXXFLAGS = table.concat(table.join(compiled, libcxx.cflags, libcxx.cxxflags), " "),
            LDFLAGS = table.concat(target, " "),
            IPHONEOS_DEPLOYMENT_TARGET = chosen:config("deployment")
        }
        local build = path.absolute("build-vpx")
        os.mkdir(build)
        local options = {"--target=armv7-darwin-gcc", "--prefix=" .. package:installdir(), "--disable-docs", "--disable-examples",
                         "--disable-postproc", "--disable-webm-io", "--disable-vp9-highbitdepth", "--disable-vp9-postproc",
                         "--disable-vp9-temporal-denoising", "--disable-unit-tests", "--enable-realtime-only",
                         "--enable-multi-res-encoding", "--size-limit=8192x8192"}
        os.vrunv(path.absolute("configure"), options, {curdir = build, envs = envs})
        local overrides = {"CC=" .. chosen:tool("cc"), "CXX=" .. chosen:tool("cxx"), "AS=" .. chosen:tool("cc"),
            "ASFLAGS=" .. table.concat(table.join({"-c"}, target, {"-I./", "-I" .. path.absolute(".") .. "/"}), " ")}
        parallel.hold(nil, function (width)
            os.vrunv("make", table.join({"-j" .. width}, overrides), {curdir = build})
        end)
        os.vrunv("make", table.join({"install"}, overrides), {curdir = build})
        for _, header in ipairs({"vpx_config.h", "vpx_version.h"}) do
            os.cp(path.join(build, header), package:installdir("include", "vpx"))
        end
        import("@addon.revenant.apple.install", {anonymous = true}).finish(package, {
            licenses = "LICENSE", prune = {"lib/pkgconfig", "share", "bin"}})
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libvpx.a")), "libvpx.a is not installed")
        for _, header in ipairs({"vpx_codec.h", "vp8cx.h", "vpx_decoder.h", "vpx_config.h", "vpx_version.h"}) do
            assert(os.isfile(path.join(package:installdir("include", "vpx"), header)), header .. " is not installed")
        end
    end)
