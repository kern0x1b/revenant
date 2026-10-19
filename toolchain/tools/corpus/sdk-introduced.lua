import("core.base.json")

local MODULES = path.join(os.scriptdir(), "..", "..", "modules")
local byteorder = import("byteorder", {rootdir = MODULES, anonymous = true})
local workspace = import("workspace", {rootdir = MODULES, anonymous = true})
local sw = import("surface_walk", {rootdir = os.scriptdir(), anonymous = true})

local NULL = {}
local CATALYST_TARGET = "arm64-apple-ios26.0-macabi"
local IOS_TARGET = "arm64-apple-ios16.4"
local IOS_VERSION = "16.4"
local UNVERIFIED_REASON = "no version of its own or its container's, and not declared in the local iPhoneOS SDK either - Catalyst-only or newer than that SDK, not distinguished here"

local FRAMEWORKS = {"Foundation", "UIKit", "Photos", "PhotosUI", "AVFoundation", "AVKit", "CoreGraphics", "ImageIO",
    "CoreVideo", "CoreImage", "CoreMedia", "Security", "CoreServices", "MobileCoreServices", "WebKit",
    "GameController", "CoreTelephony", "LocalAuthentication", "UserNotifications", "CoreData",
    "SafariServices", "QuartzCore", "CoreLocation", "CoreText", "CloudKit", "Contacts", "EventKit",
    "MessageUI", "StoreKit", "AuthenticationServices", "BackgroundTasks", "CoreMotion", "MapKit",
    "AudioToolbox", "Accelerate", "VideoToolbox", "AVFAudio", "Intents", "CallKit", "PushKit",
    "NetworkExtension", "SystemConfiguration", "CoreBluetooth", "Vision", "CoreML", "NaturalLanguage",
    "FileProvider",
    "Metal", "MetalKit", "MetalPerformanceShaders", "SceneKit", "CoreHaptics", "MediaPlayer", "PassKit",
    "Speech", "JavaScriptCore", "OSLog", "CoreSpotlight", "Messages", "ReplayKit", "ARKit", "MetricKit",
    "ModelIO", "WatchConnectivity", "Social",
    "PDFKit", "MetalFX"}

local KNOWN_NON_SDK = {
    SwiftNativeNSObject = true, _TtCs12_SwiftObject = true,
    OS_dispatch_group = true, OS_dispatch_queue = true, OS_dispatch_source = true, OS_os_log = true,
    NSConstantArray = true, NSConstantDictionary = true, NSConstantDoubleNumber = true, NSConstantIntegerNumber = true,
    _MSStickerPackCollectionViewDataSource = true,
}

local function object(keys, values)
    values._keys = keys
    return values
end

local function utf8_units(text, at)
    local first = text:byte(at)
    local length, value
    if first < 0xc2 then
        return nil
    elseif first < 0xe0 then
        length, value = 2, first - 0xc0
    elseif first < 0xf0 then
        length, value = 3, first - 0xe0
    elseif first < 0xf5 then
        length, value = 4, first - 0xf0
    else
        return nil
    end
    for index = at + 1, at + length - 1 do
        local byte = text:byte(index)
        if byte == nil or byte < 0x80 or byte > 0xbf then
            return nil
        end
        value = value * 64 + (byte - 0x80)
    end
    if (length == 3 and (value < 0x800 or (value >= 0xd800 and value <= 0xdfff))) or (length == 4 and (value < 0x10000 or value > 0x10ffff)) then
        return nil
    end
    return value, length
end

local ESCAPED = {['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t", ["\b"] = "\\b", ["\f"] = "\\f"}

local function string_text(text)
    if not text:find('[%z\1-\31"\\\127-\255]') then
        return '"' .. text .. '"'
    end
    local out, at = {}, 1
    while at <= #text do
        local char = text:sub(at, at)
        local byte = char:byte()
        if ESCAPED[char] then
            table.insert(out, ESCAPED[char])
            at = at + 1
        elseif byte < 0x20 or byte == 0x7f then
            table.insert(out, string.format("\\u%04x", byte))
            at = at + 1
        elseif byte < 0x80 then
            table.insert(out, char)
            at = at + 1
        else
            local value, length = utf8_units(text, at)
            if value == nil then
                table.insert(out, "\\ufffd")
                at = at + 1
            elseif value >= 0x10000 then
                local offset = value - 0x10000
                table.insert(out, string.format("\\u%04x\\u%04x", 0xd800 + (offset >> 10), 0xdc00 + (offset & 0x3ff)))
                at = at + length
            else
                table.insert(out, string.format("\\u%04x", value))
                at = at + length
            end
        end
    end
    return '"' .. table.concat(out) .. '"'
end

local function encode_into(value, out)
    if value == nil or value == NULL then
        table.insert(out, "null")
    elseif type(value) == "string" then
        table.insert(out, string_text(value))
    elseif type(value) == "number" then
        table.insert(out, string.format("%d", value))
    elseif type(value) == "boolean" then
        table.insert(out, value and "true" or "false")
    elseif value._keys then
        table.insert(out, "{")
        for index, key in ipairs(value._keys) do
            if index > 1 then
                table.insert(out, ", ")
            end
            table.insert(out, string_text(key))
            table.insert(out, ": ")
            encode_into(value[key], out)
        end
        table.insert(out, "}")
    else
        table.insert(out, "[")
        for index, item in ipairs(value) do
            if index > 1 then
                table.insert(out, ", ")
            end
            encode_into(item, out)
        end
        table.insert(out, "]")
    end
end

function dumps(value)
    local out = {}
    encode_into(value, out)
    return table.concat(out)
end

local function show(version)
    if version == nil then
        return ""
    end
    if sw.same(version, sw.deprecated_no_version()) then
        return "yes"
    end
    return sw.show_version(version)
end

local ROW_KEYS = {"api", "framework", "kind", "lang", "introduced", "deprecated", "obsoleted", "unavailable", "via"}

local function objc_row(name, api, kind, detail)
    local keys = table.copy(ROW_KEYS)
    local row = {api = api, framework = name, kind = kind, lang = "objc",
                 introduced = show(detail.introduced), deprecated = show(detail.deprecated),
                 obsoleted = show(detail.obsoleted), unavailable = detail.unavailable and "yes" or "",
                 via = detail.via}
    for _, role in ipairs({"getter", "setter"}) do
        if detail[role] ~= nil then
            row[role] = detail[role]
            table.insert(keys, role)
        end
    end
    return object(keys, row)
end

local function surface_rows(rows, name, surface)
    for _, api in ipairs(surface.order) do
        table.insert(rows, objc_row(name, api, surface.rows[api].kind, surface.details[api]))
    end
end

function inherit_class_floor(rows)
    local floor = {}
    for _, row in ipairs(rows) do
        if row.lang == "objc" and (row.kind == "class" or row.kind == "protocol") and row.introduced ~= "" then
            local have = floor[row.api]
            if have == nil or sw.compare(sw.parse_version(row.introduced), sw.parse_version(have)) < 0 then
                floor[row.api] = row.introduced
            end
        end
    end
    local taken = 0
    for _, row in ipairs(rows) do
        if row.lang == "objc" and (row.kind == "method" or row.kind == "property") and row.via == "none" then
            local owner = row.api:match("^[-+]%[([%w_]+) ") or row.api:match("^([%w_]+)%.")
            if owner and floor[owner] then
                row.introduced = floor[owner]
                row.via = "class-floor"
                taken = taken + 1
            end
        end
    end
    return taken
end

local function set_of(list)
    local set = {}
    for _, item in ipairs(list) do
        set[item] = true
    end
    return set
end

local function sorted_keys(set)
    return byteorder.keys(set)
end

local function bundle_names(sdk_path, target, with_headers)
    local names = {}
    for _, base in ipairs(sw.framework_bases(sdk_path, target, true)) do
        for _, entry in ipairs(os.filedirs(path.join(base, "*.framework"))) do
            local name = path.basename(entry)
            if not with_headers or sw.framework_headers_dir(sdk_path, name, target, true) then
                names[name] = true
            end
        end
    end
    return names
end

local function swift_module()
    local file = path.join(os.scriptdir(), "swiftinterface.lua")
    if not os.isfile(file) then
        raise("sdk-introduced.lua: no %s to read the .swiftinterface files with; pass --no-swift to walk the headers only", file)
    end
    return import("swiftinterface", {rootdir = os.scriptdir(), anonymous = true})
end

function walk_sdk(sdk_path, only, with_swift, with_include)
    local version = sw.sdk_version(sdk_path)
    local target = "arm64-apple-ios" .. version
    local only_set = only and set_of(only) or nil
    local names = bundle_names(sdk_path, target, true)
    if only_set then
        for name in pairs(names) do
            if not only_set[name] then
                names[name] = nil
            end
        end
    end
    local rows, failed, frameworks = {}, {}, {}
    local anonymous, anonymous_order = {}, {}
    local function count_anonymous(surface)
        for _, kind in ipairs(surface.anonymous_order) do
            if anonymous[kind] == nil then
                anonymous[kind] = 0
                table.insert(anonymous_order, kind)
            end
            anonymous[kind] = anonymous[kind] + surface.anonymous[kind]
        end
    end
    for _, fw in ipairs(sorted_keys(names)) do
        local problems = {}
        local surface = sw.declared_surface(sdk_path, fw, target, true, problems)
        table.join2(failed, problems)
        count_anonymous(surface)
        surface_rows(rows, fw, surface)
        frameworks[fw] = true
        print("%s: %d rows", fw, #surface.order)
    end
    local libraries = {}
    if with_include then
        for _, library in ipairs(sw.include_libraries(sdk_path)) do
            if not only_set or only_set[library.name] then
                local problems = {}
                local surface = sw.library_surface(sdk_path, library.name, library.headers, target, problems)
                table.join2(failed, problems)
                count_anonymous(surface)
                surface_rows(rows, library.name, surface)
                frameworks[library.name] = true
                table.insert(libraries, library.name)
                print("%s: %d rows", library.name, #surface.order)
            end
        end
    end
    local walked = sorted_keys(frameworks)
    local swift_found, swift_with_rows = {}, {}
    if with_swift then
        local swift = swift_module()
        for _, module in ipairs(swift.interfaces(sdk_path).modules) do
            if not only_set or only_set[module] then
                table.insert(swift_found, module)
            end
        end
        local problems = {}
        local swift_rows = 0
        for _, row in ipairs(swift.rows(sdk_path, only_set, problems)) do
            swift_with_rows[row.framework] = true
            table.insert(rows, object(table.copy(ROW_KEYS), {api = row.api, framework = row.framework, kind = row.kind, lang = "swift",
                                                              introduced = row.introduced, deprecated = row.deprecated,
                                                              obsoleted = row.obsoleted, unavailable = row.unavailable,
                                                              via = row.via}))
            frameworks[row.framework] = true
            swift_rows = swift_rows + 1
        end
        table.join2(failed, problems)
        print("swiftinterface: %d modules found, %d with rows, %d rows", #swift_found, #table.keys(swift_with_rows), swift_rows)
    end
    local before = {objc = 0, swift = 0}
    local versioned = {}
    for _, row in ipairs(rows) do
        before[row.lang] = (before[row.lang] or 0) + 1
        if row.introduced ~= "" then
            versioned[row.lang .. "\0" .. row.kind .. "\0" .. row.api] = true
        end
    end
    local kept = {}
    for _, row in ipairs(rows) do
        if row.introduced ~= "" or not versioned[row.lang .. "\0" .. row.kind .. "\0" .. row.api] then
            table.insert(kept, row)
        end
    end
    rows = kept
    local after = {objc = 0, swift = 0}
    for _, row in ipairs(rows) do
        after[row.lang] = (after[row.lang] or 0) + 1
    end
    local forward = object({"objc", "swift"}, {objc = before.objc - after.objc, swift = before.swift - after.swift})
    local floor = inherit_class_floor(rows)
    local counts = {}
    for _, row in ipairs(rows) do
        local key = row.framework .. "\0" .. row.lang
        counts[key] = (counts[key] or 0) + 1
    end
    local function count(name, lang)
        return counts[name .. "\0" .. lang] or 0
    end
    local framework_names = sorted_keys(frameworks)
    local framework_counts = object(framework_names, {})
    for _, name in ipairs(framework_names) do
        framework_counts[name] = object({"objc", "swift"}, {objc = count(name, "objc"), swift = count(name, "swift")})
    end
    local slashed = {}
    for _, row in ipairs(rows) do
        if row.lang == "objc" and row.api:find("/", 1, true) then
            table.insert(slashed, row.api)
        end
    end
    if #slashed > 0 then
        raise("walk_sdk: %d Objective-C row(s) named after a path, an anonymous enum or struct that went through as a name: %s",
              #slashed, table.concat(slashed, ", ", 1, math.min(3, #slashed)))
    end
    local bundles = bundle_names(sdk_path, target, false)
    if only_set then
        for name in pairs(bundles) do
            if not only_set[name] then
                bundles[name] = nil
            end
        end
    end
    local with_headers = set_of(walked)
    local modules = set_of(swift_found)
    local everything = {}
    for _, set in ipairs({bundles, with_headers, modules}) do
        for name in pairs(set) do
            everything[name] = true
        end
    end
    local no_row_keys, no_row = {}, {}
    for _, name in ipairs(sorted_keys(everything)) do
        if count(name, "objc") == 0 and count(name, "swift") == 0 then
            table.insert(no_row_keys, name)
            no_row[name] = with_headers[name] and "headers, none declares an API clang shows"
                or modules[name] and "a .swiftinterface with no public declaration"
                or "no headers and no .swiftinterface (a .tbd only)"
        end
    end
    local library_set = set_of(libraries)
    local frameworks_walked, no_objc_row = 0, {}
    for _, name in ipairs(walked) do
        if not library_set[name] then
            frameworks_walked = frameworks_walked + 1
            if count(name, "objc") == 0 then
                table.insert(no_objc_row, name)
            end
        end
    end
    local without_rows = {}
    for _, module in ipairs(swift_found) do
        if not swift_with_rows[module] then
            table.insert(without_rows, module)
        end
    end
    local dropped = object({"forward-declaration", "anonymous", "class-floor", "frameworks-walked", "libraries-walked", "no-row",
                            "no-objc-row", "swift-modules-found", "swift-modules-without-rows"},
                           {["forward-declaration"] = forward, anonymous = object(anonymous_order, anonymous), ["class-floor"] = floor,
                            ["frameworks-walked"] = frameworks_walked, ["libraries-walked"] = #libraries,
                            ["no-row"] = object(no_row_keys, no_row), ["no-objc-row"] = no_objc_row,
                            ["swift-modules-found"] = #swift_found, ["swift-modules-without-rows"] = without_rows})
    print("dropped: %s", dumps(dropped))
    local sdk_name = path.filename((sdk_path:gsub("/+$", "")))
    return object({"sdk", "version", "target", "rows", "frameworks", "failed", "libraries", "dropped"},
                  {sdk = sdk_name, version = version, target = target, rows = rows, frameworks = framework_counts,
                   failed = failed, libraries = libraries, dropped = dropped})
end

local function realpath(file)
    local absolute = path.absolute(file)
    local parts = {}
    for part in absolute:gmatch("[^/]+") do
        table.insert(parts, part)
    end
    local resolved = ""
    local index, hops = 1, 0
    while index <= #parts do
        local part = parts[index]
        if part == "." then
            index = index + 1
        elseif part == ".." then
            resolved = path.directory(resolved == "" and "/" or resolved)
            if resolved == "/" then
                resolved = ""
            end
            index = index + 1
        else
            local candidate = resolved .. "/" .. part
            if os.islink(candidate) then
                hops = hops + 1
                if hops > 40 then
                    raise("sdk-introduced.lua: too many symbolic links under %s", file)
                end
                local link = os.readlink(candidate)
                local rest = {}
                for piece in link:gmatch("[^/]+") do
                    table.insert(rest, piece)
                end
                for later = index + 1, #parts do
                    table.insert(rest, parts[later])
                end
                if link:sub(1, 1) == "/" then
                    resolved = ""
                end
                parts, index = rest, 1
            else
                resolved = candidate
                index = index + 1
            end
        end
    end
    return resolved == "" and "/" or resolved
end

local function parse_options(arguments)
    local valued = {sdk = true, out = true, frameworks = true, ["out-dir"] = true, ["macos-sdk"] = true, ["ios-sdk"] = true}
    local flags = {["no-swift"] = true, ["no-include"] = true}
    local options = {}
    local index = 1
    while index <= #arguments do
        local argument = arguments[index]
        local name, value = argument:match("^%-%-([%w-]+)=(.*)$")
        if name == nil then
            name = argument:match("^%-%-([%w-]+)$")
        end
        if name and valued[name] then
            if value == nil then
                index = index + 1
                value = arguments[index]
                if value == nil then
                    raise("sdk-introduced.lua: --%s expects one argument", name)
                end
            end
            options[name] = value
        elseif name and flags[name] and value == nil then
            options[name] = true
        else
            raise("usage: xmake l tools/corpus/sdk-introduced.lua [--sdk SDK] [--out FILE] [--frameworks A,B] [--no-swift] [--no-include] [--out-dir DIR] [--macos-sdk SDK] [--ios-sdk SDK]: unrecognized argument %s", argument)
        end
        index = index + 1
    end
    return options
end

local function split_commas(text)
    local parts = {}
    for part in (text .. ","):gmatch("([^,]*),") do
        table.insert(parts, part)
    end
    return parts
end

local function message_of(errors)
    return tostring(errors)
end

local function coverage_check(corpus, out)
    local candidates = {}
    local tools = os.getenv("REVENANT_TOOLS_DIR")
    if tools and tools ~= "" then
        table.insert(candidates, path.join(tools, "store.json"))
    end
    table.insert(candidates, path.join(corpus, "store.json"))
    local store_path = nil
    for _, candidate in ipairs(candidates) do
        if os.isfile(candidate) then
            store_path = candidate
            break
        end
    end
    if store_path == nil then
        print("FRAMEWORKS coverage check: no store.json found (looked in %s) -- cannot check the index against real corpus demand this run. Not fatal to sdk-introduced.json itself, but this safety net did not run.",
              table.concat(candidates, ", "))
        return
    end
    local store = json.decode(io.readfile(store_path))
    local classes = {}
    for _, app in pairs(store.apps) do
        for _, entry in ipairs(app.demand) do
            if entry.kind == "class" then
                classes[entry.name] = true
            end
        end
    end
    local uncovered = {}
    for _, name in ipairs(sorted_keys(classes)) do
        if out[name] == nil and not KNOWN_NON_SDK[name] then
            table.insert(uncovered, name)
        end
    end
    if #uncovered > 0 then
        print("FRAMEWORKS COVERAGE GAP: %d real corpus class(es) are absent from sdk-introduced.json and not in the known-non-SDK allowlist -- FRAMEWORKS is probably missing a real framework (the FileProvider shape) or that framework's import is silently failing (the CoreTelephony shape). Not dropped, not guessed at:",
              #uncovered)
        for _, name in ipairs(uncovered) do
            print("  %s", name)
        end
    else
        print("FRAMEWORKS coverage check: every one of %d corpus classes is either indexed or a known non-SDK name (%d allowlisted). No gap found this run.",
              #table.keys(classes), #table.keys(KNOWN_NON_SDK))
    end
end

local function catalyst(options, corpus)
    local sdk = options["macos-sdk"] or sw.newest_macos_sdk()
    local ios_sdk = options["ios-sdk"]
    if ios_sdk == nil then
        try {
            function ()
                ios_sdk = workspace.sdk_package(IOS_VERSION)
            end,
            catch {
                function (errors)
                    print("no real iPhoneOS SDK found - the Catalyst-only check is skipped, nothing is dropped by it: %s", message_of(errors))
                end
            }
        }
    end
    if ios_sdk then
        print("real iPhoneOS SDK for the Catalyst-only check: %s", ios_sdk)
    end
    local folder = options["out-dir"] or corpus
    local out, order, unverified = {}, {}, {}
    for _, fw in ipairs(FRAMEWORKS) do
        local rows, surface
        local ok = try {
            function ()
                surface = sw.declared_surface(sdk, fw, CATALYST_TARGET)
                return true
            end,
            catch {
                function (errors)
                    print("%s: skipped (%s)", fw, message_of(errors):sub(1, 240))
                end
            }
        }
        if ok then
            rows = surface.rows
            local real_ios = nil
            if ios_sdk then
                try {
                    function ()
                        real_ios = sw.declared(ios_sdk, fw, IOS_TARGET)
                    end,
                    catch {
                        function (errors)
                            print("%s: iPhoneOS cross-check skipped (%s)", fw, message_of(errors):sub(1, 60))
                        end
                    }
                }
            end
            for _, api in ipairs(surface.order) do
                local kind, version = rows[api].kind, rows[api].version
                if version == nil and real_ios ~= nil and real_ios[api] == nil then
                    table.insert(unverified, {fw, kind, api})
                end
                local shown = nil
                if version then
                    local parts = {}
                    for _, part in ipairs(version) do
                        table.insert(parts, tostring(part))
                    end
                    shown = table.concat(parts, ".")
                end
                local current = out[api]
                if current == nil then
                    table.insert(order, api)
                end
                if current == nil or (current[2] == NULL and shown ~= nil) then
                    out[api] = {kind, shown or NULL, fw}
                end
            end
            print("%s: %d rows", fw, #surface.order)
        end
    end
    io.writefile(path.join(folder, "sdk-introduced.json"), dumps(object(order, out)))
    coverage_check(corpus, out)
    table.sort(unverified, function (a, b)
        for index = 1, 3 do
            if a[index] ~= b[index] then
                return byteorder.less(a[index], b[index])
            end
        end
        return false
    end)
    local lines = {"framework\tkind\tapi\treason\n"}
    for _, row in ipairs(unverified) do
        table.insert(lines, string.format("%s\t%s\t%s\t%s\n", row[1], row[2], row[3], UNVERIFIED_REASON))
    end
    io.writefile(path.join(folder, "sdk-introduced-unverified.tsv"), table.concat(lines))
    print("SDK-DONE total %d unversioned-and-unverified %d (listed, not dropped - see corpus/sdk-introduced-unverified.tsv)", #order, #unverified)
end

function main(...)
    local options = parse_options({...})
    local corpus = workspace.corpus()
    print("surface-diff: %s", path.absolute(path.join(os.scriptdir(), "surface_walk.lua")))
    if options.sdk then
        local result = walk_sdk(realpath(options.sdk), options.frameworks and split_commas(options.frameworks) or nil,
                                not options["no-swift"], not options["no-include"])
        local out = options.out or path.join(corpus, string.format("sdk-%s-declared.json", result.version))
        io.writefile(out, dumps(result))
        print("wrote %d rows, %d failed header(s), to %s", #result.rows, #result.failed, out)
        sw.cleanup()
        return
    end
    catalyst(options, corpus)
    sw.cleanup()
end
