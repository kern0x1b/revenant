package("ggml")
    set_homepage("https://github.com/ggerganov/ggml")
    set_description("ggml 0.25.3, the tensor library with the graphs, the operators and the optimizer steps MLCompute's graphs and its optimizers are made of, unmodified, as a static library whose every symbol is hidden, for the image that links it in")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/ggerganov/ggml/archive/refs/tags/v$(version).tar.gz")
    add_versions("0.25.3", "cd9b92d5652f5e4abb41603bf59e269f8fec1b2d05ce22fded981064dd25fb89")
    add_links("ggml")

    add_configs("recipe", {description = "The digest of this recipe, so a changed flag is a different library.", default = hash.strhash128(hash.sha256(path.join(os.scriptdir(), "xmake.lua")) .. hash.sha256(path.join(os.scriptdir(), "ggml-libcxx.cpp"))), type = "string", readonly = true})

    -- Why this one, of the three the owner named, and what is taken from it:
    --
    --   - its tensors, its graph and its quantization are C, and a C engine reaches an old release's C
    --     runtime. Since the 0.2x series the operators and the graph's compute are C++ (ops.cpp, vec.cpp and
    --     the rest of the CPU backend's translation units) and the backend and the optimizer use the
    --     standard library's vector, map, string and mutex; so the archive holds objects of both, and the
    --     C++ runtime it needs is the band's (libc++ from iOS 5.0, cxx_runtime in modules/apple/backports.lua).
    --   - its graph is a list of nodes over named tensors, which is what MLCGraph builds and what
    --     MLCInferenceGraph executes.
    --   - ggml_opt's steps are SGD and AdamW over a parameter's moments, which is what MLCSGDOptimizer,
    --     MLCAdamOptimizer and MLCAdamWOptimizer are. There is no RMSProp step in the library, and
    --     MLCRMSPropOptimizer is not in the corpus of SDK 26.2 either, so nothing MLCompute has is missing.
    --   - the operators the layers need are there: convolution with its depthwise, strided, padded and
    --     transposed forms, pooling, group and root-mean-square normalization, the matrix product, the
    --     row gather, the padded write, the sort and the cumulative sum, and the activations. Three of
    --     MLCompute's layers have no operator of their own - the average pooling, the L2-norm pooling and
    --     the upsample - and are composed from these in MLCompute's own translation unit, and
    --     ggml_map_custom1 is there for the activations that take parameters, so none of them is written
    --     a second time.
    --
    -- No GGML_USE_* at all, and that is deliberate: every backend of the library is behind an #ifdef, so
    -- naming one with -D turns it on whatever value it is given - -DGGML_USE_OPENMP=0 included, which is
    -- how the first attempt of this recipe failed on a missing omp.h. With none named the library builds
    -- its plain CPU path, which is what an armv7 release has. GGML_CPU_GENERIC is the one define the CPU
    -- backend itself asks for when there is no native kernel of its own: without it arch-fallback.h takes
    -- an ARM target to have arm/quants.c and renames every generic kernel (ggml_vec_dot_*, quantize_row_q8_*)
    -- to <name>_generic, so the archive links with them undefined - the first gate that linked it said so.
    --
    -- Hidden, so the engine is never API of the image that links it in: libMLComputeBackports.dylib
    -- exports what MLCompute does and nothing a second copy of ggml in the process could bind to. The
    -- library is built without RTTI and without exceptions, which it does not use.
    local FLAGS = {"-Os", "-fvisibility=hidden", "-fno-exceptions", "-fno-rtti", "-D_GNU_SOURCE", "-Dggml_EXPORTS", "-DGGML_CPU_GENERIC",
        "-Dclock_gettime=charon_ggml_clock_gettime"}
    local CXXFLAGS = {"-std=c++17", "-fvisibility-inlines-hidden"}
    local SOURCES = {"ggml.c", "ggml-alloc.c", "ggml-quants.c", "ggml-cpu/ggml-cpu.c", "ggml-cpu/quants.c",
                     "ggml.cpp", "ggml-backend.cpp", "ggml-backend-meta.cpp", "ggml-threading.cpp", "ggml-opt.cpp",
                     "ggml-cpu/ops.cpp", "ggml-cpu/vec.cpp", "ggml-cpu/binary-ops.cpp", "ggml-cpu/unary-ops.cpp",
                     "ggml-cpu/traits.cpp", "ggml-cpu/ggml-cpu.cpp", "ggml-cpu/repack.cpp", "ggml-cpu/iqp.cpp"}
    local HEADERS = {"ggml.h", "ggml-alloc.h", "ggml-cpu.h", "ggml-opt.h", "ggml-backend.h"}

    on_install("iphoneos", function (package)
        local toolchain = assert(package:toolchains(), "ggml is built with the apple-ios toolchain")[1]
        toolchain:load()
        -- xmake flattens the archive, so the tree is the install directory itself with src/ and include/
        -- beside each other; the two files this recipe needs are named so that a layout which is not that
        -- one fails with a path rather than with a missing header further in.
        local root = os.curdir()
        assert(os.isdir(path.join(root, "src")) and os.isfile(path.join(root, "src", "ggml.c")) and
               os.isfile(path.join(root, "include", "ggml.h")), "ggml's source is not the expected tree under " .. root)

        -- ggml's CMake writes src/ggml-version.h from src/ggml-version.h.in; a charon package does not
        -- run CMake, so the two values the library's own sources ask for are written here: the version
        -- this recipe pins and the commit that tag carries.
        os.mkdir(path.join(root, "build"))
        io.writefile(path.join(root, "build", "ggml-version.h"),
                     string.format("#pragma once\n\n#define GGML_VERSION %q\n#define GGML_COMMIT  %q\n", "v" .. package:version(),
                                   "8dd76549e6e714c064348a1c89d90ed7c6306727"))

        local target = {"-target", package:arch() .. "-apple-ios", "-miphoneos-version-min=" .. toolchain:config("deployment"),
                        "-isysroot", toolchain:config("sdkdir"), "-I" .. path.join(root, "build"),
                        "-I" .. path.join(root, "include"), "-I" .. path.join(root, "include", "ggml"),
                        "-I" .. path.join(root, "src"), "-I" .. path.join(root, "src", "ggml-cpu")}

        -- Eighteen translation units and the runtime shim, and not the library's few: the CPU backend's own carry the operators
        -- (ops.cpp, vec.cpp, binary-ops.cpp, unary-ops.cpp), the kernels and the wrappers ggml.c only
        -- declares - ggml_sigmoid, ggml_new_f32, ggml_set_f32 and the graph compute - and ggml-backend.cpp the
        -- tensor writes and the buffer usage the graph allocator calls; without them the archive links with
        -- undefined symbols the first time anything calls one (143 of them, at MLCompute's link). The other
        -- backends and the examples are their own targets and are not needed by an image that links this in.
        local objects = {}
        for _, source in ipairs(SOURCES) do
            local object = path.absolute(path.join("objects", source:gsub("[/.]", "_") .. ".o"))
            os.mkdir(path.directory(object))
            local cxx = source:endswith(".cpp")
            os.vrunv(toolchain:tool(cxx and "cxx" or "cc"), table.join(target, FLAGS, cxx and CXXFLAGS or {}, {"-c", path.join(root, "src", source), "-o", object}))
            table.insert(objects, object)
        end
        -- The C++ runtime entry points the units above call and iOS 4.3's libstdc++ does not export
        -- (ggml-libcxx.cpp says which and why), defined in the archive. Every symbol of that object is
        -- made private after it is compiled: some of what it defines is declared with default visibility
        -- by the standard library's own headers, which an -fvisibility flag does not override, and none
        -- of it may be API of the image that links this in.
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
