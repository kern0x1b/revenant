import("core.base.json")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

local ROOT = path.absolute(path.join(os.scriptdir(), "..", ".."))
local REGISTRY = path.join(ROOT, "packages", "a", "apple-backports", "registry", "Intents")
local CLASSES = path.join(ROOT, "packages", "a", "apple-backports", "Intents")

local function sources()
    local found = {}
    for _, file in ipairs(os.files(path.join(CLASSES, "IN*.m"))) do
        table.insert(found, file)
    end
    table.insert(found, path.join(CLASSES, "RevenantIntents100.m"))
    table.insert(found, path.join(CLASSES, "RevenantIntents110.m"))
    byteorder.sort(found)
    return found
end

local HEADER = [==[
// init-classes.inc - the class population this harness keeps honest, with the properties the port
// synthesizes for each. Generated; the two derivations are:
//
//   the class list, from the registry - every status `implemented` row that names `-[<class> init]`,
//   read from packages/a/apple-backports/registry/Intents/ios*.json by registry_classes() in
//   tools/intents/gen-init-classes.lua:
//
//   the properties, from the port's own objects - the `@synthesize NAME = _NAME;` lines inside
//   each class's @implementation in packages/a/apple-backports/Intents/IN*.m, RevenantIntents100.m
//   and RevenantIntents110.m, read by synthesised() in the same file:
//
//     xmake l tools/intents/gen-init-classes.lua -o tests/backports/host/intents-init/init-classes.inc
//
// The class list is read from the registry and not from the SDK headers, because the claim under
// test is the registry's: the header says which classes mark -init NS_UNAVAILABLE, the registry
// says which rows claim the port answers one, and this harness measures the second.
//
// The properties are read from the port and not from the runtime, because those are the ones the
// row claims stay nil. Asking the runtime instead yields NSObject's hash/description/debugDescription/
// superclass repeated four times over plus the framework's private accessors - measured, 48
// properties for INActivateCarSignalIntentResponse - which is neither the population the claim is
// about nor safe to call. A class that synthesizes nothing is listed with an empty set and its
// -init is measured on the IMP and the call alone.
//
// A class added to the registry and not here is invisible to the harness. run.sh prints the
// registry's own count of these rows beside this file's, and fails when the two disagree, which is
// what keeps this file honest: both this file and expected.txt are written from here, so comparing
// them with each other would only show that they agree.
]==]

local function registry_classes()
    local names = {}
    for _, file in ipairs(os.files(path.join(REGISTRY, "ios*.json"))) do
        local document = json.decode(io.readfile(file, {encoding = "binary"}))
        local entries = document.entries or document
        for _, entry in ipairs(entries) do
            if entry.status == "implemented" then
                local name = entry.api:match("^%-%[([%w_]+) init%]$")
                if name ~= nil then
                    names[name] = true
                end
            end
        end
    end
    return names
end

local function synthesised()
    local properties = {}
    local owner = nil
    for _, file in ipairs(sources()) do
        if os.isfile(file) then
            for line in io.lines(file) do
                local implementation = line:match("^@implementation%s+([%w_]+)%s*$")
                local synthesize = line:match("^%s*@synthesize%s+[%w_]+%s*=%s*_[%w_]+%s*;")
                if implementation then
                    owner = implementation
                elseif synthesize and owner then
                    local name = line:match("^%s*@synthesize%s+([%w_]+)")
                    properties[owner] = properties[owner] or {}
                    properties[owner][name] = true
                end
            end
        end
    end
    return properties
end

function main(...)
    local out = "-"
    local arguments = {...}
    if arguments[1] == "-o" and arguments[2] ~= nil then
        out = arguments[2]
    elseif #arguments > 0 then
        raise("usage: xmake l tools/intents/gen-init-classes.lua [-o PATH]")
    end

    local names = registry_classes()
    local properties = synthesised()
    local sorted_names = {}
    for name in pairs(names) do
        table.insert(sorted_names, name)
    end
    byteorder.sort(sorted_names)

    local empty = {}
    for _, name in ipairs(sorted_names) do
        local held = properties[name]
        local none = true
        for _ in pairs(held or {}) do
            none = false
        end
        if none then
            table.insert(empty, name)
        end
    end

    local header = HEADER:gsub("\n$", "")
    local lines = {header}
    table.insert(lines, "//")
    table.insert(lines, string.format("// %d classes, %d of which synthesize no property: %s",
                                      #sorted_names, #empty, table.concat(empty, ", ")))
    table.insert(lines, "")
    for _, name in ipairs(sorted_names) do
        local held = {}
        for property in pairs(properties[name] or {}) do
            table.insert(held, property)
        end
        byteorder.sort(held)
        local quoted = {}
        for _, one in ipairs(held) do
            table.insert(quoted, '"' .. one .. '", ')
        end
        table.insert(lines, string.format('    { "%s", { %sNULL } },', name, table.concat(quoted)))
    end
    local text = table.concat(lines, "\n") .. "\n"
    if out == "-" then
        io.write(text)
        return
    end
    io.writefile(out, text, {encoding = "binary"})
    print(string.format("init-classes.inc: %d classes, %d with no property", #sorted_names, #empty))
end
