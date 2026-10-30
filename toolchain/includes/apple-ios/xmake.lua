includes(path.join(os.scriptdir(), "..", "..", "modules", "apple", "sdk.lua"))
local named = get_config("apple_sdk") or ""
local sdk = {name = "iphoneos-sdk", version = named ~= "" and named or apple_sdk_release()}
for _, name in ipairs({"apple-compat", "activitykit", "appintents", "authenticationservices", "backports", "cloudkit", "createml", "cryptokit", "musickit", "network", "realityfoundation", "realitykit", "spatial", "storekit", "swift-data", "swift-embedded", "swiftui", "tipkit", "uniformtypeidentifiers", "weatherkit", "widgetkit"}) do
    add_requireconfs(name, {configs = {apple_sdk = sdk.version}})
    add_requireconfs("**." .. name, {configs = {apple_sdk = sdk.version}})
end
local ld64 = {name = "ld64", version = "956.6"}
local ldid = {name = "ldid", version = "2.1.5-procursus7+23.gaf86971"}
local llvm = {name = "llvm", version = "23.1.3"}

local compat_only = get_config("apple_compat_only")
for _, tool in ipairs(compat_only and {sdk, ld64, llvm} or {sdk, ld64, ldid, llvm}) do
    add_requires("revenant@" .. tool.name .. " " .. tool.version, {alias = tool.name, host = tool == ldid})
end

add_requireconfs("**.iphoneos-sdk", {override = true, version = sdk.version})

local backports_selected = (os.getenv("REVENANT_BACKPORTS_LIBRARIES") or "") ~= ""
if not compat_only then
    add_requires("revenant@firmware-tools", {alias = "firmware-tools"})
    if not backports_selected then
        add_requires("revenant@backports", {alias = "backports"})
    end
end

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
    -- The host tools ldid signs with, and the libraries only ldid links, are built for the host, not with the iPhoneOS toolchain.
    add_requireconfs("*|" .. sdk.name .. "|" .. ld64.name .. "|" .. ldid.name .. "|" .. llvm.name .. "|firmware-tools|emulator|swiftshader|libplist|openssl-host", {configs = {toolchains = toolchain}})
end
