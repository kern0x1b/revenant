package("ffmpeg-hevc")
    set_kind("library")
    set_homepage("https://ffmpeg.org")
    set_description("FFmpeg 8.1.2 for the iOS 6 Backports: libavcodec and libavutil as shared libraries for armv7 with NEON, with the hevc decoder and parser only, at upstream n8.1.2 commit 38b88335")
    set_license("LGPL-2.1-or-later")

    add_urls("https://github.com/FFmpeg/FFmpeg.git")
    add_versions("8.1.2", "38b88335f99e76ed89ff3c93f877fdefce736c13")

    add_configs("shared", {description = "The libraries are the shared pair a Backports library links dynamically, installed in a package of their own, so the library is replaceable as LGPL-2.1 requires.", default = true, type = "boolean", readonly = true})

    if is_plat("iphoneos") then
        add_links("avcodec", "avutil")
    end

    on_install("iphoneos", function (package)
        local parallel = import("@addon.revenant.parallel", {anonymous = true})
        local cmake = import("@addon.revenant.apple.cmake", {anonymous = true})
        local shared = import("@addon.revenant.apple.shared_runtime", {anonymous = true})
        local macho = import("@addon.revenant.apple.macho", {anonymous = true})
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
        local name = shared.package_name("ffmpeg-hevc", package:buildhash())
        local envs = {SOURCE_DATE_EPOCH = "0", IPHONEOS_DEPLOYMENT_TARGET = deployment}
        local options = {"--prefix=" .. package:installdir(), "--target-os=darwin", "--arch=" .. package:arch(),
            "--cc=" .. cc, "--as=" .. cc .. " -c", "--enable-cross-compile",
            "--disable-programs", "--disable-doc", "--disable-everything", "--disable-static", "--enable-shared",
            "--disable-armv5te", "--disable-armv6", "--disable-armv6t2", "--enable-neon", "--enable-pic",
            "--disable-avdevice", "--disable-avfilter", "--disable-avformat", "--disable-swresample", "--disable-swscale",
            "--enable-avcodec", "--enable-avutil", "--enable-decoder=hevc", "--enable-parser=hevc",
            "--install-name-dir=" .. shared.folder_of(name), "--extra-ldflags=" .. target .. " " .. table.concat(linker, " ")}
        local build = path.absolute("build-ffmpeg")
        os.mkdir(build)
        os.vrunv(path.absolute("configure"), options, {curdir = build, envs = envs})
        parallel.hold(nil, function (width)
            os.vrunv("make", {"-j" .. width}, {curdir = build, envs = envs})
        end)
        os.vrunv("make", {"install"}, {curdir = build, envs = envs})
        import("@addon.revenant.apple.install", {anonymous = true}).finish(package, {
            licenses = "LICENSE.md", prune = {"lib/pkgconfig", "share", "bin"}})
        local held = {}
        for _, file in ipairs(os.files(path.join(package:installdir("lib"), "*.dylib"))) do
            if not os.islink(file) then
                table.insert(held, {source = file, leaf = path.filename(macho.images(macho.read(file))[1].identity)})
            end
        end
        shared.stage({packages = {{name = name, version = shared.package_version(package:buildhash()),
                                   title = "FFmpeg HEVC decoder " .. package:buildhash():sub(1, 8),
                                   description = "libavcodec and libavutil of FFmpeg 8.1.2 (upstream n8.1.2 commit 38b88335) with the hevc decoder and parser",
                                   note = "named after the build that holds it, so another build is another folder; the library is LGPL-2.1-or-later and replaceable, and its licence is in /usr/share/doc/" .. name .. "/",
                                   licenses = {package:installdir("licenses", "LICENSE.md")},
                                   libraries = {}, extra = held}},
                      root = path.join(package:installdir("share"), "root"),
                      metadata = path.join(package:installdir("share"), "shared-packages"), strip = {"-x"}})
        package:setenv("REVENANT_SHARED_PACKAGE", name)
    end)

    on_test(function (package)
        local shared = import("@addon.revenant.apple.shared_runtime", {anonymous = true})
        local name = shared.package_name("ffmpeg-hevc", package:buildhash())
        for _, library in ipairs({"avcodec", "avutil"}) do
            assert(os.isfile(path.join(package:installdir("lib"), "lib" .. library .. ".dylib")), "lib" .. library .. ".dylib is not installed")
        end
        assert(os.isfile(path.join(package:installdir("share"), "shared-packages", name .. ".json")), "the package left no description of its package")
        local identity = os.iorunv("xcrun", {"otool", "-D", path.join(package:installdir("lib"), "libavcodec.dylib")})
        assert(identity:find(shared.folder_of(name) .. "/libavcodec.", 1, true), "libavcodec is not identified by the package's folder: " .. identity)
    end)
