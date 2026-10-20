import("core.project.config")
import("core.project.project")

local tree = import("lib.tree", {rootdir = os.scriptdir(), anonymous = true})

local USAGE = [[usage: ./xmakew l frameworks/SwiftUI/tools/api-surface.lua [prepare]
  prepare   copy the SwiftUI framework of the iOS 16.4 SDK with its interface patched, for swift-api-digester
  (none)    prepare if needed, then dump Apple's and this module's API, list the gaps (api-diff.lua) and the
            public names Apple's 26.2 does not declare (api-invented.lua); STRICT=1 makes an invented name a failure.
Run it from the top of revenant, configured for iphoneos, after ./xmakew build -P . SwiftUI.]]

local SDK_VERSION = "16.4"

local function framework()
    return path.join(tree.run("fw"), "SwiftUI.framework")
end

local function prepare()
    local sdk = tree.workspace().sdk_package(SDK_VERSION)
    local copy = framework()
    os.tryrm(copy)
    os.cp(path.join(sdk, "System", "Library", "Frameworks", "SwiftUI.framework"), copy)
    local interface = path.join(copy, "Modules", "SwiftUI.swiftmodule", "arm64-apple-ios.swiftinterface")
    os.execv(os.programfile(), {"l", path.join(os.scriptdir(), "patch-interface.lua"), interface})
    print("%s ready", copy)
end

local function module_flags()
    config.load()
    local swiftui = project.target("SwiftUI")
    if not swiftui or not swiftui:pkg("swift-runtime") then
        raise("the project has no SwiftUI target with its packages: run this from the top of revenant, configured with ./xmakew f -P . -p iphoneos -a armv7\n%s", USAGE)
    end
    local runtime = swiftui:pkg("swift-runtime")
    local swiftc = assert(table.wrap((runtime:envs() or {}).SWIFT_EXEC)[1], "swift-runtime names no compiler; reinstall it")
    local flags = {"-resource-dir", path.join(runtime:installdir(), "lib", "swift")}
    for _, target in ipairs(table.join({swiftui}, swiftui:orderdeps())) do
        local modules = path.join(target:autogendir(), "swift")
        if os.isdir(modules) then
            table.join2(flags, {"-I", modules})
        end
        for _, folder in ipairs(table.wrap(target:get("includedirs", {interface = true}))) do
            table.join2(flags, {"-I", folder})
        end
    end
    if not os.isdir(path.join(swiftui:autogendir(), "swift", "SwiftUI.swiftmodule")) then
        raise("%s holds no SwiftUI.swiftmodule: build it first, ./xmakew build -P . SwiftUI", path.join(swiftui:autogendir(), "swift"))
    end
    return path.join(path.directory(swiftc), "swift-api-digester"), flags
end

local function lua(script, arguments, output)
    local file = io.open(output, "w")
    local status = os.execv(os.programfile(), table.join({"l", path.join(os.scriptdir(), script)}, arguments),
                            {stdout = file, try = true})
    file:close()
    return status
end

local function surface()
    if not os.isdir(framework()) then
        prepare()
    end
    local digester, flags = module_flags()
    local sdk = tree.workspace().sdk_package(SDK_VERSION)
    local out = tree.run("api")
    local cache = path.join(out, "mc")
    local common = {"-dump-sdk", "-module", "SwiftUI", "-sdk", sdk, "-swift-version", "5", "-avoid-tool-args", "-module-cache-path", cache}
    os.execv(digester, table.join(common, {"-o", path.join(out, "apple.json"), "-target", "arm64-apple-ios" .. SDK_VERSION,
                                           "-F", tree.run("fw")}, {flags[1], flags[2]}))
    os.execv(digester, table.join(common, {"-o", path.join(out, "ours.json"), "-target", "armv7-apple-ios6.0"}, flags))
    local gaps = path.join(out, "gaps.txt")
    if lua("api-diff.lua", {path.join(out, "apple.json"), path.join(out, "ours.json")}, gaps) ~= 0 then
        raise("api-diff.lua failed")
    end
    local counts = {}
    for line in io.readfile(gaps):gmatch("[^\n]+") do
        local owner = line:match("^([^\t]*)")
        counts[owner] = (counts[owner] or 0) + 1
    end
    local owners = table.orderkeys(counts)
    table.sort(owners, function (a, b)
        if counts[a] ~= counts[b] then
            return counts[a] > counts[b]
        end
        return a > b
    end)
    for i = 1, math.min(#owners, 30) do
        print("%7d %s", counts[owners[i]], owners[i])
    end
    local invented = path.join(out, "invented.txt")
    local status = lua("api-invented.lua", {path.join(out, "ours.json")}, invented)
    if status ~= 0 and status ~= 1 then
        os.rm(invented)
        raise("api-invented.lua failed with %s, so there is no count of invented names", status)
    end
    local count = 0
    for line in io.readfile(invented):gmatch("[^\n]+") do
        count = count + 1
    end
    print("api-surface: %d public names here that Apple's 26.2 does not declare (see %s); STRICT=1 makes this a failure", count, invented)
    if status ~= 0 then
        os.exit(status)
    end
end

function main(action)
    if action == "prepare" then
        prepare()
    elseif action == nil then
        surface()
    else
        raise(USAGE)
    end
end
