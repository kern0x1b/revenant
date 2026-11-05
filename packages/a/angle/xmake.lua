local PINNED = {
    ["libEGL.dylib"] = "e2c562884bb6cdda6d191b451899a75727eaafce4256ad9474633058920c5152",
    ["libGLESv2.dylib"] = "a237e9a51970a79e7534527665246fa4d93447e2bedb6809fdcb14a95f3443b2",
    ["libvk_swiftshader.dylib"] = "ffa750fd2123ea58cd70ad854d8f40bf33e92d0cb034f46d7ee51c6be29ca8f5",
    ["vk_swiftshader_icd.json"] = "d717d915e31e7c27948b80b36ab34e2d897888114c5c7d0af835f93eb53e58f5",
}

package("angle")
    set_kind("binary")
    set_homepage("https://chromium.googlesource.com/angle/angle")
    set_description("ANGLE 2.1.26625, the OpenGL ES 2.0 and EGL implementation that draws through Metal on this Mac, pinned as the libraries of Chromium Embedded Framework 144.0.15.0. It is not built from source: the four files are copied from a CEF bundle, and each is checked against its sha256 before it is copied. The host oracle that translated Metal shaders are checked against")
    set_license("BSD-3-Clause")

    add_configs("cef", {description = "The Libraries folder of a Chromium Embedded Framework 144.0.15.0 bundle, which holds the four pinned files", type = "string"})

    add_versions("144.0.15.0", "4285b6c6df76b10bf949323a5b2447f2003c412847a7cd8f7f6807b4273b09b6")

    on_install("macosx|arm64", function (package)
        local source = package:config("cef")
        assert(source and os.isdir(source), "angle needs cef=<the Libraries folder of a Chromium Embedded Framework 144.0.15.0 bundle>")
        local lib = path.join(package:installdir(), "lib")
        os.mkdir(lib)
        for name, digest in pairs(PINNED) do
            local file = path.join(source, name)
            assert(os.isfile(file), "the CEF bundle has no " .. name)
            assert(hash.sha256(file) == digest, name .. " is not the pinned file: its sha256 differs")
            os.cp(file, path.join(lib, name))
        end
    end)

    on_test(function (package)
        local lib = path.join(package:installdir(), "lib")
        for name, digest in pairs(PINNED) do
            assert(hash.sha256(path.join(lib, name)) == digest, name .. " in the install differs from its pin")
        end
    end)
