package("micro-ecc")
    set_homepage("https://github.com/kmackay/micro-ecc")
    set_description("micro-ecc, Kenneth MacKay's portable elliptic curve arithmetic, unmodified, as a static library whose every symbol is hidden: secp256r1 (P-256) signing and verification in 1700 lines of C, for the image that links it in. iOS 6 has no way to make an ECDSA signature of its own - SecKeyCreateRandomKey and SecKeyCreateSignature are iOS 8 - so the CloudKit backports link this for the ES256 signature a CloudKit Web Services authentication key takes")
    set_license("BSD-2-Clause")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/kmackay/micro-ecc.git")
    add_versions("2024.11.14", "541b3a78026420a3e369c4c9281c396b5e531113")
    add_links("micro-ecc")

    add_configs("recipe", {description = "The digest of this recipe, so a changed flag is a different library.", default = hash.strhash128(hash.sha256(path.join(os.scriptdir(), "xmake.lua"))), type = "string", readonly = true})

    local FLAGS = {"-Os", "-fvisibility=hidden", "-fno-strict-aliasing"}

    on_install("iphoneos", function (package)
        local toolchain = assert(package:toolchains(), "micro-ecc is built with the apple-ios toolchain")[1]
        toolchain:load()
        local target = {"-target", package:arch() .. "-apple-ios", "-miphoneos-version-min=" .. toolchain:config("deployment"),
                        "-isysroot", toolchain:config("sdkdir"), "-I" .. os.curdir()}
        local object = path.absolute(path.join("objects", "uECC.c.o"))
        os.mkdir(path.directory(object))
        os.vrunv(toolchain:tool("cc"), table.join(target, FLAGS, {"-I.", "-c", "uECC.c", "-o", object}))
        os.vrunv("xcrun", table.join({"libtool", "-static", "-o", path.join(package:installdir("lib"), "libmicro-ecc.a")}, {object}))
        for _, header in ipairs({"uECC.h", "uECC_vli.h", "types.h"}) do
            os.vcp(header, package:installdir("include"))
        end
        os.vcp("LICENSE.txt", package:installdir("licenses"))
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libmicro-ecc.a")))
        assert(os.isfile(path.join(package:installdir("include"), "uECC.h")))
    end)
