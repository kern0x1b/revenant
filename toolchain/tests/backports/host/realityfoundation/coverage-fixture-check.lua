local json = import("core.base.json")

local function load(file)
    return import(path.basename(file):gsub("%.lua$", ""), {rootdir = path.directory(file), anonymous = true})
end

function main(fixture_path, coverage_path, registry)
    if not (fixture_path and coverage_path and registry) then
        io.stderr:write("usage: coverage-fixture-check.lua <fixture.lua> <coverage.lua> <registry.json>\n")
        os.exit(2)
    end
    local fixture = load(fixture_path)
    local coverage = load(coverage_path)
    local checks = coverage.subjects(path.join(path.directory(coverage_path), "main.swift"))
    local rows = {}
    for _, entry in ipairs(json.loadfile(registry).entries) do
        if entry.status == "implemented" then
            table.insert(rows, entry)
        end
    end
    local satisfied, unsatisfied = 0, {}
    for _, entry in ipairs(rows) do
        local hit = nil
        for _, token in ipairs(coverage.tokens(entry.api)) do
            for _, check in ipairs(checks) do
                if check[2]:lower():find(token:lower(), 1, true) then
                    hit = {token, check[1], check[2]}
                    break
                end
            end
            if hit then
                break
            end
        end
        if hit == nil then
            hit = {"decl only", nil, nil}
        end
        local said = entry.source or ""
        local should = fixture.what_this_row_should_say(hit)
        if said == should then
            satisfied = satisfied + 1
        else
            table.insert(unsatisfied, {entry.api, said, should})
        end
    end
    print(string.format("%d of %d rows the pre-repair guard accepts", satisfied, #rows))
    for i = 1, math.min(3, #unsatisfied) do
        local row = unsatisfied[i]
        print(string.format("  %s\n    says: %s\n    the fixture expects: %s", row[1]:sub(1, 64), row[2]:sub(1, 100), row[3]:sub(1, 100)))
    end
    os.exit(#unsatisfied == 0 and 0 or 1)
end
