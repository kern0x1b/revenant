package("ffmpeg")
    set_kind("library")
    set_homepage("https://ffmpeg.org")
    set_description("FFmpeg 8.1.2 as Telegram configures it for armv7 iOS 6: AudioToolbox AAC, ALAC and GSM, libopus, libvpx and libdav1d with their ARM assembly, at upstream n8.1.2 commit 38b88335 plus Telegram's VERSION and mov.c delta and a UInt32 out-parameter fix as patches")
    set_license("LGPL-2.1-or-later")

    add_urls("https://github.com/FFmpeg/FFmpeg.git")
    add_versions("8.1.2", "38b88335f99e76ed89ff3c93f877fdefce736c13")
    add_patches("8.1.2", "patches/0001-version-and-mov-stsd.patch", "7efef3d9f5e1527578243ec3ec002f69aa87fcf4d54608e7e63dee18f9c044ef")
    add_patches("8.1.2", "patches/0002-audiotoolbox-uint32-out-params.patch", "cfbe482fec85966fa0b3db121df16648442f66438e4462bb9d507309f4575d0c")
    add_patches("8.1.2", "patches/0003-audiotoolbox-encoder-uint32-out-params.patch", "d7f2ce04e2872d0d3ab1c7aaecb1bdbc7295b0bd38294ef7c98e5d318dd812d7")
    if is_plat("iphoneos") then
        add_links("avformat", "avcodec", "swresample", "avutil")
        add_deps("revenant@libcxx", {alias = "libcxx"})
        add_deps("revenant@opus", {alias = "opus"})
        add_deps("revenant@vpx", {alias = "vpx"})
        add_deps("revenant@dav1d", {alias = "dav1d"})
        add_deps("pkgconf", {kind = "binary", host = true})
    else
        add_links("avcodec", "avutil")
        add_syslinks("iconv")
    end

    on_install("macosx", function (package)
        local parallel = import("@addon.revenant.parallel", {anonymous = true})
        local build = path.absolute("build-ffmpeg")
        os.mkdir(build)
        os.vrunv(path.absolute("configure"), {"--prefix=" .. package:installdir(), "--disable-programs", "--disable-doc",
            "--disable-network", "--disable-everything", "--disable-avformat", "--disable-avfilter", "--disable-avdevice",
            "--disable-swresample", "--disable-swscale", "--enable-avcodec", "--enable-avutil",
            "--enable-decoder=hevc", "--enable-parser=hevc"}, {curdir = build})
        parallel.hold(nil, function (width)
            os.vrunv("make", {"-j" .. width}, {curdir = build})
        end)
        os.vrunv("make", {"install"}, {curdir = build})
    end)

    on_install("iphoneos", function (package)
        local parallel = import("@addon.revenant.parallel", {anonymous = true})
        local cmake = import("@addon.revenant.apple.cmake", {anonymous = true})
        local chosen = cmake.toolchain(package)
        local deployment = chosen:config("deployment")
        local target = table.concat({"-target", package:arch() .. "-apple-ios" .. deployment, "-isysroot", chosen:config("sdkdir")}, " ")
        local cc = chosen:tool("cc") .. " " .. target
        local libcxx = import("@addon.revenant.apple.deps", {anonymous = true}).flags(package, "libcxx")
        local pc = path.absolute("pc")
        os.mkdir(pc)
        for _, item in ipairs({
            {name = "opus", lib = "opus", version = "1.5.1", include = "/opus"},
            {name = "vpx", lib = "vpx", version = "1.13.0", include = ""},
            {name = "dav1d", lib = "dav1d", version = "1.5.0", include = ""}}) do
            io.writefile(path.join(pc, item.name .. ".pc"), table.concat({
                "prefix=" .. package:dep(item.name):installdir(),
                "libdir=${prefix}/lib",
                "includedir=${prefix}/include",
                "",
                "Name: " .. item.name,
                "Description: " .. item.name,
                "Version: " .. item.version,
                "Cflags: -I${includedir}" .. item.include,
                "Libs: -L${libdir} -l" .. item.lib,
                ""}, "\n"))
        end
        local pkgconf_home = package:dep("pkgconf"):installdir()
        local tools = path.absolute("tools")
        os.mkdir(tools)
        local pkgconf = path.join(tools, "pkg-config")
        os.cp(path.join(pkgconf_home, "bin", "pkgconf"), pkgconf)
        local built_against = nil
        for line in os.iorunv("otool", {"-L", pkgconf}):gmatch("[^\n]+") do
            built_against = built_against or line:match("^%s*(%S*libpkgconf%S*)")
        end
        os.vrunv("install_name_tool", {"-change", built_against, path.join(pkgconf_home, "lib", "libpkgconf.7.dylib"), pkgconf})
        os.vrunv("codesign", {"--force", "--sign", "-", pkgconf})
        local envs = {PKG_CONFIG_LIBDIR = pc, SOURCE_DATE_EPOCH = "0", IPHONEOS_DEPLOYMENT_TARGET = deployment}
        local options = {"--prefix=" .. package:installdir(), "--target-os=darwin", "--arch=" .. package:arch(),
            "--cc=" .. cc, "--as=" .. cc .. " -c", "--enable-cross-compile", "--pkg-config=" .. pkgconf,
            "--disable-programs", "--disable-armv5te", "--disable-armv6", "--disable-armv6t2", "--disable-doc",
            "--enable-pic", "--disable-all", "--disable-everything", "--enable-avcodec", "--enable-swresample",
            "--enable-avformat", "--disable-xlib", "--enable-libopus", "--enable-libvpx", "--enable-libdav1d",
            "--enable-bsf=aac_adtstoasc,vp9_superframe,h264_mp4toannexb",
            "--enable-decoder=h264,libvpx_vp9,hevc,libopus,flac,pcm_s16le,pcm_s24le,pcm_f32le,libdav1d,av1,mp3",
            "--enable-demuxer=aac,mov,m4v,mp3,ogg,libopus,flac,wav,aiff,matroska,mpegts",
            "--enable-parser=aac,h264,mp3,libopus", "--enable-protocol=file",
            "--enable-muxer=mp4,matroska,ogg,mpegts",
            "--enable-audiotoolbox", "--enable-decoder=alac_at,gsm_ms_at,aac_at", "--enable-encoder=libvpx_vp9,aac_at",
            "--extra-cflags=-DCONFIG_SAFE_BITSTREAM_READER=1",
            "--extra-ldflags=" .. table.concat(table.join({target}, libcxx.ldflags), " "), "--extra-libs=-lc++"}
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
        local libraries = package:plat() == "iphoneos" and {"avcodec", "avformat", "avutil", "swresample"} or {"avcodec", "avutil"}
        for _, library in ipairs(libraries) do
            assert(os.isfile(path.join(package:installdir("lib"), "lib" .. library .. ".a")), "lib" .. library .. ".a is not installed")
        end
    end)
