-- The targets of the SDK entries that have no declaration shard of their own (tools/gen/targets.lua, read from tools/found/no-shard.tsv
-- and the foundation's classification in tools/found/config): every registry entry of Accelerate is declared by a nested shard that its
-- umbrella names (no-shard.tsv), and the Graphics product's members (products.tsv) are SDK frameworks with shards and own no registry rows.
-- It reads only committed data of this checkout. Run: xmake l tests/gen/targets_test.lua (exits 1 on failure).

local ROOT = path.absolute(path.join(os.scriptdir(), "..", ".."))
local TOOLS = path.join(ROOT, "tools")

function main()
    local failures, count = 0, 0
    local function check(ok, label)
        count = count + 1
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end
    local targets = import("gen.targets", {rootdir = TOOLS, anonymous = true})
    local headers = import("gen.headers", {rootdir = TOOLS, anonymous = true})
    local json = import("core.base.json")

    -- Accelerate: the names its nested targets declare (the last part of each shard row's USR is its name)
    local umbrella = targets.umbrellas(ROOT).Accelerate
    check(umbrella ~= nil and #umbrella.targets == 2, "no-shard.tsv names two nested targets for Accelerate")
    local declared = {}
    for _, fw in ipairs(umbrella and umbrella.targets or {}) do
        local rows = headers.shard_records(ROOT, fw)
        check(#rows > 0, "the nested target " .. fw .. " has a shard")
        for _, r in ipairs(rows) do
            local name = string.match(r.usr or "", "([^@]+)$")
            if name ~= nil then
                declared[name] = true
            end
        end
    end

    -- every Accelerate registry entry names something one of those shards declares (a function's "()" is not part of its name)
    local entries, resolved, unresolved = 0, 0, {}
    for _, filepath in ipairs(os.files(path.join(ROOT, "packages", "a", "apple-backports", "registry", "Accelerate", "*.json"))) do
        local doc = json.decode(io.readfile(filepath))
        for _, e in ipairs(doc.entries or doc) do
            entries = entries + 1
            local name = string.gsub(e.api or "", "%(%)$", "")
            if declared[name] then
                resolved = resolved + 1
            else
                table.insert(unresolved, name)
            end
        end
    end
    check(entries > 0, "Accelerate has registry entries to resolve")
    check(#unresolved == 0, "every Accelerate registry entry is declared by its nested targets (unresolved: "
          .. table.concat(unresolved, ", ") .. ")")
    print(string.format("targets: Accelerate, %d of %d registry entries resolve through its nested targets", resolved, entries))

    -- Graphics: a product folder whose members are SDK frameworks with shards, and no registry rows of its own
    local members = targets.products(ROOT).Graphics or {}
    check(#members > 0, "products.tsv names the Graphics members")
    for _, fw in ipairs(members) do
        check(#headers.shard_records(ROOT, fw) > 0, "the Graphics member " .. fw .. " has a shard")
    end
    check(not os.isdir(path.join(ROOT, "packages", "a", "apple-backports", "registry", "Graphics")),
          "Graphics has no registry folder of its own: its rows are its members'")

    print("targets test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)) .. " (" .. count .. " checks)")
    if failures > 0 then
        os.exit(1)
    end
end
