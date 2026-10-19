package("monocypher")
    set_homepage("https://monocypher.org")
    set_description("Monocypher 4.0.2, the curves and the AEAD HAP pairs with: X25519, Ed25519 and ChaCha20-Poly1305 (the IETF construction, which is the one HAP's session keys use) and the hash the key derivation is built on, unmodified, as a static library whose every symbol is hidden, for the image that links it in")
    set_license("BSD-2-Clause OR CC0-1.0")
    set_policy("package.strict_compatibility", true)

    -- The sources come from Monocypher's own tarball, not from a copy in this tree: xmake builds a
    -- package in its own source directory, which does not hold a vendored file, and a recipe that
    -- compiled beside itself failed the gate with "no such file or directory: 'monocypher.c'". The
    -- sha256 below pins the tarball, so the bytes are the release the description names.
    add_urls("https://monocypher.org/download/monocypher-$(version).tar.gz")
    add_versions("4.0.2", "38d07179738c0c90677dba3ceb7a7b8496bcfea758ba1a53e803fed30ae0879c")
    add_links("Monocypher")

    add_configs("recipe", {description = "The digest of this recipe, so a changed flag is a different library.", default = hash.strhash128(hash.sha256(path.join(os.scriptdir(), "xmake.lua"))), type = "string", readonly = true})

    -- Hidden, for the reason Box2D's recipe gives: libHomeKitBackports.dylib exports what HomeKit
    -- does, and nothing a second copy of Monocypher in the process could bind to. The two sources the
    -- tarball ships under src/, and the optional Ed25519 under src/optional/, are laid out side by side
    -- in the build directory because monocypher-ed25519.c includes "monocypher.h" and the release
    -- keeps them in different folders.
    local FLAGS = {"-Os", "-fvisibility=hidden", "-fvisibility-inlines-hidden", "-DCONFIG_64_BITS"}

    on_install("iphoneos", function (package)
        local toolchain = assert(package:toolchains(), "monocypher is built with the apple-ios toolchain")[1]
        toolchain:load()
        -- The compiler is the one the charon toolchain names, taken from the llvm package the
        -- way toolchains/apple-ios/xmake.lua's parts() takes it, and not through
        -- toolchain:tool("cc"): that call falls back to the host's /usr/bin/clang silently when the
        -- toolchain has not resolved its llvm package, and the host's clang cannot target
        -- armv7-apple-ios at all. The 4.3 gate's resolve hit exactly that and the install failed
        -- with a runv of /usr/bin/clang. Naming the package, and refusing when it is not there,
        -- turns that silent fallback into a failure that says what it wants.
        -- The project, not the package: a package has no required_packages() in this xmake (it is
        -- the project that holds the graph), and the toolchain reads llvm from the project the same
        -- way -- toolchains/apple-ios/xmake.lua's parts() takes import("core.project.project").
        local project = import("core.project.project")
        local llvm = (project:required_packages() or {})["llvm"]
        if not llvm then
            raise("charon@monocypher is built with the charon toolchain's clang, which comes from the llvm package; this package's graph does not hold it")
        end
        local compiler = path.join(llvm:installdir(), "bin", "clang")
        if not os.isfile(compiler) then
            raise("charon@monocypher needs the charon clang at %s, and there is none there", compiler)
        end
        -- xmake strips the tarball's top folder, so what the release ships as
        -- monocypher-$(version)/src/monocypher.c is at src/monocypher.c here. Naming the release folder
        -- is what the gate reported: "cannot copy file monocypher-4.0.2/src/monocypher.c, file not
        -- found!".
        local staged = path.join("build", "src")
        os.mkdir(staged)
        for _, name in ipairs({"monocypher.c", "monocypher.h", "optional/monocypher-ed25519.c", "optional/monocypher-ed25519.h"}) do
            os.cp(path.join("src", name), path.join(staged, path.filename(name)))
        end
        local target = {"-target", package:arch() .. "-apple-ios", "-miphoneos-version-min=" .. toolchain:config("deployment"),
                        "-isysroot", toolchain:config("sdkdir"), "-I" .. staged}
        local objects = {}
        for _, source in ipairs({"monocypher.c", "monocypher-ed25519.c"}) do
            local object = path.absolute(path.join("objects", source:gsub("%.c$", ".o")))
            os.mkdir(path.directory(object))
            os.vrunv(compiler, table.join(target, FLAGS, {"-c", path.join(staged, source), "-o", object}))
            table.insert(objects, object)
        end
        os.vrunv("xcrun", table.join({"libtool", "-static", "-o", path.join(package:installdir("lib"), "libMonocypher.a")}, objects))
        os.mkdir(package:installdir("include", "monocypher"))
        for _, header in ipairs({"monocypher.h", "monocypher-ed25519.h"}) do
            os.vcp(path.join(staged, header), path.join(package:installdir("include"), "monocypher", header))
        end
        os.mkdir(package:installdir("licenses"))
        os.vcp("LICENCE.md", path.join(package:installdir("licenses"), "LICENCE.md"))
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libMonocypher.a")))
        assert(os.isfile(path.join(package:installdir("include"), "monocypher", "monocypher.h")))
        assert(os.isfile(path.join(package:installdir("licenses"), "LICENCE.md")))
    end)
