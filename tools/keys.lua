import("core.base.task")
import("private.action.require.impl.package")

local prebuilt = import("@addon.revenant.prebuilt", {anonymous = true})

local HEAVY = {"llvm", "swift", "swift-bootstrap", "swift-runtime", "libcxx", "apple-compat", "iphoneos-sdk", "ld64"}

function main(...)
    task.run("config", {}, {disable_dump = true})
    local names = {...}
    if #names == 0 then
        names = HEAVY
    end
    local requires, extra = {}, {}
    for _, name in ipairs(names) do
        requires[#requires + 1] = "revenant@" .. name
        extra["revenant@" .. name] = {system = false}
    end
    local instances = package.load_packages(requires, {requires_extra = extra})
    for _, name in ipairs(names) do
        local found = false
        for _, instance in ipairs(instances) do
            if instance:name() == name and instance:is_toplevel() then
                print("%s %s %s", name, instance:version_str() or "latest", prebuilt.key(instance))
                found = true
                break
            end
        end
        if not found then
            raise("keys: the project requires no package %s", name)
        end
    end
end
