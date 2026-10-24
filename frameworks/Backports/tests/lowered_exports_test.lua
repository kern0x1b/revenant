local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

function main()
    local src = path.absolute(path.join(os.scriptdir(), "..", "src"))
    local members = lowered.read_members()
    local defined, implemented = {}, {}
    for _, folder in ipairs(os.dirs(path.join(src, "*"))) do
        for _, pattern in ipairs({"**.m", "**.mm", "**.c", "**.h"}) do
            for _, file in ipairs(os.files(path.join(folder, pattern))) do
                for line in io.readfile(file):gmatch("[^\n]*") do
                    local class = line:match("^@implementation%s+REVENANT_ALIAS_CLASS%(([%w_]+)%)") or line:match("^@implementation%s+([%w_]+)")
                    if class then
                        implemented[class] = true
                    end
                    local name = lowered.global_of(line)
                    if name then
                        defined[name] = true
                    end
                end
            end
        end
    end
    local enums = lowered.later_constants(workspace.sdk())
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
