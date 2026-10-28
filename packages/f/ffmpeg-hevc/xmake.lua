package("ffmpeg-hevc")
    set_kind("library")
    set_homepage("https://ffmpeg.org")
    set_description("FFmpeg 8.1.2 for the iOS 6 Backports: libavcodec and libavutil as static archives for armv7 with NEON, with the hevc decoder and parser only, at upstream n8.1.2 commit 38b88335")
    set_license("LGPL-2.1-or-later")

    add_urls("https://github.com/FFmpeg/FFmpeg.git")
    add_versions("8.1.2", "38b88335f99e76ed89ff3c93f877fdefce736c13")

    if is_plat("iphoneos") then
        add_links("avcodec", "avutil")
    end

    on_install("iphoneos", function (package)
        local parallel = import("@addon.revenant.parallel", {anonymous = true})
        local cmake = import("@addon.revenant.apple.cmake", {anonymous = true})
        local chosen = cmake.toolchain(package)
        local deployment = chosen:config("deployment")
        local target = table.concat({"-target", package:arch() .. "-apple-ios" .. deployment, "-isysroot", chosen:config("sdkdir")}, " ")
        local linker_version = chosen:config("linker_version") and {"-mlinker-version=" .. chosen:config("linker_version")} or {}
        local linker = {}
        for _, flag in ipairs(table.wrap(chosen:get("shflags"))) do
            if flag:startswith("-fuse-ld=") then
                table.insert(linker, flag)
            end
        end
        local cc = chosen:tool("cc") .. " " .. target .. " " .. table.concat(linker_version, " ")
        local envs = {SOURCE_DATE_EPOCH = "0", IPHONEOS_DEPLOYMENT_TARGET = deployment}
        local options = {"--prefix=" .. package:installdir(), "--target-os=darwin", "--arch=" .. package:arch(),
            "--cc=" .. cc, "--as=" .. cc .. " -c", "--enable-cross-compile",
            "--disable-programs", "--disable-doc", "--disable-everything", "--disable-iconv", "--enable-static", "--disable-shared",
            "--disable-armv5te", "--disable-armv6", "--disable-armv6t2", "--enable-neon", "--enable-pic",
            "--disable-avdevice", "--disable-avfilter", "--disable-avformat", "--disable-swresample", "--disable-swscale",
            "--enable-avcodec", "--enable-avutil", "--enable-decoder=hevc", "--enable-parser=hevc",
            "--extra-cflags=-fvisibility=hidden", "--extra-ldflags=" .. target .. " " .. table.concat(linker, " ")}
        local build = path.absolute("build-ffmpeg")
        os.mkdir(build)
        os.vrunv(path.absolute("configure"), options, {curdir = build, envs = envs})
        parallel.hold(nil, function (width)
            os.vrunv("make", {"-j" .. width}, {curdir = build, envs = envs})
        end)
        os.vrunv("make", {"install"}, {curdir = build, envs = envs})
        import("@addon.revenant.apple.install", {anonymous = true}).finish(package, {
            licenses = "LICENSE.md", prune = {"lib/pkgconfig", "share", "bin"}})
    end)

    on_test(function (package)
        for _, library in ipairs({"avcodec", "avutil"}) do
            assert(os.isfile(path.join(package:installdir("lib"), "lib" .. library .. ".a")), "lib" .. library .. ".a is not installed")
        end
    end)
