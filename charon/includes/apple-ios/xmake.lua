-- The SDK is 16.4 unless the project sets apple_sdk to another the iphoneos-sdk package carries (a port whose source is pinned to a
-- newer SDK, as Telegram is to 26.2); the version is part of the toolchain every package is built with, so a change rebuilds them.
local sdk = {name = "iphoneos-sdk", version = get_config("apple_sdk") or "16.4"}
local ld64 = {name = "ld64", version = "956.6"}
local ldid = {name = "ldid", version = "2.1.5-procursus7+23.gaf86971"}
local llvm = {name = "llvm", version = "23.1.1"}

for _, tool in ipairs({sdk, ld64, ldid, llvm}) do
    add_requires("charon@" .. tool.name .. " " .. tool.version, {alias = tool.name})
end

-- a package that depends on the SDK (llvm builds compiler-rt's builtins against it) names no version and so takes the newest the
-- iphoneos-sdk package lists: once it lists more than one, a second SDK beside the project's
add_requireconfs("**.iphoneos-sdk", {override = true, version = sdk.version})

add_requires("charon@firmware-tools", {alias = "firmware-tools"})

add_requireconfs("**.m4", {system = false})
add_requireconfs("**.pkgconf", {system = false})

-- Which charon@apple-backports libraries a process carries, as a comma-separated list of its configs. It is a project
-- decision because more than one dependency asks for it and each names only its own: charon@swift-runtime's port
-- headers lower the marks of what the backports implement, so a program compiled against them has to carry
-- coredata (and uikit for an application), and a package built over them asks for more of its own - charon@matter
-- needs network, because the Matter framework's device browser calls nw_*. One package with one set of configs, so
-- the union is said once here and every dependency, swift-runtime included, takes it.
local carried = get_config("apple_backports")
if carried then
    local configs = {}
    for _, name in ipairs(carried:split(",")) do
        configs[name] = true
    end
    add_requireconfs("**.apple-backports", {override = true, configs = configs})
end

local minimum = get_config("apple_minimum")

-- The slice of a universal target is built for the release its architecture first runs, where apple_minimum is older and
-- another slice keeps it (modules/apple/slices.lua says how); the port is told once per process.
includes(path.join(os.scriptdir(), "..", "..", "modules", "apple", "slices.lua"))
if minimum then
    local declared = minimum
    local other
    minimum, other = slice_minimum(get_config("arch"), declared, os.getenv("CHARON_SLICES"))
    if minimum ~= declared then
        print("note: the %s slice is built for iOS %s, the first release an %s device runs; apple_minimum %s holds for the %s slice", get_config("arch"), minimum, get_config("arch"), declared, other)
    end
end

if minimum then
    local root = path.join(os.scriptdir(), "..", "..")
    local digests = {}
    for _, file in ipairs({"toolchains/apple-ios/xmake.lua", "modules/apple/architectures.lua", "modules/apple/cmake.lua", "modules/apple/sources.lua", "modules/apple/deps.lua", "modules/apple/swift.lua"}) do
        table.insert(digests, file .. "=" .. hash.sha256(path.join(root, file)))
    end
    local toolchain = string.format("@addon/charon/apple-ios[minimum=%s,sdk=%s,ld64=%s,llvm=%s,optimize=packages,flags=%s]", minimum, sdk.version, ld64.version, llvm.version, hash.strhash128(table.concat(digests, ";")))
    add_requireconfs("*|" .. sdk.name .. "|" .. ld64.name .. "|" .. ldid.name .. "|" .. llvm.name .. "|firmware-tools|shade|swiftshader", {configs = {toolchains = toolchain}})
end
