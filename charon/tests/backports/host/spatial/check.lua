-- check.lua APPLE OURS - compares the two transcripts of the Spatial differential (Lua port of the former check.py).
-- Every line is `name<TAB>value`. A value that starts with `str:` is a string and is compared exactly; every other value
-- is a number, compared with the tolerance the name's scalar asks for: 1e-12 relative for the `d.` half, 1e-6 for the `f.`
-- half. `nan`, `inf` and `-inf` are compared as the strings they print as. A name on one side and not the other is a
-- difference, and so is a repeated name.
--
-- Three values are not compared but recorded in DIVERGENCES below: the port's answer is written down beside the host's,
-- with the reason, and both are then compared exactly against what this run produced. A difference anywhere else still
-- fails, and one of the three moving - in either column - fails as well, so a recorded divergence is a measurement that
-- cannot quietly become another one. No tolerance is widened for them and none is widened anywhere.
--
-- Prints one `ok ` line per value, one `NAMED` line per recorded divergence with its reason, and one `DIFFER` line per
-- difference, and exits 1 if anything differs. The largest relative difference over the values that were compared is
-- printed last, so a commit message can quote a number this run produced.

local TOLERANCE = {d = 1e-12, f = 1e-6}

-- The port's answers that are not the host's, each recorded with the host's beside it and the reason. Measured on
-- 2026-10-04; the decision these three are decided by is the coordinator's (coordination/wave-2026-10-03/QUEUE.md, the
-- v-fin-spatial ruling): named, measured divergences, not a widened tolerance.
local DIVERGENCES = {
    ["d.rotation.eulerAngles.xyz.z"] = {
        "0.61327141523361206",
        "0.61327139037901746",
        "the last term of the extraction, read off a matrix the two sides print the same seventeen digits for; four parts in "
            .. "1e8, and the other two terms of the same extraction agree to one ulp"},
    ["d.rotation.eulerAngles.zxy.y"] = {
        "0.40688398480415344",
        "0.40688398209126875",
        "the last term of that order's extraction, on the same matrix, and six formulas computed on it - the Float-rounded "
            .. "ones included - reach no better than 4e-9 of the host's"},
    ["f.description"] = {
        "str:(radians: 0.5235988)",
        "str:(radians: 0.52359873)",
        "the Float half's degrees to radians rounds three ulps from the host's, on operands both sides agree on: Float.pi "
            .. "prints 3.1415925 either way"},
}

local NONFINITE = {["nan"] = true, ["inf"] = true, ["-inf"] = true}

local function read(path)
    local values, order = {}, {}
    local handle = assert(io.open(path, "r"), "cannot read " .. path)
    local number = 0
    for line in handle:lines() do
        number = number + 1
        if line ~= "" then
            local name, value = line:match("^([^\t]*)\t(.*)$")
            assert(name, path .. ":" .. number .. " is not `name<TAB>value`: " .. line)
            assert(values[name] == nil, path .. ":" .. number .. " repeats the name " .. name)
            values[name] = value
            table.insert(order, name)
        end
    end
    handle:close()
    return values, order
end

local function close(apple, ours, tolerance)
    if NONFINITE[apple] or NONFINITE[ours] then return apple == ours end
    local a, b = tonumber(apple), tonumber(ours)
    if a == nil or b == nil then return false end
    if a ~= a or b ~= b then return a ~= a and b ~= b end
    if a == b then return true end
    return math.abs(a - b) <= tolerance * math.max(math.abs(a), math.abs(b))
end

function main(apple_path, ours_path)
    local apple, order = read(apple_path)
    local ours = read(ours_path)
    local differences, agreed, named, worst = {}, 0, 0, 0.0
    for _, name in ipairs(order) do
        local divergence = DIVERGENCES[name]
        if divergence then
            local host_value, port_value = divergence[1], divergence[2]
            if ours[name] == nil then
                table.insert(differences, {name, host_value, "<no value>"})
            elseif ours[name] ~= port_value or apple[name] ~= host_value then
                table.insert(differences, {name, apple[name], ours[name]})
            else
                named = named + 1
            end
        elseif ours[name] == nil then
            table.insert(differences, {name, apple[name], "<no value>"})
        else
            local mine = ours[name]
            if apple[name]:sub(1, 4) == "str:" or mine:sub(1, 4) == "str:" then
                if apple[name] == mine then
                    agreed = agreed + 1
                else
                    table.insert(differences, {name, apple[name], mine})
                end
            else
                local tolerance = TOLERANCE[name:match("^([^.]*)")] or 1e-12
                if close(apple[name], mine, tolerance) then
                    agreed = agreed + 1
                    local a, b = tonumber(apple[name]), tonumber(mine)
                    if a and b and a ~= b then
                        worst = math.max(worst, math.abs(a - b) / math.max(math.abs(a), math.abs(b)))
                    end
                else
                    table.insert(differences, {name, apple[name], mine})
                end
            end
        end
    end
    local names = {}
    for name in pairs(DIVERGENCES) do table.insert(names, name) end
    table.sort(names)
    for _, name in ipairs(names) do
        local d = DIVERGENCES[name]
        print(string.format("NAMED %s\thost=%s\tours=%s\t%s", name, d[1], d[2], d[3] or ""))
    end
    for _, d in ipairs(differences) do
        print(string.format("DIFFER %s\thost=%s\tours=%s", d[1], d[2], d[3]))
    end
    print(string.format("values: %d, agree: %d, named divergences: %d, differ: %d, largest relative difference: %g",
        #order, agreed, named, #differences, worst))
    os.exit(#differences > 0 and 1 or 0)
end
