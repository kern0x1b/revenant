-- objc-init-members.lua - which of a class's own method lists carry -init and +new, read out of a held release.
--
--   xmake l tools/objc-init-members.lua <release> <architecture> <Class>...
--
-- The release is a folder under the held dyld root (for example 16.0), and the architecture is the cache
-- held for it (arm64e for 16.0). apple.objc.inventory() keys every selector with a leading `-`, class methods
-- included, so the instance list is asked for `-init` and the metaclass list for `-init` and `-new`. NSObject
-- is always printed first as the control: it defines both, and a probe that answered "neither" for it would be
-- broken, not a measurement.
--
-- A class that prints neither selector inherits NSObject's pair, and a caller that reaches them gets the
-- NSObject answer. `own` is what the class's own list carries; `super` is its superclass in that release.
--
-- Read-only: the cache is opened and closed by apple.objc, and nothing is written.

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
