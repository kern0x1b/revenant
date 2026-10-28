package("tesseract")
    set_kind("library")
    set_homepage("https://github.com/tesseract-ocr/tesseract")
    set_description("Tesseract 5.5.3, the LSTM text recognizer behind Vision's VNRecognizeTextRequest: the static library without training tools, graphics or the legacy engine")
    set_license("Apache-2.0")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/tesseract-ocr/tesseract.git")
    add_versions("5.5.3", "db0ec62f81b0737fbbe184d8fea40af5738f8eef")
    add_deps("cmake", "ninja", {kind = "binary"})
    add_links("tesseract")

    local patches = {"5.5.3-apple-neon-sysctl.patch"}
    local digests = {"xmake.lua=" .. hash.sha256(path.join(os.scriptdir(), "xmake.lua"))}
    for _, name in ipairs(patches) do
        local file = path.join(os.scriptdir(), "patches", name)
        local digest = hash.sha256(file)
        add_patches("5.5.3", file, digest)
        table.insert(digests, name .. "=" .. digest)
    end
    add_configs("recipe", {description = "The digest of this recipe and the patches it applies, so a changed patch is a different build.",
                           default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    local configs = {
        "-DBUILD_SHARED_LIBS=OFF",
        "-DBUILD_TESTS=OFF",
        "-DBUILD_TRAINING_TOOLS=OFF",
        "-DDISABLED_LEGACY_ENGINE=ON",
        "-DDISABLE_ARCHIVE=ON",
        "-DDISABLE_CURL=ON",
        "-DDISABLE_TIFF=ON",
        "-DENABLE_LTO=OFF",
        "-DENABLE_NATIVE=OFF",
        "-DGRAPHICS_DISABLED=ON",
        "-DINSTALL_CONFIGS=OFF",
        "-DLEPT_TIFF_COMPILE_SUCCESS=TRUE",
        "-DLEPT_TIFF_RESULT=1",
        "-DOPENMP_BUILD=OFF"
    }

    on_load(function (package)
        package:add("deps", "revenant@leptonica", {alias = "leptonica"})
        if package:is_plat("iphoneos") then
            package:add("deps", "revenant@libcxx", {alias = "libcxx"})
        end
    end)

    on_install("iphoneos", function (package)
        local cmake = import("@addon.revenant.apple.cmake", {anonymous = true})
        cmake.install(package, configs, {deps = {"libcxx", "leptonica"}, licenses = "LICENSE"})
    end)

    on_install("macosx", function (package)
        import("package.tools.cmake").install(package, configs, {cmake_generator = "Ninja"})
        os.cp("LICENSE", package:installdir("licenses") .. "/")
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libtesseract.a")))
        assert(os.isfile(path.join(package:installdir("include"), "tesseract", "baseapi.h")))
    end)
