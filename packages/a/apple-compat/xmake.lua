package("apple-compat")
    set_homepage("https://github.com/kern0x1b/charon")
    set_description("What a current library calls and an old Apple system does not have, provided as hidden definitions linked into the image that calls them")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    local digests = {}
    local sources = table.join({path.join(os.scriptdir(), "xmake.lua")},
                               os.files(path.join(os.scriptdir(), "src", "*.c")), os.files(path.join(os.scriptdir(), "src", "*.h")),
                               os.files(path.join(os.scriptdir(), "include", "charon", "*.h")))
    table.sort(sources)
    for _, file in ipairs(sources) do
        table.insert(digests, path.filename(file) .. "=" .. hash.sha256(file))
    end
    add_configs("sources", {description = "The digest of this recipe and the shims it compiles, so a changed shim or recipe is a different package.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    on_load("iphoneos", function (package)
        import("core.base.semver")
        local compat = import("apple.compat", {rootdir = path.join(package:scriptdir(), "..", "..", "..", "modules"), anonymous = true})
        local toolchain = assert(package:toolchains(), "apple-compat is built with the apple-ios toolchain")[1]
        toolchain:load()
        local symbols, process_wide = {}, {}
        local shared = compat.process_wide()
        for symbol, release in pairs(compat.provided("iOS")) do
            if semver.compare(toolchain:config("deployment"), release) < 0 then
                table.insert(shared[symbol] and process_wide or symbols, symbol)
            end
        end
        table.sort(symbols)
        table.sort(process_wide)
        package:data_set("provided", symbols)
        package:data_set("process_wide", process_wide)
        if #symbols > 0 then
            package:add("links", "apple-compat")
        end
    end)

    on_install("iphoneos", function (package)
        local toolchain = package:toolchains()[1]
        toolchain:load()
        local triple = package:arch() .. "-apple-ios"
        local objects = {}
        for _, symbol in ipairs(package:data("provided")) do
            local object = path.absolute(symbol .. ".o")
            -- -fno-builtin: at -Os LLVM merges a sin and a cos of one argument into a call to __sincos_stret, which for a
            -- shim of __sincos_stret is a call to itself. The shim's sin and cos are the library's, called as two calls.
            os.vrunv(toolchain:tool("cc"), {"-target", triple, "-miphoneos-version-min=" .. toolchain:config("deployment"), "-isysroot", toolchain:config("sdkdir"), "-Os",
                               "-fno-builtin", "-fvisibility=hidden", "-c", path.join(package:scriptdir(), "src", symbol .. ".c"), "-o", object})
            table.insert(objects, object)
            local header = path.join(package:scriptdir(), "include", "charon", symbol .. ".h")
            if os.isfile(header) then
                os.vcp(header, path.join(package:installdir("include"), "charon") .. "/")
            end
        end
        if #objects > 0 then
            os.vrunv("xcrun", table.join({"libtool", "-static", "-o", path.join(package:installdir("lib"), "libapple-compat.a")}, objects))
        end
        -- The same declarations as one module, so that Swift reaches a shim: a forced include reaches the C file being
        -- compiled and not the Swift one, and a declaration has to be in a module to be seen at all. The modulemap names
        -- the headers it has, which are the ones this release needed -- the module is written from what was installed,
        -- so a shim a newer release does not need is not in it, and no caller can reach one it does not have.
        local module = path.join(package:installdir("include"), "CharonCompat")
        os.mkdir(module)
        local lines = {"// Written by charon@apple-compat: the shims this release needs, as one module a Swift file can import."}
        for _, symbol in ipairs(package:data("provided")) do
            if os.isfile(path.join(package:installdir("include"), "charon", symbol .. ".h")) then
                table.insert(lines, "#include <charon/" .. symbol .. ".h>")
            end
        end
        io.writefile(path.join(module, "shims.h"), table.concat(lines, "\n") .. "\n")
        io.writefile(path.join(module, "module.modulemap"), "module CharonCompat {\n    header \"shims.h\"\n    export *\n}\n")
        local process_wide = package:data("process_wide")
        if #process_wide > 0 then
            local folder = path.join(package:installdir("share"), "apple-compat", "process-wide")
            os.vcp(path.join(package:scriptdir(), "src", "*.h"), folder .. "/")
            for _, symbol in ipairs(process_wide) do
                os.vcp(path.join(package:scriptdir(), "src", symbol .. ".c"), folder .. "/")
            end
        end
        os.vcp(path.join(package:scriptdir(), "..", "..", "..", "LICENSE"), package:installdir("licenses"))
    end)

    on_test(function (package)
        local symbols = package:data("provided") or {}
        if #symbols > 0 then
            assert(os.isfile(path.join(package:installdir("lib"), "libapple-compat.a")))
        end
        for _, symbol in ipairs(package:data("process_wide") or {}) do
            assert(os.isfile(path.join(package:installdir("share"), "apple-compat", "process-wide", symbol .. ".c")))
        end
    end)
