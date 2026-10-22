local named = get_config("apple_sdk") or ""
local apple_sdk = import("apple.sdk", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})
local sdk = {name = "iphoneos-sdk", version = named ~= "" and named or apple_sdk.release_for(get_config("component"))}
for _, name in ipairs({"apple-compat", "activitykit", "appintents", "cloudkit", "createml", "cryptokit", "musickit", "network", "realityfoundation", "realitykit", "spatial", "swift-data", "swift-embedded", "swiftui", "tipkit", "uniformtypeidentifiers", "weatherkit", "widgetkit"}) do
    add_requireconfs(name, {configs = {apple_sdk = sdk.version}})
    add_requireconfs("**." .. name, {configs = {apple_sdk = sdk.version}})
end
local ld64 = {name = "ld64", version = "956.6"}
local ldid = {name = "ldid", version = "2.1.5-procursus7+23.gaf86971"}
local llvm = {name = "llvm", version = "23.1.3"}

for _, tool in ipairs({sdk, ld64, ldid, llvm}) do
    add_requires("revenant@" .. tool.name .. " " .. tool.version, {alias = tool.name})
end

add_requireconfs("**.iphoneos-sdk", {override = true, version = sdk.version})

add_requires("revenant@firmware-tools", {alias = "firmware-tools"})

add_requireconfs("**.m4", {system = false})
add_requireconfs("**.pkgconf", {system = false})

local minimum = get_config("apple_minimum")

includes(path.join(os.scriptdir(), "..", "..", "modules", "apple", "slices.lua"))
if minimum then
    local declared = minimum
    local other
    minimum, other = slice_minimum(get_config("arch"), declared, os.getenv("REVENANT_SLICES"))
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
    local toolchain = string.format("@addon/revenant/apple-ios[minimum=%s,sdk=%s,ld64=%s,llvm=%s,optimize=packages,flags=%s]", minimum, sdk.version, ld64.version, llvm.version, hash.strhash128(table.concat(digests, ";")))
    add_requireconfs("*|" .. sdk.name .. "|" .. ld64.name .. "|" .. ldid.name .. "|" .. llvm.name .. "|firmware-tools|emulator|swiftshader", {configs = {toolchains = toolchain}})
end
