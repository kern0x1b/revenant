package("lzfse")
    set_homepage("https://github.com/lzfse/lzfse")
    set_description("lzfse, the LZFSE and LZVN reference codec, unmodified, as a static library whose every symbol is hidden: the codec behind COMPRESSION_LZFSE in the Compression backport.")
    set_license("BSD-3-Clause")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/lzfse/lzfse.git")
    add_versions("lzfse-1.0", "88e2d2788b4021d0b2eb9fe2d97352ae9190f128")
    add_links("lzfse")

    local digest = {hash.sha256(path.join(os.scriptdir(), "xmake.lua"))}
    add_configs("recipe", {description = "The digest of this recipe, so a changed flag is a different library.", default = hash.strhash128(table.concat(digest, ";")), type = "string", readonly = true})

    local FLAGS = {"-Os", "-fvisibility=hidden", "-fno-strict-aliasing", "-DLZFSE_API="}
    local SOURCES = {"src/lzfse_decode.c", "src/lzfse_decode_base.c", "src/lzfse_encode.c", "src/lzfse_encode_base.c",
                     "src/lzfse_fse.c", "src/lzvn_decode_base.c", "src/lzvn_encode_base.c"}

    on_install("iphoneos", function (package)
        local toolchain = assert(package:toolchains(), "lzfse is built with the apple-ios toolchain")[1]
        toolchain:load()
        local target = {"-target", package:arch() .. "-apple-ios", "-miphoneos-version-min=" .. toolchain:config("deployment"),
                        "-isysroot", toolchain:config("sdkdir"), "-I" .. os.curdir(), "-Isrc"}
        local objects = {}
        for _, source in ipairs(SOURCES) do
            local object = path.absolute(path.join("objects", path.filename(source) .. ".o"))
            os.mkdir(path.directory(object))
            os.vrunv(toolchain:tool("cc"), table.join(target, FLAGS, {"-c", source, "-o", object}))
            table.insert(objects, object)
        end
        os.vrunv("xcrun", table.join({"libtool", "-static", "-o", path.join(package:installdir("lib"), "liblzfse.a")}, objects))
        os.mkdir(package:installdir("include", "lzfse"))
        for _, header in ipairs({"src/lzfse.h", "src/lzfse_internal.h", "src/lzfse_fse.h", "src/lzfse_tunables.h", "src/lzvn_decode_base.h"}) do
            os.vcp(header, package:installdir("include", "lzfse"))
        end
        os.vcp("LICENSE", package:installdir("licenses"))
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "liblzfse.a")))
        assert(os.isfile(path.join(package:installdir("include"), "lzfse", "lzfse.h")))
    end)
