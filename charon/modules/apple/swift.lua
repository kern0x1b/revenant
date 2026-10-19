local FEATURES = {"Embedded", "Macros", "FreestandingMacros", "Extern", "BitwiseCopyable", "ValueGenerics", "AddressableParameters",
                  "AddressableTypes", "AllowUnsafeAttribute", "SuppressedAssociatedTypesWithDefaults", "Reparenting", "Lifetimes",
                  "BorrowAndMutateAccessors", "BorrowInout", "NonescapableTypes", "LifetimeDependence", "InoutLifetimeDependence",
                  "LifetimeDependenceMutableAccessors"}

local SOURCE_PATHS = {"/stdlib/public/core/", "/stdlib/public/SwiftShims/", "/stdlib/public/stubs/Unicode/", "/include/swift/",
                      "/utils/gyb.py", "/utils/SwiftIntTypes.py", "/utils/SwiftFloatingPointTypes.py", "/utils/GYBUnicodeDataUtils.py",
                      "/utils/availability-macros.def", "/LICENSE.txt"}

-- What a runtime build reads beside the Embedded module's sources: the standalone runtime build itself, the headers, the
-- demangler and threading sources it compiles, and the CMake modules and generators they use.
local RUNTIME_SOURCE_PATHS = {"/Runtimes/", "/include/", "/lib/Demangling/", "/lib/Threading/", "/stdlib/", "/cmake/", "/utils/"}

function source_paths()
    return SOURCE_PATHS
end

function runtime_source_paths()
    return RUNTIME_SOURCE_PATHS
end

function triple(architecture, deployment)
    return architecture .. "-apple-ios" .. deployment
end

function module_name(architecture)
    return architecture .. "-apple-ios"
end

local function embedded_entries(listing, list)
    local start = listing:find("OUT_LIST_EMBEDDED " .. list, 1, true)
    if not start then
        raise("stdlib/public/core/CMakeLists.txt has no %s list; this Swift release lays out its core library differently", list)
    end
    local finish = listing:find("\n  )", start, true)
    local entries = {}
    for entry in listing:sub(start, finish):gmatch("\n%s*EMBEDDED%s+(%S+)") do
        table.insert(entries, entry)
    end
    return entries
end

local function appended_sources(listing)
    local block = listing:match("list%(APPEND SWIFTLIB_EMBEDDED_SOURCES\n(.-)%)")
    if not block then
        raise("stdlib/public/core/CMakeLists.txt no longer appends the Embedded runtime sources to SWIFTLIB_EMBEDDED_SOURCES")
    end
    local entries = {}
    for entry in block:gmatch("%S+") do
        table.insert(entries, entry)
    end
    return entries
end

function core_sources(source, workdir, architecture)
    local core = path.join(source, "stdlib", "public", "core")
    local listing = io.readfile(path.join(core, "CMakeLists.txt"))
    local files = {}
    for _, entry in ipairs(table.join(embedded_entries(listing, "SWIFTLIB_EMBEDDED_SOURCES"), appended_sources(listing))) do
        table.insert(files, path.join(core, entry))
    end
    local generated = path.join(workdir, "gyb")
    os.mkdir(generated)
    for _, entry in ipairs(embedded_entries(listing, "SWIFTLIB_EMBEDDED_GYB_SOURCES")) do
        if entry:endswith(".gyb") then
            local output = path.join(generated, entry:sub(1, -5))
            os.vrunv("python3", {path.join(source, "utils", "gyb.py"), "-DCMAKE_SIZEOF_VOID_P=" .. (architecture == "arm64" and "8" or "4"), "--line-directive", "", "-o", output, path.join(core, entry)})
            table.insert(files, output)
        else
            table.insert(files, path.join(core, entry))
        end
    end
    return files
end

function availability(source)
    local flags = {}
    for line in io.readfile(path.join(source, "utils", "availability-macros.def")):gmatch("[^\n]+") do
        local definition = line:trim()
        if definition ~= "" and not definition:startswith("#") then
            local name = definition:match("^([^:]+):")
            for _, macro in ipairs({name, name:startswith("SwiftStdlib") and name:gsub("^SwiftStdlib", "StdlibDeploymentTarget") or nil}) do
                table.join2(flags, {"-Xfrontend", "-define-availability", "-Xfrontend", macro .. ":*"})
            end
        end
    end
    return flags
end

-- The availability macros of the standard library, every one of them always available: a macro names the OS releases whose
-- Swift runtime a library may rely on, and a runtime that ships with the program is there whatever the release.
function bundled_availability(source)
    local lines = {"# Rewritten by charon@swift-runtime: the runtime ships with the program, so every release has it."}
    for line in io.readfile(path.join(source, "utils", "availability-macros.def")):gmatch("[^\n]+") do
        local definition = line:trim()
        if definition ~= "" and not definition:startswith("#") then
            table.insert(lines, definition:match("^([^:]+):") .. ": *")
        end
    end
    return table.concat(lines, "\n") .. "\n"
end

function build_module(opt)
    local architecture, sdk = opt.architecture, opt.sdk
    local folder = path.join(opt.output, "Swift.swiftmodule")
    os.mkdir(folder)
    local argv = {"-emit-module", "-emit-module-path", path.join(folder, module_name(architecture) .. ".swiftmodule"),
                  "-target", triple(architecture, opt.deployment), "-sdk", sdk, "-O", "-wmo", "-parse-as-library",
                  "-Xllvm", "-sil-inline-generics", "-Xllvm", "-sil-partial-specialization",
                  "-Xfrontend", "-enable-experimental-concise-pound-file", "-strict-memory-safety",
                  "-D", "SWIFT_THREADING_NONE", "-no-link-objc-runtime", "-Xfrontend", "-disable-reflection-metadata",
                  "-nostdimport", "-parse-stdlib", "-module-name", "Swift",
                  "-Xfrontend", "-group-info-path", "-Xfrontend", path.join(opt.source, "stdlib", "public", "core", "GroupInfo.json"),
                  "-swift-version", "5", "-Xfrontend", "-empty-abi-descriptor", "-Xfrontend", "-enforce-exclusivity=unchecked",
                  "-runtime-compatibility-version", "none", "-disable-autolinking-runtime-compatibility-dynamic-replacements",
                  "-Xfrontend", "-disable-autolinking-runtime-compatibility-concurrency", "-Xfrontend", "-disable-objc-interop",
                  "-enable-upcoming-feature", "MemberImportVisibility",
                  "-Xfrontend", "-enable-relative-protocol-witness-tables", "-Xfrontend", "-swift-async-frame-pointer=never",
                  "-Xcc", "-ffreestanding"}
    for _, feature in ipairs(FEATURES) do
        table.join2(argv, {"-enable-experimental-feature", feature})
    end
    table.join2(argv, availability(opt.source), core_sources(opt.source, opt.workdir, architecture))
    os.vrunv(opt.swiftc, argv)
    return folder
end

function unicode_tables(source)
    return {
        folder = path.join(source, "stdlib", "public", "stubs", "Unicode"),
        includedirs = {path.join(source, "include"), path.join(source, "stdlib", "public", "SwiftShims"),
                       path.join(source, "stdlib", "public", "stubs", "Unicode")},
        defines = {"SWIFT_STDLIB_ENABLE_UNICODE_DATA=1"},
        cxxflags = {"-std=c++17", "-fno-exceptions", "-fno-rtti"}
    }
end

function runtime_config(version)
    local major, minor = version:match("^(%d+)%.(%d+)")
    return string.format("#ifndef SWIFT_RUNTIME_CMAKECONFIG_H\n#define SWIFT_RUNTIME_CMAKECONFIG_H\n#define SWIFT_VERSION_MAJOR \"%s\"\n#define SWIFT_VERSION_MINOR \"%s\"\n#endif\n", major, minor)
end

function module_identifier(name)
    local identifier = name:gsub("[^%w_]", "_")
    return identifier:match("^%d") and ("_" .. identifier) or identifier
end

function compile_flags(opt)
    local flags = {"-target", triple(opt.architecture, opt.deployment), "-sdk", opt.sdk,
                   "-enable-experimental-feature", "Embedded", "-wmo", "-I", opt.modules, "-module-name", module_identifier(opt.module)}
    local optimizations = {none = "-Onone", smallest = "-Osize"}
    table.insert(flags, opt.optimize and (optimizations[opt.optimize] or "-O") or "-Onone")
    if opt.symbols then
        table.insert(flags, "-g")
    end
    if opt.prefix_map then
        table.join2(flags, {"-file-prefix-map", opt.prefix_map})
    end
    if not opt.has_main then
        table.insert(flags, "-parse-as-library")
    end
    return flags
end

-- The flags a port compiles with against the runtime it carries. The features of this Swift release are available
-- whatever the deployment target, because the runtime ships with the program, while the SDK's own availability is
-- checked as before; the clang importer is told the same target, or it would read the SDK's headers for the release the
-- compiler was built against. The compatibility libraries of the Swift runtimes that shipped in an OS are not linked:
-- there is no OS Swift here to be compatible with.
function runtime_flags(opt)
    local flags = {"-target", triple(opt.architecture, opt.deployment), "-clang-target", triple(opt.architecture, opt.deployment),
                   "-sdk", opt.sdk, "-resource-dir", opt.resources, "-Xfrontend", "-bundled-swift-runtime",
                   "-runtime-compatibility-version", "none", "-wmo", "-module-name", module_identifier(opt.module)}
    if opt.plugins then
        table.join2(flags, {"-plugin-path", opt.plugins})
    end
    local optimizations = {none = "-Onone", smallest = "-Osize"}
    table.insert(flags, opt.optimize and (optimizations[opt.optimize] or "-O") or "-Onone")
    if opt.symbols then
        table.insert(flags, "-g")
    end
    if opt.prefix_map then
        table.join2(flags, {"-file-prefix-map", opt.prefix_map})
    end
    if not opt.has_main then
        table.insert(flags, "-parse-as-library")
    end
    return flags
end

function codegen_flags(opt)
    local levels = {none = "-O0", smallest = "-Os"}
    return {opt.optimize and (levels[opt.optimize] or "-O2") or "-O0", "-x", "ir"}
end
