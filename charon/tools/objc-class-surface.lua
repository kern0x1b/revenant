local modules = path.join(os.scriptdir(), "..", "modules")
local objc = import("apple.objc", {rootdir = modules, anonymous = true})
local dyld = import("apple.dyld", {rootdir = modules, anonymous = true})
local byteorder = import("byteorder", {rootdir = modules, anonymous = true})

local function own_list(methods)
    local out = {}
    for selector in pairs(methods or {}) do
        table.insert(out, selector)
    end
    byteorder.sort(out)
    return out
end

local function describe(found, name)
    local class = found.classes[name]
    if not class then
        return string.format("%s: not in this release", name)
    end
    local lines = {string.format("%s: super=%s", name, tostring(class.superclass))}
    for _, selector in ipairs(own_list(class.instance)) do
        table.insert(lines, "  " .. selector)
    end
    for _, selector in ipairs(own_list(class.class)) do
        table.insert(lines, "  " .. selector .. " (class)")
    end
    return table.concat(lines, "\n")
end

function main(release, architecture, ...)
    if not release or not architecture then
        raise("usage: objc-class-surface.lua <release> <architecture> <Class>...")
    end
    local source = dyld.held_source(path.join(dyld.root(), release), architecture)
    if not source then
        raise("no %s cache held for iOS %s", architecture, release)
    end
    local found = objc.inventory(source)
    print("source " .. source)
    local control = found.classes["NSObject"]
    print(string.format("NSObject (control): %d instance selectors, %d class selectors", #own_list(control.instance),
        #own_list(control.class)))
    for _, name in ipairs({...}) do
        print(describe(found, name))
    end
end
