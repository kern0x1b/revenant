package("ggml")
    set_homepage("https://github.com/ggerganov/ggml")
    set_description("ggml 0.25.3, the tensor library with the graphs, the operators and the optimizer steps MLCompute's graphs and its optimizers are made of, unmodified, as a static library whose every symbol is hidden, for the image that links it in")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/ggerganov/ggml/archive/refs/tags/v$(version).tar.gz")
    add_versions("0.25.3", "cd9b92d5652f5e4abb41603bf59e269f8fec1b2d05ce22fded981064dd25fb89")
    add_links("ggml")

    add_configs("recipe", {description = "The digest of this recipe, so a changed flag is a different library.", default = hash.strhash128(hash.sha256(path.join(os.scriptdir(), "xmake.lua")) .. hash.sha256(path.join(os.scriptdir(), "ggml-libcxx.cpp"))), type = "string", readonly = true})

    local FLAGS = {"-Os", "-fvisibility=hidden", "-fno-exceptions", "-fno-rtti", "-D_GNU_SOURCE", "-Dggml_EXPORTS", "-DGGML_CPU_GENERIC",
        "-Dclock_gettime=revenant_ggml_clock_gettime"}
    local CXXFLAGS = {"-std=c++17", "-fvisibility-inlines-hidden"}
    local SOURCES = {"ggml.c", "ggml-alloc.c", "ggml-quants.c", "ggml-cpu/ggml-cpu.c", "ggml-cpu/quants.c",
                     "ggml.cpp", "ggml-backend.cpp", "ggml-backend-meta.cpp", "ggml-threading.cpp", "ggml-opt.cpp",
                     "ggml-cpu/ops.cpp", "ggml-cpu/vec.cpp", "ggml-cpu/binary-ops.cpp", "ggml-cpu/unary-ops.cpp",
                     "ggml-cpu/traits.cpp", "ggml-cpu/ggml-cpu.cpp", "ggml-cpu/repack.cpp", "ggml-cpu/iqp.cpp"}
    local HEADERS = {"ggml.h", "ggml-alloc.h", "ggml-cpu.h", "ggml-opt.h", "ggml-backend.h"}

    on_install("iphoneos", function (package)
        local toolchain = assert(package:toolchains(), "ggml is built with the apple-ios toolchain")[1]
        toolchain:load()
        local root = os.curdir()
        assert(os.isdir(path.join(root, "src")) and os.isfile(path.join(root, "src", "ggml.c")) and
               os.isfile(path.join(root, "include", "ggml.h")), "ggml's source is not the expected tree under " .. root)

        os.mkdir(path.join(root, "build"))
        io.writefile(path.join(root, "build", "ggml-version.h"),
                     string.format("#pragma once\n\n#define GGML_VERSION %q\n#define GGML_COMMIT  %q\n", "v" .. package:version(),
                                   "8dd76549e6e714c064348a1c89d90ed7c6306727"))

        local target = {"-target", package:arch() .. "-apple-ios", "-miphoneos-version-min=" .. toolchain:config("deployment"),
                        "-isysroot", toolchain:config("sdkdir"), "-I" .. path.join(root, "build"),
                        "-I" .. path.join(root, "include"), "-I" .. path.join(root, "include", "ggml"),
                        "-I" .. path.join(root, "src"), "-I" .. path.join(root, "src", "ggml-cpu")}

        local objects = {}
        for _, source in ipairs(SOURCES) do
            local object = path.absolute(path.join("objects", source:gsub("[/.]", "_") .. ".o"))
            os.mkdir(path.directory(object))
            local cxx = source:endswith(".cpp")
            os.vrunv(toolchain:tool(cxx and "cxx" or "cc"), table.join(target, FLAGS, cxx and CXXFLAGS or {}, {"-c", path.join(root, "src", source), "-o", object}))
            table.insert(objects, object)
        end
        do
            local shim = path.absolute(path.join("objects", "ggml-libcxx.o"))
            local shim_public = path.absolute(path.join("objects", "ggml-libcxx-public.o"))
            os.vrunv(toolchain:tool("cxx"), table.join(target, FLAGS, CXXFLAGS, {"-c", path.join(package:scriptdir(), "ggml-libcxx.cpp"), "-o", shim_public}))
            os.vrunv("xcrun", {"ld", "-r", "-arch", package:arch(), "-platform_version", "ios", toolchain:config("deployment"), "16.4",
                               "-keep_private_externs", "-unexported_symbol", "*", shim_public, "-o", shim})
            table.insert(objects, shim)
        end
        table.sort(objects)
        os.vrunv("xcrun", table.join({"libtool", "-static", "-o", path.join(package:installdir("lib"), "libggml.a")}, objects))
        local include = path.join(package:installdir("include"), "ggml") .. "/"
        local licences = path.join(package:installdir("licenses"), "ggml") .. "/"
        os.mkdir(path.directory(include))
        os.mkdir(path.directory(licences))
        for _, header in ipairs(HEADERS) do
            if os.isfile(path.join(root, "include", header)) then
                os.vcp(path.join(root, "include", header), include)
            end
        end
        os.vcp(path.join(root, "build", "ggml-version.h"), include)
        os.vcp(path.join(root, "LICENSE"), licences)
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libggml.a")))
        assert(os.isfile(path.join(package:installdir("include"), "ggml", "ggml-cpu.h")))
        assert(os.isfile(path.join(package:installdir("include"), "ggml", "ggml.h")))
        assert(os.isfile(path.join(package:installdir("include"), "ggml", "ggml-opt.h")))
    end)
