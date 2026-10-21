import("core.project.config")
import("core.project.project")

local tree = import("lib.tree", {rootdir = os.scriptdir(), anonymous = true})

local USAGE = [==[usage: ./xmakew l frameworks/SwiftUI/tools/api_surface.lua [prepare | apple [MODULE...]]
  prepare   copy the SwiftUI framework of the iOS 16.4 SDK with its interface patched, for swift-api-digester
  apple     write Apple's 26.2 surface, one row per declaration, to apple-26-surface.tsv in the run folder, which
            api_invented.lua reads; it builds the surftool of tests/surface first
  (none)    prepare if needed, then dump Apple's and this module's API, list the gaps (api_diff.lua) and the
            public names Apple's 26.2 does not declare (api_invented.lua); STRICT=1 makes an invented name a failure.
Run it from the top of revenant, configured for iphoneos, after ./xmakew build -P . SwiftUI.]==]

local SDK_VERSION = "16.4"
local APPLE_ENTRY = {"Swift", "SwiftUI", "SwiftUICore", "Foundation", "CoreFoundation", "Combine", "Observation", "CoreGraphics", "UIKit"}
local PATCH_OPENER = 'os_log(.fault, log: Log.runtimeIssuesLog, """\n'
local PATCH_REPLACEMENT = "_ = Log.runtimeIssuesLog"

local function framework()
    return path.join(tree.run("fw"), "SwiftUI.framework")
end

local function closing_end(s, body)
    local line_start = body
    while line_start <= #s do
        local newline = string.find(s, "\n", line_start, true)
        local line_end = newline and newline - 1 or #s
        local line = string.sub(s, line_start, line_end)
        local _, close = string.find(line, '^%s*"""%)')
        if close then
            return line_start + close - 1
        end
        if not newline then
            break
        end
        line_start = newline + 1
    end
    return nil
end

local function patch(file)
    local s = io.readfile(file)
    local from = 1
    while true do
        local at = string.find(s, PATCH_OPENER, from, true)
        if not at then
            break
        end
        local finish = closing_end(s, at + #PATCH_OPENER)
        if finish then
            io.writefile(file, string.sub(s, 1, at - 1) .. PATCH_REPLACEMENT .. string.sub(s, finish + 1))
            return
        end
        from = at + 1
    end
    raise("the os_log call this patches was not found in %s", file)
end

local function prepare()
    local sdk = tree.workspace().sdk_package(SDK_VERSION)
    local copy = framework()
    os.tryrm(copy)
    os.cp(path.join(sdk, "System", "Library", "Frameworks", "SwiftUI.framework"), copy)
    patch(path.join(copy, "Modules", "SwiftUI.swiftmodule", "arm64-apple-ios.swiftinterface"))
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
    if lua("api_diff.lua", {path.join(out, "apple.json"), path.join(out, "ours.json")}, gaps) ~= 0 then
        raise("api_diff.lua failed")
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
    local status = lua("api_invented.lua", {path.join(out, "ours.json")}, invented)
    if status ~= 0 and status ~= 1 then
        os.rm(invented)
        raise("api_invented.lua failed with %s, so there is no count of invented names", status)
    end
    local count = 0
    for line in io.readfile(invented):gmatch("[^\n]+") do
        count = count + 1
    end
    print("api_surface: %d public names here that Apple's 26.2 does not declare (see %s); STRICT=1 makes this a failure", count, invented)
    if status ~= 0 then
        os.exit(status)
    end
end

local function surftool()
    local project = tree.root("tests", "surface")
    local build = tree.run("surface", "build")
    local envs = {XMAKE_CONFIGDIR = tree.run("surface", "config")}
    for _, argv in ipairs({{"f", "-P", project, "-o", build, "-y"}, {"build", "-P", project}}) do
        os.execv(os.programfile(), argv, {envs = envs})
    end
    local tool = path.join(build, "macosx", "arm64", "release", "surftool")
    if not os.isfile(tool) then
        raise("the build of %s left no surftool at %s", project, tool)
    end
    return tool
end

local function interfaces(sdk, modules)
    local found = {}
    for _, name in ipairs(modules) do
        local folders = os.dirs(path.join(sdk, "**", name .. ".swiftmodule"))
        table.sort(folders)
        if #folders == 0 then
            raise("the SDK at %s has no %s.swiftmodule", sdk, name)
        end
        local files = os.files(path.join(folders[1], "*.swiftinterface"))
        table.sort(files)
        table.join2(found, files)
    end
    return found
end

local function apple(modules)
    local sdk = tree.sdk()
    local tool = surftool()
    local out = path.join(tree.run("api"), "apple-26-surface.tsv")
    local file = io.open(out, "w")
    os.execv(tool, table.join({sdk}, interfaces(sdk, modules)), {stdout = file})
    file:close()
    print("%s written", out)
end

function main(action, ...)
    if action == "prepare" then
        prepare()
    elseif action == "apple" then
        apple(#{...} > 0 and {...} or APPLE_ENTRY)
    elseif action == nil then
        surface()
    else
        raise(USAGE)
    end
end
