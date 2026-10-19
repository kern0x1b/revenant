-- The removed-override ceiling (review r4 G11; coordinator ruling G11). A removed override is a registry override whose symbol the 26.2
-- spec no longer holds: a WARN, not a failure, because the backports exist for exactly the APIs that 26.2 removed or deprecated and 6.1.3
-- carries. Its count must not grow: the total over every framework is held to tests/gen/removed-overrides.tsv, one row per framework
-- that has removed overrides. A total above the ceiling fails and names each framework that grew; a total below it passes, and the ceiling
-- is lowered in the change that removes the overrides. The ceiling is derived from a check run: `xmake l tools/gen.lua check --all --tree .`
-- prints one "check <F>: ... removed overrides (warned) N, ..." line per framework; its rows are the frameworks with N > 0, by name.
-- Run: xmake l tests/gen/removed_ceiling_test.lua (exits 1 on failure).

local ROOT = path.absolute(path.join(os.scriptdir(), "..", ".."))
local TOOLS = path.join(ROOT, "tools")
local CEILING = path.join(ROOT, "tests", "gen", "removed-overrides.tsv")

function main()
    local cmd = import("gen.cmd_check", {rootdir = TOOLS, anonymous = true})
    local tsv = import("gen.tsv", {rootdir = TOOLS, anonymous = true})
    local files = import("gen.files", {rootdir = TOOLS, anonymous = true})
    local order = import("gen.order", {rootdir = TOOLS, anonymous = true})

    local text = files.read_text(CEILING)
    if text == nil then
        print("removed ceiling FAIL: " .. CEILING .. " is missing")
        os.exit(1)
    end
    local ceiling, ceiling_total = {}, 0
    for _, r in ipairs(tsv.records(text)) do
        ceiling[r.framework] = tonumber(r.removed)
        ceiling_total = ceiling_total + tonumber(r.removed)
    end

    local counts, total = cmd.removed_counts(ROOT, "26.2")
    if total > ceiling_total then
        local names = {}
        for fw in pairs(counts) do
            table.insert(names, fw)
        end
        table.sort(names, order.less)
        for _, fw in ipairs(names) do
            if counts[fw] > (ceiling[fw] or 0) then
                print(string.format("removed ceiling FAIL: %s has %d removed overrides, the ceiling is %d",
                    fw, counts[fw], ceiling[fw] or 0))
            end
        end
        print(string.format("removed ceiling FAIL: %d removed overrides in total, the ceiling is %d", total, ceiling_total))
        os.exit(1)
    end
    print(string.format("removed ceiling: OK (%d removed overrides, ceiling %d)", total, ceiling_total))
end
