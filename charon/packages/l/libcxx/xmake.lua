package("libcxx")
    set_homepage("https://libcxx.llvm.org")
    set_description("The C++ runtime an old iOS does not ship, as the shared libraries an application carries in its bundle")
    set_license("Apache-2.0 WITH LLVM-exception")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/llvm/llvm-project.git")
    add_versions("23.1.1", "6dfe1677ab8dffbc6ec13d53a1e0215d75147689")
    add_deps("charon@apple-compat", {alias = "apple-compat"})
    add_deps("cmake", "ninja", {kind = "binary"})

    -- The Lua this is made of enters the build hash as the digest in digest.lua, which leaves comments out
    -- (modules/digest.lua): rewording one is not a new runtime.
    includes(path.join(os.scriptdir(), "digest.lua"))
    local digests = {"sources=" .. libcxx_sources_digest}
    for _, patch in ipairs(os.files(path.join(os.scriptdir(), "patches", "*.patch"))) do
        table.insert(digests, path.filename(patch) .. "=" .. hash.sha256(patch))
    end
    -- What apple-compat holds is linked into the libraries built here (and libc++abi exports its process-wide half), so a
    -- changed shim is a different runtime: without this a build finds the one it already has and keeps the old shims.
    local folder = path.join(os.scriptdir(), "..", "..", "a", "apple-compat")
    for _, shim in ipairs(table.join(os.files(path.join(folder, "src", "*.c")), os.files(path.join(folder, "src", "*.h")),
                                     os.files(path.join(folder, "include", "charon", "*.h")))) do
        table.insert(digests, "apple-compat/" .. path.filename(shim) .. "=" .. hash.sha256(shim))
    end
    table.sort(digests)
    add_configs("recipe", {description = "The digest of this recipe and the patches it applies, so a changed flag or patch is a different runtime.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    add_configs("shared", {description = "The runtime is always the shared pair an application bundles.", default = true, type = "boolean", readonly = true})
    add_configs("operators", {description = "operator new and delete are ordinary definitions in libc++abi, so no image binds them weakly and dyld never coalesces them with another C++ runtime in the process.", default = "not-weak", type = "string", readonly = true})

    -- The pair as a package of its own, /usr/lib/charon/org.charon.libcxx-<build>, which what links against it depends on
    -- instead of carrying it: a process has one copy of libc++abi, so the programs and the Swift runtime that share it
    -- name this one.
    add_configs("packaged", {description = "Install the libraries under absolute install names and leave what a Debian package holding them is written from, which what is linked against them depends on instead of carrying them: the program that depends on it writes and signs that package, so this package needs no host tool.", default = false, type = "boolean"})

    add_includedirs("include/c++/v1")
    add_links("c++", "c++abi")
    add_defines("_LIBCPP_DISABLE_AVAILABILITY")
    add_cxxflags("-nostdinc++")
    add_mxxflags("-nostdinc++")
    add_ldflags("-nostdlib++")
    add_shflags("-nostdlib++")

    on_download(function (package, opt)
        local checkout = import("checkout", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "modules"), anonymous = true})
        checkout.pinned(opt.sourcedir, {{url = opt.url, tag = "llvmorg-" .. package:version_str(),
                                         commit = package:revision(opt.url_alias) or package:commit(),
                                         sparse = {"/*", "!/*/", "/libcxx/", "/libcxxabi/", "/libunwind/", "/runtimes/", "/cmake/",
                                                   "/third-party/", "/llvm/cmake/", "/llvm/utils/llvm-lit/", "/libc/",
                                                   "/compiler-rt/lib/builtins/"}}})
    end)

    on_install("iphoneos", function (package)
        import("core.base.semver")
        local modules = path.join(package:scriptdir(), "..", "..", "..", "modules")
        local cmake = import("apple.cmake", {rootdir = modules, anonymous = true})
        local macho = import("apple.macho", {rootdir = modules, anonymous = true})
        for _, patch in ipairs({"utimensat-told-no.patch", "reexport-when-dyld-can.patch", "one-emulated-tls-runtime.patch", "one-atomic-runtime.patch", "process-wide-compat.patch"}) do
            os.vrunv("git", {"apply", path.join(package:scriptdir(), "patches", patch), "-p2"})
        end
        local compat = package:dep("apple-compat")
        local cxxflags = {"-mllvm", "-hot-cold-split=false", "-D_LIBCPP_NO_UTIMENSAT"}
        local shflags = {"-Wl,-force_symbols_not_weak_list," .. path.join(package:scriptdir(), "operators-not-weak.exp")}
        for _, symbol in ipairs(compat:data("provided") or {}) do
            local header = path.join(compat:installdir("include"), "charon", symbol .. ".h")
            if os.isfile(header) then
                table.insert(cxxflags, "-include" .. header)
            end
        end
        if #(compat:data("provided") or {}) > 0 then
            table.join2(shflags, {"-L" .. compat:installdir("lib"), "-Wl,-hidden-lapple-compat"})
        end
        local process_wide = compat:data("process_wide") or {}
        local process_sources, process_exports = {}, path.absolute("process-wide.exp")
        for _, symbol in ipairs(process_wide) do
            table.insert(process_sources, path.join(compat:installdir("share"), "apple-compat", "process-wide", symbol .. ".c"))
        end
        io.writefile(process_exports, table.concat(table.imap(process_wide, function (_, symbol) return "_" .. symbol end), "\n") .. "\n")
        local deployment = cmake.toolchain(package):config("deployment")
        local emulated_tls = cmake.toolchain(package):config("emulated_tls") and true or false
        local atomic_libcalls = cmake.toolchain(package):config("atomic_libcalls") and true or false
        cmake.install(package, {
            "-DLIBCXXABI_ENABLE_EMULATED_TLS=" .. (emulated_tls and "ON" or "OFF"),
            "-DLIBCXXABI_ENABLE_ATOMIC_LIBCALLS=" .. (atomic_libcalls and "ON" or "OFF"),
            "-DLIBCXXABI_PROCESS_WIDE_SOURCES=" .. table.concat(process_sources, ";"),
            "-DLIBCXXABI_PROCESS_WIDE_EXPORTS=" .. process_exports,
            "-DLLVM_ENABLE_RUNTIMES=libcxx;libcxxabi",
            "-DLIBCXXABI_REEXPORT_FROM_LIBCXX=" .. (semver.compare(deployment, "4.2") < 0 and "OFF" or "ON"),
            "-DLIBCXX_ENABLE_SHARED=ON", "-DLIBCXXABI_ENABLE_SHARED=ON",
            "-DLIBCXX_ENABLE_STATIC=OFF", "-DLIBCXXABI_ENABLE_STATIC=OFF",
            "-DLIBCXX_CXX_ABI=libcxxabi", "-DLIBCXXABI_USE_LLVM_UNWINDER=OFF",
            "-DLIBCXX_INCLUDE_BENCHMARKS=OFF", "-DLIBCXX_INCLUDE_TESTS=OFF", "-DLIBCXXABI_INCLUDE_TESTS=OFF"
        }, {sourcedir = "runtimes", system = "Darwin", cflags = {"-mllvm", "-hot-cold-split=false"}, cxxflags = cxxflags, shflags = shflags})
        for _, library in ipairs({"libc++.1.0.dylib", "libc++abi.1.0.dylib"}) do
            local imported = {}
            for name in os.iorunv("xcrun", {"nm", "-u", path.join(package:installdir("lib"), library)}):gmatch("%S+") do
                if name:startswith("_") then
                    imported[name:sub(2)] = true
                end
            end
            local leaked = {}
            for _, symbol in ipairs(compat:data("provided") or {}) do
                if imported[symbol] or imported["charon_" .. symbol] then
                    table.insert(leaked, symbol)
                end
            end
            if #leaked > 0 then
                raise("%s still imports %s from the system, which iOS %s does not have; apple-compat was not linked into it", library, table.concat(leaked, ", "), cmake.toolchain(package):config("deployment"))
            end
        end
        local exported = os.iorunv("xcrun", {"nm", "-gU", path.join(package:installdir("lib"), "libc++abi.1.0.dylib")})
        if emulated_tls then
            for _, symbol in ipairs({"___emutls_get_address", "___cxa_thread_atexit"}) do
                if not exported:find(" T " .. symbol .. "\n", 1, true) then
                    raise("libc++abi.1.0.dylib does not export %s, and code compiled with -femulated-tls for iOS %s calls it", symbol, deployment)
                end
            end
        end
        for _, symbol in ipairs({"___atomic_load", "___atomic_store", "___atomic_exchange", "___atomic_compare_exchange", "___atomic_is_lock_free"}) do
            local found = exported:find(" T " .. symbol .. "\n", 1, true)
            if atomic_libcalls and not found then
                raise("libc++abi.1.0.dylib does not export %s, and code compiled for iOS %s calls it for an atomic the processor cannot update in one instruction", symbol, deployment)
            elseif not atomic_libcalls and found then
                raise("libc++abi.1.0.dylib exports %s, which libSystem has from iOS 7.0, so code built for iOS %s would bind a second copy with locks of its own", symbol, deployment)
            end
        end
        local reexported = os.iorunv("xcrun", {"nm", "-gm", path.join(package:installdir("lib"), "libc++.1.0.dylib")})
        local wanted = {}
        for _, name in ipairs(process_wide) do
            wanted[name] = true
        end
        local compat_module = import("apple.compat", {rootdir = modules, anonymous = true})
        for _, name in ipairs(table.orderkeys(compat_module.process_wide())) do
            local found = exported:find(" T _" .. name .. "\n", 1, true)
            if wanted[name] and not found then
                raise("libc++abi.1.0.dylib does not export %s, which iOS %s lacks and every image of a process must reach in one copy", name, deployment)
            elseif not wanted[name] and found then
                raise("libc++abi.1.0.dylib exports %s, which the system has for iOS %s, so an image would bind a second copy beside the system's", name, deployment)
            end
            if wanted[name] and semver.compare(deployment, "4.2") >= 0 and not reexported:find("(indirect) external _" .. name .. " ", 1, true) then
                raise("libc++.1.0.dylib does not re-export %s from libc++abi, so a client that links libc++ alone binds nothing", name)
            end
        end
        local function is_operator(name)
            return name:find("^__Zn[wa]") ~= nil or name:find("^__Zd[la]") ~= nil
        end
        local library = package:installdir("lib")
        local defined = 0
        for line in os.iorunv("xcrun", {"nm", "-gmU", path.join(library, "libc++abi.1.0.dylib")}):gmatch("[^\n]+") do
            local name = line:match("(%S+)$")
            if is_operator(name) then
                defined = defined + 1
                if line:find("weak external", 1, true) then
                    raise("libc++abi.1.0.dylib still defines %s weakly", name)
                end
            end
        end
        if defined == 0 then
            raise("libc++abi.1.0.dylib defines no operator new or delete")
        end
        for _, runtime_library in ipairs({"libc++.1.0.dylib", "libc++abi.1.0.dylib"}) do
            local data = macho.read(path.join(library, runtime_library))
            for _, binding in ipairs(macho.weak_bindings(data, macho.images(data)[1])) do
                if is_operator(binding.name) then
                    raise("%s %s %s, and dyld would coalesce it with another C++ runtime in the process", runtime_library,
                          binding.overrides and "overrides" or "binds weakly", binding.name)
                end
            end
        end
        local chosen = cmake.toolchain(package)
        local probe = path.absolute(path.join("operators_probe", "probe.cpp"))
        io.writefile(probe, "int *kept;\nint *kept_array;\nint main(int argc, char **) { kept = new int(argc); delete kept; kept_array = new int[argc]; delete[] kept_array; return 0; }\n")
        local client = path.join(path.directory(probe), "probe")
        os.vrunv(chosen:tool("cxx"), table.join(table.wrap(chosen:get("cxflags")), table.wrap(chosen:get("ldflags")),
                                                {"-nostdinc++", "-isystem", package:installdir("include", "c++", "v1"), "-nostdlib++",
                                                 "-L" .. library, "-lc++", "-lc++abi", probe, "-o", client}))
        local imported = os.iorunv("xcrun", {"nm", "-u", client})
        for _, symbol in ipairs({"__Znwm", "__ZdlPv", "__Znam", "__ZdaPv"}) do
            if not imported:find(symbol .. "\n", 1, true) then
                raise("the probe client does not import %s, so it says nothing about how operator new and delete bind", symbol)
            end
        end
        local probed = macho.read(client)
        local probed_image = macho.images(probed)[1]
        for _, binding in ipairs(macho.weak_bindings(probed, probed_image)) do
            if is_operator(binding.name) then
                raise("a client linked against this runtime still binds %s weakly", binding.name)
            end
        end
        if probed_image.flags & 0x10000 ~= 0 then
            raise("a client that only calls operator new and delete is still marked MH_BINDS_TO_WEAK")
        end
        os.cp("libcxx/LICENSE.TXT", package:installdir("licenses") .. "/")
        if package:config("packaged") then
            local shared = import("apple.shared_runtime", {rootdir = modules, anonymous = true})
            local name = shared.package_name("libcxx", package:buildhash())
            -- What links against these libraries reads their install names, so they are given before the package is written
            -- and the package holds copies of them under the names the libraries are loaded by.
            local held = {{source = path.join(library, "libc++.1.0.dylib"), leaf = "libc++.1.dylib"},
                          {source = path.join(library, "libc++abi.1.0.dylib"), leaf = "libc++abi.1.dylib"}}
            local identities = {}
            for _, entry in ipairs(held) do
                identities[entry.source] = shared.folder_of(name) .. "/" .. entry.leaf
            end
            import("apple.bundle", {rootdir = modules, anonymous = true}).retarget(table.keys(identities), identities,
                                                                                    {home = shared.folder_of(name) .. "/"})
            shared.stage({packages = {{name = name, version = shared.package_version(package:buildhash()),
                                       title = "C++ runtime " .. package:buildhash():sub(1, 8),
                                       description = "libc++ and libc++abi of one build of Charon's charon@libcxx,",
                                       libraries = {}, extra = held}},
                          root = path.join(package:installdir("share"), "root"),
                          metadata = path.join(package:installdir("share"), "shared-packages"), strip = {"-x"}})
            package:setenv("CHARON_SHARED_PACKAGE", name)
        end
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libc++.1.0.dylib")))
        assert(os.isfile(path.join(package:installdir("include", "c++", "v1"), "vector")))
        if package:config("packaged") then
            local shared = import("apple.shared_runtime", {rootdir = path.join(package:scriptdir(), "..", "..", "..", "modules"), anonymous = true})
            local name = shared.package_name("libcxx", package:buildhash())
            assert(os.isfile(path.join(package:installdir("share"), "shared-packages", name .. ".json")), "the packaged libc++ left no description of its package")
            local identity = os.iorunv("xcrun", {"otool", "-D", path.join(package:installdir("lib"), "libc++.1.0.dylib")})
            assert(identity:find(shared.folder_of(name) .. "/libc++.1.dylib", 1, true), "libc++ is not identified by the package's folder: " .. identity)
        end
    end)
