local frameworks = {"JavaScriptCore", "WebCore", "WebKitLegacy"}
local staged = {JavaScriptCore = "JavaScriptCore", WebCore = "WebCore", WebKitLegacy = "WebKit"}
local pin = path.join(os.scriptdir(), "..", "..", "tests", "data", "carry-symbols.txt")

local header = [[
# Symbols this port's frameworks depend on and provide, as of the last
# build known to load on the device. tools/symbol-check.lua compares a
# fresh build against this, and so does every build of the engine.
#
# undefined <framework> <symbol>  something iOS 6 must already have.
#   A new one means an upstream change reached for API this system may
#   not have, and dyld kills the process at load with no crash log.
# class <framework> <symbol>      an Objective-C class UIKit and Safari
#   link by name. Losing one is the same death, from the other side.
]]

local function nm(arguments, binary)
    return os.iorunv("xcrun", table.join({"nm"}, arguments, {binary}))
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

function surface(build)
    local entries = {}
    for _, framework in ipairs(frameworks) do
        local file = binary(build, framework)
        if not file then
            raise("there is no %s.framework under %s to read the symbols of", framework, build)
        end
        for line in nm({"-u"}, file):gmatch("[^\n]+") do
            local symbol = line:trim()
            if symbol ~= "" then
                entries["undefined " .. framework .. " " .. symbol] = true
            end
        end
        for line in nm({"-gU"}, file):gmatch("[^\n]+") do
            local symbol = line:match("(%S+)%s*$")
            if symbol and symbol:startswith("_OBJC_CLASS_$_") then
                entries["class " .. framework .. " " .. symbol] = true
            end
        end
    end
    return entries
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
    local current = surface(build)
    local sorted = table.orderkeys(current)
    io.writefile(pin, header .. table.concat(sorted, "\n") .. "\n")
    return #sorted
end

function compare(build)
    local current, baseline = surface(build), pinned()
    local new_imports, lost_classes = {}, {}
    for entry in pairs(current) do
        if not baseline[entry] and entry:startswith("undefined ") then
            table.insert(new_imports, entry)
        end
    end
    for entry in pairs(baseline) do
        if not current[entry] and entry:startswith("class ") then
            table.insert(lost_classes, entry)
        end
    end
    table.sort(new_imports)
    table.sort(lost_classes)
    return new_imports, lost_classes
end

function verify(build)
    local new_imports, lost_classes = compare(build)
    if #new_imports > 0 or #lost_classes > 0 then
        raise("the frameworks' symbols changed against carry-symbols.txt: %d new undefined symbols iOS 6 may not have (%s), %d Objective-C classes no longer exported (%s); check each against the device, then ./xmakew l frameworks/WebKit/tools/symbol-check.lua --pin BUILD",
              #new_imports, table.concat(table.slice(new_imports, 1, 5), ", "), #lost_classes, table.concat(table.slice(lost_classes, 1, 5), ", "))
    end
end
