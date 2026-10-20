local ulp = import("ulp", {rootdir = path.join(os.scriptdir(), "..", "..", "common"), anonymous = true})
local json = import("core.base.json")

local CLAIMS = {
    {"compared", "compared: (%d+) cases"},
    {{"identical", "ulp", "non_ulp"}, "identical: (%d+)%s+ulp %(bound %d+%): (%d+)%s+non%-ulp: (%d+)"},
    {"largest_rounding", "rounding is %*%*(%d+)%*%*"},
    {"smallest_beyond", "that are not is %*%*(%d+)%*%*"},
}

local function repr(values)
    local quoted = {}
    for _, v in ipairs(values) do
        table.insert(quoted, "'" .. v .. "'")
    end
    if #quoted == 1 then
        return "(" .. quoted[1] .. ",)"
    end
    return "(" .. table.concat(quoted, ", ") .. ")"
end

local function read_text(file)
    if not os.isfile(file) then
        error(string.format("no such file: %s", file), 0)
    end
    return io.readfile(file)
end

local function better_max(a, b)
    return a[1] > b[1] or (a[1] == b[1] and a[2] > b[2])
end

local function better_min(a, b)
    return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2])
end

local function measure(rundir, bound)
    local system = ulp.cases(path.join(rundir, "system.prefix"))
    local port = ulp.cases(path.join(rundir, "port.prefix"))
    local n = math.min(#system, #port)
    local run = {compared = n, identical = 0, ulp = 0, non_ulp = 0}
    local rounding, beyond = {}, {}
    for i = 1, n do
        local s, p = system[i], port[i]
        if s.name ~= p.name or s.length ~= p.length then
            run.non_ulp = run.non_ulp + 1
            table.insert(beyond, {1 << 30, s.name})
        elseif s.hex == p.hex then
            run.identical = run.identical + 1
        else
            local worst = ulp.distance(s.hex, p.hex, s.length)
            if worst <= bound then
                run.ulp = run.ulp + 1
                table.insert(rounding, {worst, s.name})
            else
                run.non_ulp = run.non_ulp + 1
                table.insert(beyond, {worst, s.name})
            end
        end
    end
    local function best(list, better)
        local pick = nil
        for _, entry in ipairs(list) do
            if not pick or better(entry, pick) then
                pick = entry
            end
        end
        return pick
    end
    run.largest_rounding = best(rounding, better_max)
    run.smallest_beyond = best(beyond, better_min)
    return run
end

local function check_effect(rundir, bound, registry, bad)
    local doc = json.loadfile(registry)
    local entries = doc.entries or doc
    local row
    for _, e in ipairs(entries) do
        if e.api == "MPSMatrixFullyConnected" and e.effect and e.effect ~= "" then
            row = e
            break
        end
    end
    if not row then
        print(string.format("  FAIL  %s: no implemented MPSMatrixFullyConnected row carries an effect", registry))
        return bad + 1
    end
    local said = {}
    for claim in row.effect:gmatch("`(fully%-connected %d+)`") do
        said[claim] = true
    end
    local system = ulp.cases(path.join(rundir, "system.prefix"))
    local port = ulp.cases(path.join(rundir, "port.prefix"))
    local n = math.min(#system, #port)
    local beyond = {}
    for i = 1, n do
        local s, p = system[i], port[i]
        if (s.name == "fully-connected" or s.name:sub(1, 16) == "fully-connected ") and s.hex ~= p.hex then
            if ulp.distance(s.hex, p.hex, s.length) > bound then
                beyond[s.name] = true
            end
        end
    end
    local said_list, beyond_list = {}, {}
    for k in pairs(said) do
        table.insert(said_list, k)
    end
    for k in pairs(beyond) do
        table.insert(beyond_list, k)
    end
    table.sort(said_list)
    table.sort(beyond_list)
    if table.concat(said_list, "\0") == table.concat(beyond_list, "\0") then
        print(string.format("  ok    %s: MPSMatrixFullyConnected names %s, which is what the run found",
            registry, table.concat(said_list, ", ")))
        return bad
    end
    print(string.format("  FAIL  %s: the effect names %s and the run's non-ulp fully-connected cases are %s",
        registry, #said_list > 0 and table.concat(said_list, ", ") or "none",
        #beyond_list > 0 and table.concat(beyond_list, ", ") or "none"))
    return bad + 1
end

function check(rundir, ...)
    local pages = {...}
    for _, name in ipairs({"system.prefix", "port.prefix"}) do
        if not os.isfile(path.join(rundir, name)) then
            io.stderr:write(string.format("page-check: %s is not there, so nothing was measured and this check cannot pass\n",
                path.join(rundir, name)))
            return 2
        end
    end
    local bound
    for _, page in ipairs(pages) do
        local found = read_text(page):match("ulp %(bound (%d+)%):")
        if found then
            bound = tonumber(found)
            break
        end
    end
    if not bound then
        io.stderr:write("page-check: no page states the ulp bound the figures were measured against\n")
        return 2
    end
    local run = measure(rundir, bound)
    print(string.format("measured over %s: compared %d, identical %d, ulp(bound %d) %d, non-ulp %d",
        rundir, run.compared, run.identical, bound, run.ulp, run.non_ulp))
    if run.largest_rounding then
        print(string.format("  the largest distance among the cases that are rounding: %d, in %s",
            run.largest_rounding[1], run.largest_rounding[2]))
    end
    if run.smallest_beyond then
        print(string.format("  the smallest distance among the cases that are not:      %d, in %s",
            run.smallest_beyond[1], run.smallest_beyond[2]))
    end

    local bad, claims_made = 0, 0
    for _, page in ipairs(pages) do
        local text = read_text(page)
        for _, claim in ipairs(CLAIMS) do
            local key, pattern = claim[1], claim[2]
            local said = {text:match(pattern)}
            if said[1] ~= nil then
                claims_made = claims_made + 1
                local mine
                local entry = type(key) == "string" and (key == "largest_rounding" or key == "smallest_beyond") and run[key]
                if type(key) == "table" then
                    mine = {}
                    for _, k in ipairs(key) do
                        table.insert(mine, tostring(run[k]))
                    end
                elseif (key == "largest_rounding" or key == "smallest_beyond") and entry == nil then
                    print(string.format("  %s: the run has no such case, and the page states %s", page, said[1]))
                    bad = bad + 1
                else
                    if key == "largest_rounding" or key == "smallest_beyond" then
                        mine = {tostring(entry[1])}
                    else
                        mine = {tostring(run[key])}
                    end
                end
                if mine then
                    if #said == #mine and table.concat(said, "\0") == table.concat(mine, "\0") then
                        print(string.format("  ok    %s: %s = %s", page, type(key) == "table" and repr(key) or key,
                            #said == 1 and said[1] or repr(mine)))
                    else
                        print(string.format("  FAIL  %s: the page says %s and the run says %s", page, repr(said), repr(mine)))
                        bad = bad + 1
                    end
                end
            end
        end
    end
    for _, page in ipairs(pages) do
        if page:sub(-5) == ".json" then
            bad = check_effect(rundir, bound, page, bad)
            claims_made = claims_made + 1
        end
    end
    if claims_made == 0 then
        print("  FAIL  no figure was checked: a check that examined nothing has to fail")
        return 1
    end
    print(string.format("%d figure(s) checked over %d page(s), %d wrong", claims_made, #pages, bad))
    return bad > 0 and 1 or 0
end

function main(rundir, ...)
    if not rundir then
        io.stderr:write("usage: page-check.lua <run-dir> <page> [page ...]\n")
        os.exit(2)
    end
    os.exit(check(rundir, ...))
end
