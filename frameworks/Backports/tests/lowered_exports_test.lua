local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

function main()
    local src = path.absolute(path.join(os.scriptdir(), "..", "src"))
    local members = lowered.read_members()
    local defined, implemented = lowered.constants_defined_in(src), lowered.classes_implemented_in(src)
    local enums = members.enums or {}
    local problems = {}
    for name in pairs(members.globals) do
        if not defined[name] and not enums[name] then
            table.insert(problems, "global " .. name .. " is in the member set, but no Backports source defines it and the SDK does not declare it as an enum value")
        end
    end
    for class in pairs(members.classes) do
        if not implemented[class] then
            table.insert(problems, "class " .. class .. " is in the member set, but no Backports source implements it")
        end
    end
    table.sort(problems)
    assert(#problems == 0, "the member set names what Backports does not export:\n  " .. table.concat(problems, "\n  "))
end
