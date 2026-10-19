package("micro-ecc")
    set_homepage("https://github.com/kmackay/micro-ecc")
    set_description("micro-ecc, Kenneth MacKay's portable elliptic curve arithmetic, unmodified, as a static library whose every symbol is hidden: secp256r1 (P-256) signing and verification in 1700 lines of C, for the image that links it in. iOS 6 has no way to make an ECDSA signature of its own - SecKeyCreateRandomKey and SecKeyCreateSignature are iOS 8 - so the CloudKit backports link this for the ES256 signature a CloudKit Web Services authentication key takes")
    set_license("BSD-2-Clause")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/kmackay/micro-ecc.git")
    add_versions("2024.11.14", "541b3a78026420a3e369c4c9281c396b5e531113")
    add_links("micro-ecc")

    local digest = {hash.sha256(path.join(os.scriptdir(), "xmake.lua"))}
    for _, file in ipairs(os.files(path.join(os.scriptdir(), "files", "**"))) do
        digest[#digest + 1] = hash.sha256(file)
    end
    add_configs("recipe", {description = "The digest of this recipe and of the files it adds, so a changed flag or a changed wrapper is a different library.", default = hash.strhash128(table.concat(digest, ";")), type = "string", readonly = true})

    local FLAGS = {"-Os", "-fvisibility=hidden", "-fno-strict-aliasing"}

    on_install("iphoneos", function (package)
        local toolchain = assert(package:toolchains(), "micro-ecc is built with the apple-ios toolchain")[1]
        toolchain:load()
        local target = {"-target", package:arch() .. "-apple-ios", "-miphoneos-version-min=" .. toolchain:config("deployment"),
                        "-isysroot", toolchain:config("sdkdir"), "-I" .. os.curdir()}
        local objects = {}
        local sources = {{path = "uECC.c", where = "."},
                         {path = path.join(os.scriptdir(), "files", "CharonCKWebAuth.c"), where = path.join(os.scriptdir(), "files")}}
        for _, entry in ipairs(sources) do
            local object = path.absolute(path.join("objects", (path.filename(entry.path) .. ".o")))
            os.mkdir(path.directory(object))
            os.vrunv(toolchain:tool("cc"), table.join(target, FLAGS, {"-I" .. entry.where, "-I.", "-c", entry.path, "-o", object}))
            table.insert(objects, object)
        end
        os.vrunv("xcrun", table.join({"libtool", "-static", "-o", path.join(package:installdir("lib"), "libmicro-ecc.a")}, objects))
        for _, header in ipairs({"uECC.h", "uECC_vli.h", "types.h", path.join(os.scriptdir(), "files", "CharonCKWebAuth.h")}) do
            os.vcp(header, package:installdir("include"))
        end
        os.vcp("LICENSE.txt", package:installdir("licenses"))
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libmicro-ecc.a")))
        assert(os.isfile(path.join(package:installdir("include"), "uECC.h")))
        assert(os.isfile(path.join(package:installdir("include"), "CharonCKWebAuth.h")))
        local hashed = #os.files(path.join(os.scriptdir(), "files", "**"))
        assert(hashed > 0, "the recipe digests the files it adds and found none of them")
        local added = {"CharonCKWebAuth.c", "CharonCKWebAuth.h"}
        for _, name in ipairs(added) do
            assert(os.isfile(path.join(os.scriptdir(), "files", name)), "the recipe adds " .. name .. " and it is not there")
        end
        assert(hashed == #added, "the digest read " .. hashed .. " files and the recipe adds " .. #added)
        local header = io.readfile(path.join(os.scriptdir(), "files", "CharonCKWebAuth.h"))
        local wrapper = io.readfile(path.join(os.scriptdir(), "files", "CharonCKWebAuth.c"))
        for name in header:gmatch("%s(Charon%w+)%s*%(") do
            local defined = wrapper:match("[%a][%w%* ]*" .. name .. "%s*%(")
            if not defined then
                assert(false, "the header declares " .. name .. " and the source does not define it")
            end
        end
        assert(header:find("CharonCKSHA256"), "the header declares the SHA-256 the message-level pair is built on")
    end)
