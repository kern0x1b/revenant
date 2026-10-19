package("quicly")
    set_homepage("https://github.com/h2o/quicly")
    set_description("quicly (h2o), QUIC over picotls, as a static archive for the port: the release has no TLS 1.3 and no QUIC of its own, so a connection of QUIC parameters gets its transport from here")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/h2o/quicly.git")
    add_versions("2026.09.25", "0a163c0e45e728a33f83261d8cf957ac0006935a")

    add_deps("revenant@apple-compat", {alias = "apple-compat"})
    add_deps("revenant@picotls 2026.09.24", {alias = "picotls"})
    add_links("picotls-minicrypto", "picotls-core")

    add_configs("recipe", {description = "The digest of this recipe, so a changed flag is a different archive.", default = hash.strhash128(hash.sha256(path.join(os.scriptdir(), "xmake.lua"))), type = "string", readonly = true})

    local SOURCES = {
        "lib/frame.c", "lib/cc-cubic.c", "lib/cc-pico.c", "lib/defaults.c", "lib/local_cid.c",
        "lib/loss.c", "lib/quicly.c", "lib/ranges.c", "lib/rate.c", "lib/recvstate.c",
        "lib/remote_cid.c", "lib/sendstate.c", "lib/sentmap.c", "lib/streambuf.c"
    }
    local SUBMODULES = {["deps/klib"] = true, ["deps/picotest"] = true}

    on_install("iphoneos", function (package)
        for name in pairs(SUBMODULES) do
            os.vrunv("git", {"submodule", "update", "--init", "--depth", "1", name})
            assert(os.isdir(path.join(os.curdir(), name)), "the submodule " .. name .. " is not there after git checked it out")
        end

        local toolchain = assert(package:toolchains(), "quicly is built with the apple-ios toolchain")[1]
        toolchain:load()
        local sdk = assert(toolchain:config("sdkdir"), "the apple-ios toolchain names no SDK")
        local minimum = assert(toolchain:config("deployment"), "the apple-ios toolchain names no minimum release")
        local target = {"-target", package:arch() .. "-apple-ios", "-miphoneos-version-min=" .. minimum, "-isysroot", sdk}
        local flags = table.join({"-std=c99", "-Os", "-fvisibility=hidden", "-w"},
                                 toolchain:config("emulated_tls") and {"-femulated-tls"} or {})
        local include_flags = table.join({"-I" .. package:dep("picotls"):installdir("include"),
                                          "-I" .. path.join(os.curdir(), "deps", "klib"),
                                          "-I" .. path.join(os.curdir(), "deps", "picotest"),
                                          "-I" .. path.join(os.curdir(), "include"),
                                          "-I" .. os.curdir()})

        local tracer = path.join(os.curdir(), "quicly-tracer.h")
        os.vrunv("perl", {path.join(os.curdir(), "misc", "probe2trace.pl"), "-a", "tracer"},
                 {stdout = tracer, inputs = path.join(os.curdir(), "quicly-probes.d")})
        assert(os.isfile(tracer), "quicly-tracer.h was not written")

        local objects = path.join(package:installdir("lib"), "obj")
        os.mkdir(objects)
        local built = {}
        for _, source in ipairs(SOURCES) do
            local object = path.join(objects, (source:gsub("[/\\]", "_") .. ".o"))
            os.vrunv(toolchain:tool("cc"), table.join(target, flags, include_flags,
                                                     {"-c", path.join(os.curdir(), source), "-o", object}))
            table.insert(built, object)
        end
        os.vrunv("xcrun", table.join({"libtool", "-static", "-o", path.join(package:installdir("lib"), "libquicly.a")}, built))

        local include = package:installdir("include")
        for _, header in ipairs(os.files(path.join(os.curdir(), "include", "**", "*.h"))) do
            os.cp(header, path.join(include, path.directory(header)) .. "/")
        end
        os.cp(tracer, path.join(include, "quicly", "quicly-tracer.h"))
        for _, notice in ipairs({"LICENSE", "README.md"}) do
            if os.isfile(path.join(os.curdir(), notice)) then
                os.vcp(notice, package:installdir("licenses"))
            end
        end
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libquicly.a")), "libquicly.a is not installed")
        for _, header in ipairs({"quicly.h", "quicly/quicly.h", "quicly/quicly-tracer.h"}) do
            assert(os.isfile(path.join(package:installdir("include"), header)), header .. " is not installed")
        end
    end)
