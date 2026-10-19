import("lib.detect.find_tool")

local processors = {armv6 = "arm", armv7 = "arm", armv7s = "arm", arm64 = "aarch64"}

local function quoted(values)
    return table.concat(values, " "):gsub("\\", "\\\\"):gsub("\"", "\\\"")
end

function toolchain(package)
    local found = assert(package:toolchains(), package:name() .. " is built for apple-ios without the apple-ios toolchain")[1]
    found:load()
    return found
end

function toolchain_file(package, opt)
    opt = opt or {}
    local chosen = toolchain(package)
    local sdk = chosen:config("sdkdir")
    local minimum = chosen:config("deployment")
    local thread_local = chosen:config("emulated_tls") and {"-femulated-tls"} or {}
    local linker_version = chosen:config("linker_version") and {"-mlinker-version=" .. chosen:config("linker_version")} or {}
    local common = table.join({"-target", package:arch() .. "-apple-ios", "-miphoneos-version-min=" .. minimum, "-isysroot", sdk}, linker_version)
    local compiled = table.join(common, thread_local, opt.cflags or {})
    local linker = {}
    for _, flag in ipairs(table.wrap(chosen:get("shflags"))) do
        if flag:startswith("-fuse-ld=") then
            table.insert(linker, flag)
        end
    end
    -- CMake has one set of linker flags for every language, and Swift's driver takes neither clang's spelling of the
    -- sysroot and the deployment target nor its spelling of the linker. Where a build has Swift, each language carries
    -- those itself - C and C++ in their own flags, which CMake also puts on their link lines, and Swift in its own - and
    -- what stays here is only what a link of any language takes.
    local linked = opt.swift and {} or table.join(common, linker, opt.ldflags or {})
    local roots = {sdk}
    for _, dep in ipairs(package:orderdeps()) do
        if not dep:is_binary() and not dep:is_toolchain() then
            table.insert(roots, dep:installdir())
        end
    end
    local lines = {
        "set(CMAKE_SYSTEM_NAME " .. (opt.system or "iOS") .. ")",
        "set(CMAKE_SYSTEM_PROCESSOR " .. assert(processors[package:arch()], "apple-ios builds armv6, armv7, armv7s and arm64") .. ")",
        "set(CMAKE_OSX_SYSROOT \"" .. sdk .. "\" CACHE PATH \"\" FORCE)",
        "set(CMAKE_OSX_ARCHITECTURES " .. package:arch() .. " CACHE STRING \"\" FORCE)",
        "set(CMAKE_C_COMPILER \"" .. chosen:tool("cc") .. "\")",
        "set(CMAKE_CXX_COMPILER \"" .. chosen:tool("cxx") .. "\")"
    }
    if (opt.system or "iOS") == "iOS" then
        table.insert(lines, "set(CMAKE_OSX_DEPLOYMENT_TARGET " .. minimum .. " CACHE STRING \"\" FORCE)")
    else
        table.insert(lines, "set(CMAKE_OSX_DEPLOYMENT_TARGET \"\" CACHE STRING \"\" FORCE)")
    end
    for _, language in ipairs({"C", "CXX", "OBJC", "OBJCXX", "ASM"}) do
        local flags = table.join(compiled, language:find("CXX") and opt.cxxflags or {})
        table.insert(lines, string.format("set(CMAKE_%s_FLAGS_INIT \"%s\")", language, quoted(flags)))
    end
    for _, kind in ipairs({"EXE", "SHARED", "MODULE"}) do
        table.insert(lines, string.format("set(CMAKE_%s_LINKER_FLAGS_INIT \"%s\")", kind, quoted(table.join(linked, kind ~= "EXE" and opt.shflags or {}))))
    end
    if opt.swift then
        -- CMake cannot run a test binary for the phone, and Swift's linker driver takes its own spelling of the linker,
        -- so each language names the linker it uses.
        local linker = ""
        for _, flag in ipairs(table.wrap(chosen:get("shflags"))) do
            if flag:startswith("-fuse-ld=") then
                linker = flag:sub(#"-fuse-ld=" + 1)
            end
        end
        table.join2(lines, {
            "set(CMAKE_Swift_COMPILER \"" .. opt.swift.compiler .. "\")",
            "set(CMAKE_Swift_COMPILER_TARGET " .. package:arch() .. "-apple-ios" .. minimum .. ")",
            "set(CMAKE_Swift_COMPILER_WORKS YES)",
            string.format("set(CMAKE_Swift_FLAGS_INIT \"%s\")", quoted(table.wrap(opt.swift.flags)))
        })
        if linker ~= "" then
            table.join2(lines, {
                "set(CMAKE_LINKER_TYPE LD64)",
                string.format("set(CMAKE_C_USING_LINKER_LD64 \"%s\")", quoted(table.join({"-fuse-ld=" .. linker}, opt.ldflags or {}))),
                string.format("set(CMAKE_CXX_USING_LINKER_LD64 \"%s\")", quoted(table.join({"-fuse-ld=" .. linker}, opt.ldflags or {}))),
                string.format("set(CMAKE_Swift_USING_LINKER_LD64 \"-use-ld=%s\")", linker)
            })
        end
    end
    table.join2(lines, {
        "set(CMAKE_FIND_ROOT_PATH \"" .. table.concat(roots, "\" \"") .. "\")",
        "set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)",
        "set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)",
        "set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)",
        "set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)"
    })
    local file = path.absolute(path.join(opt.builddir or "build_charon", "apple-ios.toolchain.cmake"))
    io.writefile(file, table.concat(lines, "\n") .. "\n")
    return file
end

function install(package, configs, opt)
    opt = table.copy(opt or {})
    if opt.deps then
        local from_deps = import("deps").flags(package, opt.deps ~= true and opt.deps or nil)
        opt.cflags = table.join(opt.cflags or {}, from_deps.cflags)
        opt.cxxflags = table.join(opt.cxxflags or {}, from_deps.cxxflags)
        opt.shflags = table.join(opt.shflags or {}, from_deps.ldflags)
        opt.ldflags = table.join(opt.ldflags or {}, from_deps.ldflags)
    end
    local cmake = assert(find_tool("cmake"), "cmake is needed to build " .. package:name())
    local ninja = assert(find_tool("ninja"), "ninja is needed to build " .. package:name())
    -- One build tree per configuration. CMake takes a toolchain file's flags only while their cache entries are unset, and
    -- the sources of a package are one directory for every architecture it is built for, so a shared tree would build the
    -- second architecture - or the next version of a recipe - with the flags of the first.
    local builddir = path.absolute(opt.builddir or ("build_charon-" .. package:buildhash()))
    os.mkdir(builddir)
    local argv = {"-G", "Ninja", "-S", path.absolute(opt.sourcedir or "."), "-B", builddir,
                  "-DCMAKE_MAKE_PROGRAM=" .. ninja.program,
                  "-DCMAKE_TOOLCHAIN_FILE=" .. toolchain_file(package, table.join(opt, {builddir = builddir})),
                  "-DCMAKE_BUILD_TYPE=" .. (package:is_debug() and "Debug" or "Release"),
                  "-DCMAKE_INSTALL_PREFIX=" .. package:installdir(),
                  "-DCMAKE_INSTALL_LIBDIR=lib",
                  "-DBUILD_SHARED_LIBS=" .. (package:config("shared") and "ON" or "OFF"),
                  "-DCMAKE_MACOSX_BUNDLE=OFF"}
    table.join2(argv, configs or {})
    local envs = {SOURCE_DATE_EPOCH = opt.source_date_epoch or "0", IPHONEOS_DEPLOYMENT_TARGET = toolchain(package):config("deployment")}
    os.vrunv(cmake.program, argv, {envs = envs})
    os.vrunv(cmake.program, table.join({"--build", builddir, "--parallel", tostring(os.cpuinfo("ncpu"))}, opt.targets and table.join({"--target"}, opt.targets) or {}), {envs = envs})
    if opt.install ~= false then
        os.vrunv(cmake.program, {"--install", builddir}, {envs = envs})
    end
    import("install").finish(package, {prune = opt.prune, licenses = opt.licenses})
    return builddir
end
