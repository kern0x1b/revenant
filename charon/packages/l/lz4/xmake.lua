package("lz4")
    set_homepage("https://github.com/lz4/lz4")
    set_description("LZ4, the block codec, unmodified (lib/ only), as a static library whose every symbol is hidden: the codec behind COMPRESSION_LZ4_RAW and the blocks of COMPRESSION_LZ4 in the Compression backport.")
    set_license("BSD-2-Clause")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/lz4/lz4.git")
    add_versions("v1.9.2", "fdf2ef5809ca875c454510610764d9125ef2ebbd")
    add_links("lz4")

    local digest = {hash.sha256(path.join(os.scriptdir(), "xmake.lua"))}
    add_configs("recipe", {description = "The digest of this recipe, so a changed flag is a different library.", default = hash.strhash128(table.concat(digest, ";")), type = "string", readonly = true})

    local FLAGS = {"-Os", "-fvisibility=hidden", "-fno-strict-aliasing", "-DLZ4LIB_VISIBILITY="}

    on_install("iphoneos", function (package)
        local toolchain = assert(package:toolchains(), "lz4 is built with the apple-ios toolchain")[1]
        toolchain:load()
        local target = {"-target", package:arch() .. "-apple-ios", "-miphoneos-version-min=" .. toolchain:config("deployment"),
                        "-isysroot", toolchain:config("sdkdir"), "-I" .. os.curdir(), "-Ilib"}
        local object = path.absolute(path.join("objects", "lz4.c.o"))
        os.mkdir(path.directory(object))
        os.vrunv(toolchain:tool("cc"), table.join(target, FLAGS, {"-c", "lib/lz4.c", "-o", object}))
        os.vrunv("xcrun", {"libtool", "-static", "-o", path.join(package:installdir("lib"), "liblz4.a"), object})
        os.mkdir(package:installdir("include", "lz4"))
        os.vcp("lib/lz4.h", package:installdir("include", "lz4"))
        os.vcp("LICENSE", package:installdir("licenses"))
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "liblz4.a")))
        assert(os.isfile(path.join(package:installdir("include"), "lz4", "lz4.h")))
    end)
