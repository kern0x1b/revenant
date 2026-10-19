package("picotls")
    set_homepage("https://github.com/h2o/picotls")
    set_description("picotls (h2o), the minimal TLS 1.3 implementation with a crypto backend of its own, as two static archives for the port: the release's own SecureTransport stops at TLS 1.1, so this is the TLS a QUIC handshake is made with")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/h2o/picotls.git")
    -- The version is the date of the commit, because this tree carries no release tag for it and a
    -- date says which tree a build of it came from; the checksum is the commit itself, which is what
    -- xmake checks a git source against.
    add_versions("2026.09.24", "d6c3da61b47cc3ccecaf9aa093c24e4aafebd52a")

    add_deps("charon@apple-compat", {alias = "apple-compat"})

    add_configs("recipe", {description = "The digest of this recipe, so a changed flag is a different pair of archives.", default = hash.strhash128(hash.sha256(path.join(os.scriptdir(), "xmake.lua"))), type = "string", readonly = true})

    -- The two archives the project itself builds, as its own CMakeLists.txt names them: the core
    -- (the state machine, HPKE and PEM) and minicrypto (its own AES-GCM, ChaCha20, SHA-2, X25519 and
    -- secp256r1, with no OpenSSL behind it - the port has no armv7 OpenSSL, and minicrypto is what
    -- picotls offers for a target that has none). What is NOT built: lib/openssl.c, lib/mbedtls.c,
    -- lib/hpke's OpenSSL path, lib/certificate_compression.c (it wants brotli) and the `fusion` AES-GCM
    -- engine (it wants liboqs or a CPU-specific assembler build), and the whole of t/ and fuzz/.
    --
    -- `-femulated-tls` is the one flag that is not picotls's: picotls.h declares a thread-local, and
    -- an armv7 build below iOS 9 has no real `__thread` - the same reason every other package of this
    -- port that uses threads is built with it (modules/apple/cmake.lua's `emulated_tls`, and
    -- packages/m/matter). The flag comes from the toolchain, not from here.
    local CORE = {"lib/hpke.c", "lib/picotls.c", "lib/pembase64.c"}
    local MINICRYPTO = {
        "deps/micro-ecc/uECC.c",
        "deps/cifra/src/aes.c", "deps/cifra/src/blockwise.c", "deps/cifra/src/chacha20.c",
        "deps/cifra/src/chash.c", "deps/cifra/src/curve25519.c", "deps/cifra/src/drbg.c",
        "deps/cifra/src/hmac.c", "deps/cifra/src/gcm.c", "deps/cifra/src/gf128.c",
        "deps/cifra/src/modes.c", "deps/cifra/src/poly1305.c", "deps/cifra/src/sha256.c",
        "deps/cifra/src/sha512.c",
        "lib/cifra.c", "lib/cifra/x25519.c", "lib/cifra/chacha20.c", "lib/cifra/aes128.c",
        "lib/cifra/aes256.c", "lib/cifra/random.c", "lib/minicrypto-pem.c", "lib/uecc.c",
        "lib/asn1.c", "lib/ffx.c"
    }
    local INCLUDES = {"deps/cifra/src/ext", "deps/cifra/src", "deps/micro-ecc", "deps/picotest", "include"}

    -- The headers a port that links one of these archives needs: the umbrella and everything under
    -- picotls/, in the layout the sources name them with, so `-I<includedir>` and `#include
    -- <picotls.h>` is all a consumer writes.
    on_install("iphoneos", function (package)
        local toolchain = assert(package:toolchains(), "picotls is built with the apple-ios toolchain")[1]
        toolchain:load()
        local sdk = assert(toolchain:config("sdkdir"), "the apple-ios toolchain names no SDK")
        local minimum = assert(toolchain:config("deployment"), "the apple-ios toolchain names no minimum release")
        local target = {"-target", package:arch() .. "-apple-ios", "-miphoneos-version-min=" .. minimum, "-isysroot", sdk}
        local flags = table.join({"-std=c99", "-Os", "-fvisibility=hidden", "-w"},
                                 toolchain:config("emulated_tls") and {"-femulated-tls"} or {})
        local include_flags = {}
        for _, directory in ipairs(INCLUDES) do
            table.insert(include_flags, "-I" .. path.join(os.curdir(), directory))
        end

        local objects = path.join(package:installdir("lib"), "obj")
        os.mkdir(objects)
        local function compile(sources)
            local built = {}
            for _, source in ipairs(sources) do
                local object = path.join(objects, (source:gsub("[/\\]", "_") .. ".o"))
                os.vrunv(toolchain:tool("cc"), table.join(target, flags, include_flags,
                                                         {"-c", path.join(os.curdir(), source), "-o", object}))
                table.insert(built, object)
            end
            return built
        end

        local core = compile(CORE)
        local minicrypto = compile(MINICRYPTO)
        -- Two archives, and the order they are given a consumer in: the core first, the crypto that
        -- fills in its primitives second, which is what the project's own link line is.
        os.vrunv("xcrun", table.join({"libtool", "-static", "-o", path.join(package:installdir("lib"), "libpicotls-core.a")}, core))
        os.vrunv("xcrun", table.join({"libtool", "-static", "-o", path.join(package:installdir("lib"), "libpicotls-minicrypto.a")}, minicrypto))

        local include = package:installdir("include")
        for _, header in ipairs(os.files(path.join(os.curdir(), "include", "**", "*.h"))) do
            os.cp(header, path.join(include, path.directory(header)) .. "/")
        end
        for _, notice in ipairs({"LICENSE", "README.md", "SECURITY.md"}) do
            if os.isfile(path.join(os.curdir(), notice)) then
                os.vcp(notice, package:installdir("licenses"))
            end
        end
    end)

    on_test(function (package)
        for _, archive in ipairs({"libpicotls-core.a", "libpicotls-minicrypto.a"}) do
            assert(os.isfile(path.join(package:installdir("lib"), archive)), archive .. " is not installed")
        end
        for _, header in ipairs({"picotls.h", "picotls/minicrypto.h"}) do
            assert(os.isfile(path.join(package:installdir("include"), header)), header .. " is not installed")
        end
    end)
