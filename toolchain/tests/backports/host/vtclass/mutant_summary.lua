local V = import("vtlib", {rootdir = os.scriptdir()})
local R = import("records_json", {rootdir = os.scriptdir()})

local function none_if_null(value)
    if value == false then
        return nil
    end
    return value
end

local function tokens_of(path)
    local list = {}
    for token in V.read_text(path):gmatch("%S+") do
        list[#list + 1] = token
    end
    return list
end

local function is_expected_name(token)
    if token:sub(1, 2) ~= "VT" or #token < 3 then
        return false
    end
    return token:sub(3):find("^[A-Za-z0-9_]+$") ~= nil
end

local function load_pair(base_path, mutant_path)
    local function read_one(path)
        if not os.isfile(path) then
            V.fail("mutant_summary.lua: " .. path .. " is not there")
        end
        local map
        local bad = false
        try {
            function()
                map = R.read_object(path)
            end,
            catch {
                function(err)
                    bad = true
                end
            }
        }
        return map, bad
    end
    local before, bad = read_one(base_path)
    local after
    if not bad then
        after, bad = read_one(mutant_path)
    end
    if bad then
        print("  (no mutant build to read)")
        return {}, {}
    end
    return before, after
end

function main(base_path, mutant_path, mutants_path, covered_path, expected_path)
    local before, after = load_pair(base_path, mutant_path)

    local mutated = {}
    for _, line in ipairs(V.read_lines(mutants_path)) do
        if line:find("%S") then
            local cls = line:match("^([^\t]*)")
            mutated[cls] = (mutated[cls] or 0) + 1
        end
    end

    local covered = tokens_of(covered_path)
    V.sort_bytes(covered)
    for _, cls in ipairs(covered) do
        local count = mutated[cls] or 0
        if count ~= 0 then
            local keys = {}
            for key in pairs(before) do
                keys[key] = true
            end
            for key in pairs(after) do
                keys[key] = true
            end
            local changed = 0
            for key in pairs(keys) do
                if none_if_null(before[key]) ~= none_if_null(after[key]) then
                    changed = changed + 1
                end
            end
            print(string.format("  %-48s %d mutant(s) applied, %d record(s) changed", cls, count, changed))
        end
    end

    local skipped = {}
    for _, cls in ipairs(covered) do
        if mutated[cls] == nil then
            skipped[#skipped + 1] = cls
        end
    end

    local listed = {}
    for _, token in ipairs(tokens_of(expected_path)) do
        if is_expected_name(token) then
            listed[#listed + 1] = token
        end
    end
    V.sort_bytes(listed)

    local listed_set, skipped_set = {}, {}
    for _, name in ipairs(listed) do
        listed_set[name] = true
    end
    for _, name in ipairs(skipped) do
        skipped_set[name] = true
    end

    local grew = {}
    for _, name in ipairs(skipped) do
        if not listed_set[name] then
            grew[#grew + 1] = name
        end
    end
    local vanished = {}
    for _, name in ipairs(listed) do
        if not skipped_set[name] then
            vanished[#vanished + 1] = name
        end
    end

    if #grew > 0 then
        print("  CLASSES WITH NO MUTANT THAT ARE NOT IN mutants-expected.txt: " .. table.concat(grew, ", "))
    end
    if #vanished > 0 then
        print("  classes that now HAVE a mutant and can come off the list: " .. table.concat(vanished, ", "))
    end
    if #skipped > 0 then
        print(string.format("  LISTED SKIP - no mutant, by name (%d): %s", #skipped, table.concat(skipped, ", ")))
    else
        print("  every covered class has a mutant")
    end
    if #grew > 0 then
        os.exit(1)
    end
end
