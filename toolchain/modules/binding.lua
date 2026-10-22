import("byteorder", {rootdir = os.scriptdir()})

local MARK = "revenant.apple-ios"

function mark(target)
    target:data_set(MARK, true)
end

function check(targets)
    import("core.project.project")
    local unbound = {}
    for name, target in pairs(targets or project.targets()) do
        if target:is_plat("iphoneos") and target:kind() ~= "phony" and not target:data(MARK) then
            table.insert(unbound, name)
        end
    end
    if #unbound > 0 then
        byteorder.sort(unbound)
        raise("%s builds for iphoneos without the revenant apple-ios toolchain: add_rules(\"@addon/revenant/apple-ios\") to each, or a revenant rule that depends on it", table.concat(unbound, ", "))
    end
end
