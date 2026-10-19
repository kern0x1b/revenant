package("shade")
    set_kind("binary")
    set_homepage("https://github.com/kern0x1b/shade")
    set_description("Shade, Charon's emulator for an iPhone OS or iOS firmware's own userland: it boots the firmware over an emulated XNU on macOS arm64 hosts, for the devices and releases Charon emulates. Provenance and required attribution in Shade's NOTICE.")
    set_license("MPL-2.0")

    add_urls("https://github.com/kern0x1b/shade.git")
    local revision = "5e9716f1e8fe800cb24c1bc54d2534d490d508ba"
    add_versions("2026.10.15+1", revision)
    add_configs("revision", {description = "The Shade commit this package builds, so another commit is another emulator.", default = revision, type = "string", readonly = true})
    add_configs("sdl", {description = "Build the SDL2 window backend, for watching a guest on the desktop.", default = false, type = "boolean"})
    add_configs("ffmpeg", {description = "Build the FFmpeg audio decoder, for a guest that plays compressed audio.", default = false, type = "boolean"})

    add_deps("cmake", "ninja", "pkgconf", {kind = "binary"})
    add_deps("charon@openssl 4.0.2", "charon@libplist 2.7.0", "charon@swiftshader")
    add_deps("vulkan-headers 1.4.335+0", "vulkan-loader 1.4.335+0", "libpng", "libjpeg-turbo", {system = false})
    add_deps("shaderc", {kind = "binary", system = false})

    on_load("macosx|arm64", function (package)
        if package:config("sdl") then
            package:add("deps", "libsdl2", {system = false})
        end
        if package:config("ffmpeg") then
            package:add("deps", "ffmpeg", {system = false})
        end
    end)

    on_install("macosx|arm64", function (package)
        local head = os.iorunv("git", {"rev-parse", "HEAD"}):trim()
        if head ~= package:config("revision") then
            raise("the Shade source xmake holds for %s is commit %s, not the pinned %s; the pin needs a version name of its own",
                  package:version_str(), head, package:config("revision"))
        end
        local plist = package:dep("libplist")
        local pkgconfig = path.absolute("pkgconfig")
        os.mkdir(pkgconfig)
        io.writefile(path.join(pkgconfig, "libplist-2.0.pc"), table.concat({
            "prefix=" .. plist:installdir(),
            "Name: libplist-2.0",
            "Description: libplist as Charon builds it",
            "Version: " .. plist:version_str(),
            "Cflags: -I${prefix}/include -DLIBPLIST_STATIC",
            "Libs: -L${prefix}/lib -lplist-2.0",
            ""}, "\n"))
        local prefixes = {}
        for _, name in ipairs({"libpng", "libjpeg-turbo", "vulkan-headers", "vulkan-loader"}) do
            table.insert(prefixes, package:dep(name):installdir())
        end
        local glslc = path.join(package:dep("shaderc"):installdir(), "bin", "glslc")
        local configs = {"-DCMAKE_BUILD_TYPE=Release", "-DBUILD_TESTING=OFF", "-DSHADE_ENABLE_VULKAN=ON",
                         "-DSHADE_ENABLE_SDL2=" .. (package:config("sdl") and "ON" or "OFF"),
                         "-DCMAKE_PREFIX_PATH=" .. table.concat(prefixes, ";"),
                         "-DOPENSSL_ROOT_DIR=" .. package:dep("openssl"):installdir(),
                         "-DOPENSSL_USE_STATIC_LIBS=ON",
                         "-DVulkan_GLSLC_EXECUTABLE=" .. glslc,
                         "-DCMAKE_BUILD_RPATH=" .. path.join(package:dep("vulkan-loader"):installdir(), "lib")}
        table.insert(configs, "-DCMAKE_IGNORE_PREFIX_PATH=/opt/homebrew;/usr/local")
        local envs = import("package.tools.cmake").buildenvs(package)
        envs.PKG_CONFIG_PATH = pkgconfig
        envs.PKG_CONFIG_LIBDIR = pkgconfig
        if package:config("sdl") or package:config("ffmpeg") then
            local paths = {pkgconfig}
            for _, name in ipairs({"libsdl2", "ffmpeg"}) do
                local dep = package:dep(name)
                if dep then
                    table.insert(paths, path.join(dep:installdir(), "lib", "pkgconfig"))
                end
            end
            envs.PKG_CONFIG_PATH = path.joinenv(paths)
            envs.PKG_CONFIG_LIBDIR = envs.PKG_CONFIG_PATH
        end
        import("package.tools.cmake").build(package, configs, {builddir = "build", target = "shade", cmake_generator = "Ninja", envs = envs})
        local allowed = {"/usr/lib/", "/System/", "@rpath/libvulkan"}
        for _, name in ipairs({"libsdl2", "ffmpeg"}) do
            local dep = package:dep(name)
            if dep then
                table.insert(allowed, dep:installdir())
            end
        end
        local linked = os.iorunv("otool", {"-L", path.join("build", "shade")})
        for line in linked:gmatch("[^\n]+") do
            local library = line:match("^%s+(%S+)")
            local known = false
            for _, prefix in ipairs(allowed) do
                known = known or (library and library:startswith(prefix))
            end
            if library and not known then
                raise("the emulator links %s, which is neither a system library nor one of its packages; the build found a library outside Charon", library)
            end
        end
        os.cp(path.join("build", "shade"), package:installdir("bin") .. "/")
        os.cp("LICENSE", package:installdir("licenses") .. "/")
        os.cp("NOTICE", package:installdir("licenses") .. "/")
    end)

    on_test(function (package)
        local listed = os.iorunv(path.join(package:installdir("bin"), "shade"), {"profile", "--list"})
        assert(listed:find("iPhone3,1", 1, true))
    end)
