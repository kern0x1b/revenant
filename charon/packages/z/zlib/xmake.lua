package("zlib")
    set_homepage("https://github.com/madler/zlib")
    set_description("zlib 1.3.2, unmodified (the deflate and inflate core, no gz file layer), as a static library whose every symbol is hidden: the raw deflate that COMPRESSION_ZLIB writes and reads in the Compression backport.")
    set_license("Zlib")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/madler/zlib.git")
    add_versions("v1.3.2", "da607da739fa6047df13e66a2af6b8bec7c2a498")
    add_links("zcodec")

    local digest = {hash.sha256(path.join(os.scriptdir(), "xmake.lua"))}
    add_configs("recipe", {description = "The digest of this recipe, so a changed flag is a different library.", default = hash.strhash128(table.concat(digest, ";")), type = "string", readonly = true})

    local FLAGS = {"-Os", "-fvisibility=hidden", "-fno-strict-aliasing"}
    local SOURCES = {"adler32.c", "crc32.c", "deflate.c", "infback.c", "inffast.c", "inflate.c", "inftrees.c", "trees.c", "zutil.c"}

    on_install("iphoneos", function (package)
        local toolchain = assert(package:toolchains(), "zlib is built with the apple-ios toolchain")[1]
        toolchain:load()
        local target = {"-target", package:arch() .. "-apple-ios", "-miphoneos-version-min=" .. toolchain:config("deployment"),
                        "-isysroot", toolchain:config("sdkdir"), "-I" .. os.curdir()}
        local objects = {}
        for _, source in ipairs(SOURCES) do
            local object = path.absolute(path.join("objects", source .. ".o"))
            os.mkdir(path.directory(object))
            os.vrunv(toolchain:tool("cc"), table.join(target, FLAGS, {"-c", source, "-o", object}))
            table.insert(objects, object)
        end
        os.vrunv("xcrun", table.join({"libtool", "-static", "-o", path.join(package:installdir("lib"), "libzcodec.a")}, objects))
        os.mkdir(package:installdir("include", "zlib"))
        os.vcp("zlib.h", package:installdir("include", "zlib"))
        os.vcp("zconf.h", package:installdir("include", "zlib"))
        os.vcp("LICENSE", package:installdir("licenses"))
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libzcodec.a")))
        assert(os.isfile(path.join(package:installdir("include"), "zlib", "zlib.h")))
    end)
