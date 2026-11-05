local frameworks = {"JavaScriptCore", "WebCore", "WebKitLegacy"}
local staged = {JavaScriptCore = "JavaScriptCore", WebCore = "WebCore", WebKitLegacy = "WebKit"}
local pin = path.join(os.scriptdir(), "..", "..", "tests", "data", "carry-symbols.txt")
local RELEASE, ARCHITECTURE = "6.0", "armv7"

local header = [[
# Symbols this port's frameworks depend on and provide, as of the last
# build known to load on the device. tools/symbol_check.lua compares a
# fresh build against this, and so does every build of the engine.
#
# undefined <framework> <symbol>  an import the device has been checked against. A new
#   import is not added here: the gate judges it against the iOS 6.0 cache and accepts it
#   when the library it names exports it there, and rejects it otherwise. A rejected import
#   joins this list only after a device check that resolves it.
# class <framework> <symbol>      an Objective-C class UIKit and Safari
#   link by name. Losing one is the same death, from the other side.
]]

local function nm(arguments, binary)
    return os.iorunv("xcrun", table.join({"nm"}, arguments, {binary}))
end

local function toolchain(name)
    return import("@addon.revenant." .. name, {anonymous = true})
end

function binary(build, framework)
    local as = staged[framework]
    for _, candidate in ipairs({path.join(build, framework .. ".framework", framework),
                                path.join(build, "usr", "lib", "rev-fw", as .. ".framework", as)}) do
        if os.isfile(candidate) then
            return candidate
        end
    end
end

local function cache_source()
    local dyld = toolchain("apple.dyld")
    local source = dyld.held_source(path.join(dyld.root(), RELEASE), ARCHITECTURE)
    if not source then
        raise("the imports of this %s build cannot be checked without the libraries of iOS %s; run xmake firmware --arch=%s fetch %s", ARCHITECTURE, RELEASE, ARCHITECTURE, RELEASE)
    end
    return source
end

function judge(build, cachefile)
    local dyld = toolchain("apple.dyld")
    local files, paths, defined, classes = {}, {}, {}, {}
    for _, framework in ipairs(frameworks) do
        local file = binary(build, framework)
        if not file then
            raise("there is no %s.framework under %s to read the symbols of", framework, build)
        end
        table.insert(files, {framework = framework, file = file})
        table.insert(paths, file)
        for line in nm({"-gU"}, file):gmatch("[^\n]+") do
            local symbol = line:match("(%S+)%s*$")
            if symbol then
                defined[symbol] = true
                if symbol:startswith("_OBJC_CLASS_$_") then
                    classes["class " .. framework .. " " .. symbol] = true
                end
            end
        end
    end
    local verdicts = dyld.import_verdicts(cachefile or cache_source(), paths)
    local imports = {}
    for _, item in ipairs(files) do
        for _, verdict in ipairs(verdicts[item.file]) do
            if not defined[verdict.name] then
                verdict.framework = item.framework
                verdict.entry = "undefined " .. item.framework .. " " .. verdict.name
                table.insert(imports, verdict)
            end
        end
    end
    return imports, classes
end

function pinned()
    local entries = {}
    for line in io.readfile(pin):gmatch("[^\n]+") do
        if not line:startswith("#") then
            entries[line] = true
        end
    end
    return entries
end

function write_pin(build)
    local report = compare(build)
    local kept = {}
    for entry in pairs(pinned()) do
        if entry:startswith("undefined ") then
            kept[entry] = true
        end
    end
    for _, verdict in ipairs(report.rejected) do
        kept[verdict.entry] = true
    end
    for entry in pairs(report.classes) do
        kept[entry] = true
    end
    local sorted = table.orderkeys(kept)
    io.writefile(pin, header .. table.concat(sorted, "\n") .. "\n")
    return #sorted
end

function compare(build, cachefile)
    local imports, classes = judge(build, cachefile)
    local baseline = pinned()
    local report = {new = {}, accepted = {}, rejected = {}, lost = {}, classes = classes}
    for _, verdict in ipairs(imports) do
        if not baseline[verdict.entry] then
            table.insert(report.new, verdict)
            table.insert(verdict.accepted and report.accepted or report.rejected, verdict)
        end
    end
    for entry in pairs(baseline) do
        if entry:startswith("class ") and not classes[entry] then
            table.insert(report.lost, entry)
        end
    end
    for _, key in ipairs({"new", "accepted", "rejected"}) do
        table.sort(report[key], function (a, b) return a.entry < b.entry end)
    end
    table.sort(report.lost)
    return report
end

function verify(build, cachefile)
    local report = compare(build, cachefile)
    print(string.format("symbols: %d imports the pin does not list, %d accepted and %d rejected by the iOS %s cache",
                        #report.new, #report.accepted, #report.rejected, RELEASE))
    for _, verdict in ipairs(report.accepted) do
        print(string.format("  accepted %s, exported from %s", verdict.entry, verdict.library))
    end
    for _, verdict in ipairs(report.rejected) do
        print(string.format("  rejected %s: %s", verdict.entry, verdict.reason))
    end
    for _, entry in ipairs(report.lost) do
        print("  lost " .. entry)
    end
    if #report.rejected > 0 or #report.lost > 0 then
        local rejected = {}
        for _, verdict in ipairs(report.rejected) do
            table.insert(rejected, verdict.entry)
        end
        raise("the frameworks' symbols changed against carry-symbols.txt: %d imports iOS %s does not export (%s), %d Objective-C classes no longer exported (%s); check each against the device, then ./xmakew l frameworks/WebKit/tools/symbol_check.lua --pin BUILD",
              #report.rejected, RELEASE, table.concat(table.slice(rejected, 1, 5), ", "), #report.lost, table.concat(table.slice(report.lost, 1, 5), ", "))
    end
end
