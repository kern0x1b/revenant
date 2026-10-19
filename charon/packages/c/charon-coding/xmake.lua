package("charon-coding")
    set_homepage("https://github.com/kern0x1b/charon")
    set_description("The secure coding and the copying every backport's data classes share, as a static library whose every symbol is hidden, for the dylibs that link it in")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_links("charon-coding")

    -- The digest of the **sources**, not of this file alone. A recipe that hashes only itself is
    -- micro-ecc's bug: a change to a file under files/ left the digest as it was, the package
    -- was the one already installed, and the change never reached a build that wanted it. Every
    -- file this library is made of is in the digest, so a changed helper is a different package
    -- with its own install path.
    local digests = {"xmake.lua=" .. hash.sha256(path.join(os.scriptdir(), "xmake.lua"))}
    local sources = table.join(os.files(path.join(os.scriptdir(), "files", "*.h")),
                                  os.files(path.join(os.scriptdir(), "files", "*.m")))
    table.sort(sources)
    for _, source in ipairs(sources) do
        table.insert(digests, path.filename(source) .. "=" .. hash.sha256(source))
    end
    add_configs("recipe", {description = "The digest of this recipe and every file of the library, so a changed helper is a different package.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    -- Hidden, so the helpers are never API of the image they are linked into: a library that
    -- exports them would be checked by check_registry for entries, and a name two dylibs in one
    -- process both bind would be whichever loaded first. Every name starts with charon_, which
    -- modules/apple/backports.lua's internal_symbol() puts in -unexported_symbols_list, and the
    -- linker takes the archive's own members per dylib that links it, so each library has its
    -- own hidden copy - the linker doing its job, not a second copy of the source.
    local FLAGS = {"-Os", "-fvisibility=hidden"}

    on_install("iphoneos", function (package)
        local toolchain = assert(package:toolchains(), "charon-coding is built with the apple-ios toolchain")[1]
        toolchain:load()
        local target = {"-target", package:arch() .. "-apple-ios",
                        "-miphoneos-version-min=" .. toolchain:config("deployment"),
                        "-isysroot", toolchain:config("sdkdir"), "-I" .. os.curdir()}
        local sources = os.files(path.join(os.scriptdir(), "files", "*.m"))
        if #sources == 0 then
            raise("charon-coding has no source under files/: the library would be built empty and "
                  .. "every dylib that links it would have no implementation behind it")
        end
        local objects = {}
        for _, source in ipairs(sources) do
            local object = path.absolute(path.join("objects", path.filename(source) .. ".o"))
            os.mkdir(path.directory(object))
            os.vrunv(toolchain:tool("cc"), table.join(target, FLAGS, {"-fobjc-arc", "-c", source, "-o", object}))
            table.insert(objects, object)
        end
        table.sort(objects)
        os.mkdir(package:installdir("lib"))
        os.vrunv("xcrun", table.join({"libtool", "-static", "-o", path.join(package:installdir("lib"), "libcharon-coding.a")}, objects))
        os.mkdir(package:installdir("include"))
        for _, header in ipairs(os.files(path.join(os.scriptdir(), "files", "*.h"))) do
            os.vcp(header, package:installdir("include"))
        end
    end)
