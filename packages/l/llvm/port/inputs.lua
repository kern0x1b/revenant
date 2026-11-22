llvm_build_inputs = {
    procedure = 1,
    url = "https://github.com/llvm/llvm-project.git",
    version = "23.1.3",
    commit = "0d261d1ca552c95a8f007e061c787ac7132fbcbc",
    tag_prefix = "llvmorg-",
    sparse = {"/*", "!/*/", "/cmake/", "/third-party/", "/libc/", "!/libc/test/",
              "/llvm/", "!/llvm/test/", "!/llvm/unittests/", "!/llvm/docs/",
              "/clang/", "!/clang/test/", "!/clang/unittests/", "!/clang/docs/", "!/clang/www/",
              "/compiler-rt/", "!/compiler-rt/test/"},
    patches = {"clang-emulated-tls-without-dyld.patch", "builtins-leave-emutls-to-the-runtime.patch", "clang-atomic-libcalls-from-the-runtime.patch",
               "configure-and-build-without-python.patch", "llvm-sjlj-demote-phis-in-block-order.patch"},
    apply = {"apply", "{patch}", "-p2"},
    host_linker = {program = "xcrun", arguments = {"-f", "ld"}},
    cmake = {
        build = {"--build", "{build}"},
        target = {"--target"},
        install = {"--install", "{build}"}
    },
    compiler = {
        configure = {"-G", "Ninja", "-S", "llvm", "-B", "{build}", "-DCMAKE_BUILD_TYPE=Release",
                     "-DCMAKE_INSTALL_PREFIX={install}", "-DCMAKE_OSX_ARCHITECTURES={arch}",
                     "-DLLVM_ENABLE_PROJECTS=clang", "-DLLVM_TARGETS_TO_BUILD=ARM;AArch64",
                     "-DLLVM_INCLUDE_TESTS=OFF", "-DLLVM_INCLUDE_UTILS=OFF", "-DLLVM_INCLUDE_BENCHMARKS=OFF",
                     "-DLLVM_INCLUDE_EXAMPLES=OFF", "-DLLVM_INCLUDE_DOCS=OFF", "-DCLANG_INCLUDE_TESTS=OFF", "-DCLANG_INCLUDE_DOCS=OFF",
                     "-DLLVM_ENABLE_ASSERTIONS=OFF", "-DLLVM_ENABLE_ZLIB=OFF", "-DLLVM_ENABLE_ZSTD=OFF",
                     "-DLLVM_ENABLE_LIBXML2=OFF", "-DLLVM_ENABLE_TERMINFO=OFF",
                     "-DCLANG_ENABLE_STATIC_ANALYZER=OFF", "-DCLANG_ENABLE_OBJC_REWRITER=OFF",
                     "-DCMAKE_DISABLE_FIND_PACKAGE_Python3=ON", "-DLLVM_PARALLEL_LINK_JOBS={link_jobs}"},
        targets = {"install-clang", "install-clang-resource-headers", "install-LTO", "install-llvm-libtool-darwin"},
        libraries = {"-DLLVM_BUILD_LLVM_DYLIB=ON", "-DLLVM_LINK_LLVM_DYLIB=ON",
                     "-DLLVM_DISTRIBUTION_COMPONENTS=LLVM;clang-cpp;llvm-headers;clang-headers;llvm-config;clang;clang-resource-headers;llvm-extract;llvm-split;llvm-dis;llvm-nm;llvm-objdump;LTO;llvm-libtool-darwin"},
        libraries_targets = {"install-distribution"}
    },
    builtins = {
        configure = {"-G", "Ninja", "-S", "compiler-rt", "-B", "{build}", "-DCMAKE_BUILD_TYPE=Release",
                     "-DCMAKE_EXE_LINKER_FLAGS=-fuse-ld={host_linker}",
                     "-DCMAKE_C_COMPILER={clang}", "-DCMAKE_CXX_COMPILER={clang}++", "-DCMAKE_ASM_COMPILER={clang}",
                     "-DLLVM_CMAKE_DIR={llvm_cmake_dir}",
                     "-DCOMPILER_RT_INSTALL_PATH={resource_install}",
                     "-DCOMPILER_RT_BUILD_BUILTINS=ON", "-DCOMPILER_RT_BUILD_CRT=OFF", "-DCOMPILER_RT_BUILD_SANITIZERS=OFF",
                     "-DCOMPILER_RT_BUILD_XRAY=OFF", "-DCOMPILER_RT_BUILD_LIBFUZZER=OFF", "-DCOMPILER_RT_BUILD_PROFILE=OFF",
                     "-DCOMPILER_RT_BUILD_MEMPROF=OFF", "-DCOMPILER_RT_BUILD_ORC=OFF", "-DCOMPILER_RT_BUILD_CTX_PROFILE=OFF",
                     "-DCOMPILER_RT_INCLUDE_TESTS=OFF", "-DCMAKE_DISABLE_FIND_PACKAGE_Python3=ON",
                     "-DCOMPILER_RT_ENABLE_IOS=ON", "-DCOMPILER_RT_ENABLE_WATCHOS=OFF", "-DCOMPILER_RT_ENABLE_TVOS=OFF",
                     "-DCOMPILER_RT_ENABLE_XROS=OFF",
                     "-DDARWIN_iphoneos_CACHED_SYSROOT={sysroot}",
                     "-DDARWIN_iphonesimulator_OVERRIDE_SDK_VERSION={sdk_version}",
                     "-DDARWIN_ios_BUILTIN_ARCHS=armv7;armv7s;arm64", "-DDARWIN_osx_BUILTIN_ARCHS={arch}"}
    }
}

llvm_recipe_aliases = {
    ["04f818966f1d914741fa2f3adff234a0"] = "4c6acdde5d0e3e4b5da9051c33454e22"
}

local function ordered(a, b)
    if type(a) == type(b) then
        return a < b
    end
    return type(a) == "number"
end

local function leaves(value, name, lines)
    if type(value) == "table" then
        local keys = {}
        for key in pairs(value) do
            table.insert(keys, key)
        end
        table.sort(keys, ordered)
        for _, key in ipairs(keys) do
            leaves(value[key], name .. "." .. tostring(key), lines)
        end
    else
        table.insert(lines, name .. "=" .. type(value) .. ":" .. tostring(value))
    end
    return lines
end

function llvm_inputs()
    return llvm_build_inputs
end

function llvm_aliases()
    return llvm_recipe_aliases
end

function llvm_recipe_digest(folder, inputs)
    inputs = inputs or llvm_build_inputs
    local lines = leaves(inputs, "inputs", {})
    for _, patch in ipairs(inputs.patches) do
        table.insert(lines, "patch " .. patch .. "=" .. hash.sha256(path.join(folder, "patches", patch)))
    end
    return hash.strhash128(table.concat(lines, "\n"))
end

function llvm_recipe_key(folder, inputs, aliases)
    local digest = llvm_recipe_digest(folder, inputs)
    return (aliases or llvm_recipe_aliases)[digest] or digest
end
