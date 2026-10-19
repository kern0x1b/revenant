local modules = path.join(os.scriptdir(), "..", "modules")
local objc = import("apple.objc", {rootdir = modules, anonymous = true})
local dyld = import("apple.dyld", {rootdir = modules, anonymous = true})

local function describe(found, name)
    local class = found.classes[name]
    if not class then
        return string.format("%-44s not in this release", name)
    end
    local instance_init = class.instance["-init"] and "yes" or "no"
    local class_init = class.class["-init"] and "yes" or "no"
    local class_new = class.class["-new"] and "yes" or "no"
    return string.format("%-44s super=%-28s -init=%-3s +init=%-3s +new=%-3s", name, tostring(class.superclass), instance_init, class_init, class_new)
end

function main(release, architecture, ...)
    if not release or not architecture then
        raise("usage: objc-init-members.lua <release> <architecture> <Class>...")
    end
    local source = dyld.held_source(path.join(dyld.root(), release), architecture)
    if not source then
        raise("no %s cache held for iOS %s", architecture, release)
    end
    local found = objc.inventory(source)
    print("source " .. source)
    print(describe(found, "NSObject"))
    for _, name in ipairs({...}) do
        print(describe(found, name))
    end
end
