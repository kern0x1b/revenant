package("micro-ecc")
    set_homepage("https://github.com/kmackay/micro-ecc")
    set_description("micro-ecc, Kenneth MacKay's portable elliptic curve arithmetic, unmodified, as a static library whose every symbol is hidden: secp256r1 (P-256) signing and verification in 1700 lines of C, for the image that links it in. iOS 6 has no way to make an ECDSA signature of its own - SecKeyCreateRandomKey and SecKeyCreateSignature are iOS 8 - so the CloudKit backports link this for the ES256 signature a CloudKit Web Services authentication key takes")
    set_license("BSD-2-Clause")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/kmackay/micro-ecc.git")
    add_versions("2024.11.14", "541b3a78026420a3e369c4c9281c396b5e531113")
    add_links("micro-ecc")

    -- The digest of the recipe **and of the files it adds**, so that a changed wrapper is a different
    -- package. Hashing the recipe alone does not: a change to files/CharonCKWebAuth.c leaves the
    -- package identity alone and the store hands back the archive built from the wrapper before it, which
    -- is what a gate run of another band measured - the four CharonCK functions it needed were not in the
    -- archive the link saw, and the digest of the recipe never moved.
    local digest = {hash.sha256(path.join(os.scriptdir(), "xmake.lua"))}
    for _, file in ipairs(os.files(path.join(os.scriptdir(), "files", "**"))) do
        digest[#digest + 1] = hash.sha256(file)
    end
    add_configs("recipe", {description = "The digest of this recipe and of the files it adds, so a changed flag or a changed wrapper is a different library.", default = hash.strhash128(table.concat(digest, ";")), type = "string", readonly = true})

    -- Hidden, so the arithmetic is never API of the image that links it in: libCloudKitBackports.dylib
    -- exports CloudKit and nothing a second copy of a curve implementation in the process could bind to.
    -- The library chooses uECC_WORD_SIZE from the target itself (4 for armv7, 8 for arm64) and needs
    -- no define from here, and it uses the ARM assembly path its own platform-specific.inc selects for
    -- __arm__ without Thumb interworking problems, which is what the port's Mach-O checks are about.
    local FLAGS = {"-Os", "-fvisibility=hidden", "-fno-strict-aliasing"}

    on_install("iphoneos", function (package)
        local toolchain = assert(package:toolchains(), "micro-ecc is built with the apple-ios toolchain")[1]
        toolchain:load()
        local target = {"-target", package:arch() .. "-apple-ios", "-miphoneos-version-min=" .. toolchain:config("deployment"),
                        "-isysroot", toolchain:config("sdkdir"), "-I" .. os.curdir()}
        local objects = {}
        -- uECC.c comes from the fetched upstream, and the JOSE wrapper from this package's own
        -- files/ directory - which is where a package keeps what it adds to what it fetched, and not
        -- in the fetched tree. The first version named the wrapper "files/CharonCKWebAuth.c" and read
        -- it out of the build directory, where the git checkout has no files/ at all; the gate
        -- installed micro-ecc and said `no such file or directory`, which is how it was found.
        local sources = {{path = "uECC.c", where = "."},
                         {path = path.join(os.scriptdir(), "files", "CharonCKWebAuth.c"), where = path.join(os.scriptdir(), "files")}}
        for _, entry in ipairs(sources) do
            local object = path.absolute(path.join("objects", (path.filename(entry.path) .. ".o")))
            os.mkdir(path.directory(object))
            os.vrunv(toolchain:tool("cc"), table.join(target, FLAGS, {"-I" .. entry.where, "-I.", "-c", entry.path, "-o", object}))
            table.insert(objects, object)
        end
        os.vrunv("xcrun", table.join({"libtool", "-static", "-o", path.join(package:installdir("lib"), "libmicro-ecc.a")}, objects))
        -- The wrapper's header goes beside upstream's three: a caller of the curve needs the one
        -- that declares the signature, and without it the CloudKit library cannot find it.
        for _, header in ipairs({"uECC.h", "uECC_vli.h", "types.h", path.join(os.scriptdir(), "files", "CharonCKWebAuth.h")}) do
            os.vcp(header, package:installdir("include"))
        end
        os.vcp("LICENSE.txt", package:installdir("licenses"))
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libmicro-ecc.a")))
        assert(os.isfile(path.join(package:installdir("include"), "uECC.h")))
        -- the header a caller of the curve includes, which the recipe installs beside upstream's three
        -- and which the recipe's own comment names: without it the library that links the archive
        -- cannot find the declaration of the signature.
        assert(os.isfile(path.join(package:installdir("include"), "CharonCKWebAuth.h")))
        -- and the number of files the digest consumed. The glob is files/**: os.files("files/*") is not
        -- recursive (measured with a nested file in a scratch tree: one match against two), so the
        -- first files/sub/whatever.c would fall out of the digest silently and the store would hand
        -- back the archive built from the wrapper before it - the exact failure the digest is for.
        -- Counting the files makes a missed one a test failure and not a stale archive.
        -- The digest must cover every file the package adds, and the check has to be able to fail: a
        -- The digest must cover every file the package adds, and the check must be able to fail: a
        -- glob counted against itself cannot. So the count the digest walked is compared with what
        -- the recipe *adds* - the wrapper's two files, named where they are copied and compiled -
        -- which is a different statement from any listing of the directory. Put a third file in
        -- files/ without naming it in the recipe and the two numbers part company, which is the
        -- whole point.
        --
        -- Three listings were tried and none of them exists in the sandbox on_test runs in: os.filetypes
        -- and os.iolines are not functions there, and there is no next. Each was measured in its own
        -- install, and the three errors are the record.
        local hashed = #os.files(path.join(os.scriptdir(), "files", "**"))
        assert(hashed > 0, "the recipe digests the files it adds and found none of them")
        local added = {"CharonCKWebAuth.c", "CharonCKWebAuth.h"}
        for _, name in ipairs(added) do
            assert(os.isfile(path.join(os.scriptdir(), "files", name)), "the recipe adds " .. name .. " and it is not there")
        end
        assert(hashed == #added, "the digest read " .. hashed .. " files and the recipe adds " .. #added)
        -- Every entry point the header declares is defined in the source beside it. This is the check
        -- that would have caught the one that was not: a declaration with no definition is a header
        -- that promises a function nothing can link, and this band's own Security library failed at
        -- the link on CharonCKSHA256 while the header named it.
        --
        -- It reads the two files rather than the archive's symbol table on purpose: on_test runs in a
        -- sandbox that has no nm and no next, and a check that needs a tool it does not get is a check
        -- that never runs. The definition and the declaration differ in a prototype's return type, so
        -- the comparison is on the name at the start of a line that ends in an opening parenthesis.
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
