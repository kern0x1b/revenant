import("byteorder", {rootdir = os.scriptdir()})

local function long_bracket(source, at)
    return source:match("^%[(=*)%[", at)
end

function stripped(source)
    local out, line = {}, {}
    local at, size = 1, #source
    local function flush()
        local text = table.concat(line):gsub("^%s+", ""):gsub("%s+$", "")
        if text ~= "" then
            table.insert(out, text)
        end
        line = {}
    end
    while at <= size do
        local char = source:sub(at, at)
        if source:sub(at, at + 1) == "--" then
            local level = source:match("^%-%-%[(=*)%[", at)
            if level then
                local close = "]" .. level .. "]"
                local found = source:find(close, at, true)
                at = found and found + #close or size + 1
            else
                at = source:find("\n", at, true) or size + 1
            end
        elseif char == '"' or char == "'" then
            local cursor = at + 1
            while cursor <= size do
                local next = source:sub(cursor, cursor)
                if next == "\\" then
                    cursor = cursor + 2
                elseif next == char then
                    break
                else
                    cursor = cursor + 1
                end
            end
            table.insert(line, source:sub(at, cursor))
            at = cursor + 1
        elseif char == "[" and long_bracket(source, at) then
            local close = "]" .. long_bracket(source, at) .. "]"
            local found = source:find(close, at, true)
            local last = found and found + #close - 1 or size
            table.insert(line, source:sub(at, last))
            at = last + 1
        elseif char == "\n" then
            flush()
            at = at + 1
        else
            table.insert(line, char)
            at = at + 1
        end
    end
    flush()
    return table.concat(out, "\n")
end

local RECIPES = {
    {folder = "packages/s/swift-runtime", variable = "swift_runtime_sources_digest",
     inputs = {"packages/s/swift-runtime/xmake.lua", "toolchain/modules/apple/shared_runtime.lua",
               "toolchain/modules/apple/compat.lua", "toolchain/modules/apple/dyld.lua", "toolchain/modules/apple/lowered.lua",
               "toolchain/modules/gyb/bigint.lua", "toolchain/modules/gyb/compiler.lua", "toolchain/modules/gyb/lexer.lua", "toolchain/modules/gyb/main.lua",
               "toolchain/modules/gyb/parser.lua", "toolchain/modules/gyb/random.lua", "toolchain/modules/gyb/runtime.lua", "toolchain/modules/gyb/template.lua",
               "packages/s/swift-runtime/patches/**.patch",
               "toolchain/src/apple-compat/src/*.c", "toolchain/src/apple-compat/src/*.h", "toolchain/src/apple-compat/include/revenant/*.h"}},
    {folder = "packages/l/libcxx", variable = "libcxx_sources_digest",
     inputs = {"packages/l/libcxx/xmake.lua", "packages/l/libcxx/patches/*.patch", "toolchain/modules/apple/shared_runtime.lua",
               "toolchain/src/apple-compat/src/*.c", "toolchain/src/apple-compat/src/*.h", "toolchain/src/apple-compat/include/revenant/*.h"}},
    {folder = "packages/s/swiftui", variable = "swiftui_sources_digest",
     inputs = {"packages/s/swiftui/xmake.lua", "frameworks/SwiftUI/xmake.lua", "frameworks/SwiftUI/src/*"}},
    {folder = "packages/a/appintents", variable = "appintents_sources_digest",
     inputs = {"packages/a/appintents/xmake.lua", "frameworks/Backports/src/Swift/xmake.lua", "toolchain/modules/apple/wrapper.lua", "frameworks/Backports/src/AppIntents/*"}},
    {folder = "packages/a/activitykit", variable = "activitykit_sources_digest",
     inputs = {"packages/a/activitykit/xmake.lua", "frameworks/Backports/src/Swift/xmake.lua", "toolchain/modules/apple/wrapper.lua", "frameworks/Backports/src/ActivityKit/*"}},
    {folder = "packages/t/tipkit", variable = "tipkit_sources_digest",
     inputs = {"packages/t/tipkit/xmake.lua", "frameworks/Backports/src/Swift/xmake.lua", "toolchain/modules/apple/wrapper.lua", "frameworks/Backports/src/TipKit/*"}},
    {folder = "packages/w/widgetkit", variable = "widgetkit_sources_digest",
     inputs = {"packages/w/widgetkit/xmake.lua", "frameworks/Backports/src/Swift/xmake.lua", "toolchain/modules/apple/wrapper.lua", "frameworks/Backports/src/WidgetKit/*"}},
    {folder = "packages/c/createml", variable = "createml_sources_digest",
     inputs = {"packages/c/createml/xmake.lua", "frameworks/Backports/src/Swift/xmake.lua", "toolchain/modules/apple/wrapper.lua", "frameworks/Backports/src/TabularData/*",
               "frameworks/Backports/src/CoreML/*.swift", "frameworks/Backports/src/CoreML/RevenantCoreML.h",
               "frameworks/Backports/src/CreateMLComponents/*", "frameworks/Backports/src/CreateML/*"}},
    {folder = "packages/m/musickit", variable = "musickit_sources_digest",
     inputs = {"packages/m/musickit/xmake.lua", "frameworks/Backports/src/Swift/xmake.lua", "toolchain/modules/apple/wrapper.lua", "frameworks/Backports/src/MusicKit/*",
               "frameworks/Backports/src/MusicKit/include/*"}},
    {folder = "packages/s/swift-data", variable = "swift_data_sources_digest",
     inputs = {"packages/s/swift-data/xmake.lua", "frameworks/Backports/src/Swift/xmake.lua", "toolchain/modules/apple/wrapper.lua", "frameworks/Backports/src/SwiftData/*"}},
    {folder = "packages/a/apple-compat", variable = "apple_compat_sources_digest",
     inputs = {"packages/a/apple-compat/xmake.lua", "toolchain/src/apple-compat/xmake.lua", "toolchain/src/apple-compat/src/*",
               "toolchain/src/apple-compat/include/revenant/*", "toolchain/modules/apple/compat.lua"}},
    {folder = "packages/s/swift-embedded", variable = "swift_embedded_sources_digest",
     inputs = {"packages/s/swift-embedded/xmake.lua", "toolchain/src/swift-embedded/xmake.lua", "toolchain/modules/apple/swift.lua", "toolchain/modules/apple/wrapper.lua"}},
    {folder = "packages/s/swift-crypto", variable = "swift_crypto_sources_digest",
     inputs = {"packages/s/swift-crypto/xmake.lua", "packages/s/swift-crypto/patches/*.patch", "packages/s/swift-crypto/patches/swift-asn1/*.patch",
               "toolchain/src/apple-compat/src/memset_s.c", "toolchain/src/apple-compat/src/objc_opt_self.c",
               "toolchain/src/apple-compat/src/objc_allocWithZone.c", "toolchain/src/apple-compat/include/revenant/*.h"}},
    {folder = "packages/s/swift-system", variable = "swift_system_sources_digest",
     inputs = {"packages/s/swift-system/xmake.lua", "packages/s/swift-system/patches/*.patch",
               "toolchain/src/apple-compat/src/openat.c", "toolchain/src/apple-compat/src/unlinkat.c",
               "toolchain/src/apple-compat/src/fdopendir.c", "toolchain/src/apple-compat/src/fstatat.c",
               "toolchain/src/apple-compat/include/revenant/*.h"}},
    {folder = "packages/i/iphoneos-sdk", variable = "iphoneos_sdk_additions_digest",
     inputs = {"packages/i/iphoneos-sdk/xmake.lua", "toolchain/modules/apple/sdk.lua", "toolchain/modules/apple/sdkstubs.lua", "toolchain/src/iphoneos-sdk/usr/**",
               "toolchain/src/iphoneos-sdk/arclite/*", "toolchain/src/iphoneos-sdk/blocks/*", "toolchain/src/iphoneos-sdk/markers/*"}},
    {folder = "packages/r/realityfoundation", variable = "realityfoundation_sources_digest",
     inputs = {"packages/r/realityfoundation/xmake.lua", "frameworks/Backports/src/Swift/xmake.lua", "toolchain/modules/apple/wrapper.lua",
               "frameworks/Backports/tools/apinotes.lua", "frameworks/Backports/src/RealityFoundation/*.swift"}},
    {folder = "packages/r/realitykit", variable = "realitykit_sources_digest",
     inputs = {"packages/r/realitykit/xmake.lua", "frameworks/Backports/src/Swift/xmake.lua", "toolchain/modules/apple/wrapper.lua",
               "frameworks/Backports/tools/apinotes.lua", "frameworks/Backports/src/RealityKit/*.swift"}},
    {folder = "packages/s/spatial", variable = "spatial_sources_digest",
     inputs = {"packages/s/spatial/xmake.lua", "frameworks/Backports/src/Swift/xmake.lua", "toolchain/modules/apple/wrapper.lua",
               "frameworks/Backports/src/Spatial/*.swift", "frameworks/Backports/src/Spatial/*.swift.gyb"}},
    {folder = "packages/c/cloudkit", variable = "cloudkit_sources_digest",
     inputs = {"packages/c/cloudkit/xmake.lua", "frameworks/Backports/src/Swift/xmake.lua", "toolchain/modules/apple/wrapper.lua",
               "frameworks/Backports/src/CloudKit/*.swift"}},
    {folder = "packages/w/weatherkit", variable = "weatherkit_sources_digest",
     inputs = {"packages/w/weatherkit/xmake.lua", "frameworks/Backports/src/Swift/xmake.lua", "toolchain/modules/apple/wrapper.lua",
               "frameworks/Backports/src/WeatherKit/*.swift"}},
    {folder = "packages/n/network", variable = "network_sources_digest",
     inputs = {"packages/n/network/xmake.lua", "frameworks/Backports/src/Swift/xmake.lua", "toolchain/modules/apple/wrapper.lua",
               "frameworks/Backports/src/Network/*.swift"}},
    {folder = "packages/u/uniformtypeidentifiers", variable = "uniformtypeidentifiers_sources_digest",
     inputs = {"packages/u/uniformtypeidentifiers/xmake.lua", "frameworks/Backports/src/Swift/xmake.lua", "toolchain/modules/apple/wrapper.lua",
               "frameworks/Backports/src/UniformTypeIdentifiers/*.swift"}},
    {folder = "packages/c/cryptokit", variable = "cryptokit_sources_digest",
     inputs = {"packages/c/cryptokit/xmake.lua", "frameworks/Backports/src/Swift/xmake.lua", "toolchain/modules/apple/wrapper.lua",
               "frameworks/Backports/src/CryptoKit/*.swift"}}
}

function recipes()
    return RECIPES
end

function sources(root, inputs)
    local digests = {}
    for _, input in ipairs(inputs) do
        local files = {path.join(root, input)}
        if input:find("*", 1, true) then
            files = os.files(path.join(root, input))
            byteorder.sort(files)
        end
        for _, file in ipairs(files) do
            local text = io.readfile(file)
            if file:endswith(".lua") then
                text = stripped(text)
            end
            local name = input:find("*", 1, true) and path.relative(file, root) or input
            table.insert(digests, name .. "=" .. hash.strhash128(text))
        end
    end
    return hash.strhash128(table.concat(digests, ";"))
end

function digest_file(recipe, value)
    return string.format("%s = \"%s\"\n", recipe.variable, value)
end
