local generate = import("generate", {rootdir = os.scriptdir(), anonymous = true})
local sources = import("implemented", {rootdir = os.scriptdir(), anonymous = true})

function main()
    local state = generate.prepare()
    local keys = sources.from_objects()
    local total_implemented, total_members = 0, 0
    for _, framework in ipairs(state.frameworks) do
        local implemented, members = 0, 0
        for _, row in ipairs(generate.in_scope_rows(state, framework)) do
            if row.kind ~= "enum constant" then
                members = members + 1
                if generate.is_implemented(keys, framework, row) then
                    implemented = implemented + 1
                end
            end
        end
        total_implemented = total_implemented + implemented
        total_members = total_members + members
        print(string.format("%-28s implemented %d of %d", framework.name, implemented, members))
    end
    print(string.format("%-28s implemented %d of %d", "total", total_implemented, total_members))
end
