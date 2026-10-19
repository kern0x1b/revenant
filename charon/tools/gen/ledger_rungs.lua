local tsv = import("tsv", {anonymous = true})
local pyjson = import("pyjson", {anonymous = true})
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

local RUNG_ARCH = {
    {"4.3", "armv7"}, {"6.1.3", "armv7"}, {"7.0", "armv7"}, {"7.1", "armv7"},
    {"7.1.1", "armv7"}, {"7.1.2", "armv7"}, {"8.0", "armv7"}, {"8.1.3", "armv7s"},
    {"8.2", "armv7s"}, {"8.4.1", "armv7s"}, {"9.3.6", "armv7"}, {"10.0.1", "arm64"},
    {"11.0", "arm64"}, {"12.0", "arm64"}, {"16.0", "arm64e"},
}
local CONTROL = "_NSFileSize"
local NONSENSE = "_AVNoSuchSymbolForAReviewerControl"
local NONE_OF_THE_15 = "NONE-OF-THE-15"

local function list_repr(items)
    local quoted = {}
    for _, item in ipairs(items) do
        table.insert(quoted, "'" .. item .. "'")
    end
    return "[" .. table.concat(quoted, ", ") .. "]"
end

local function counts_repr(order, counts)
    local items = {}
    for _, key in ipairs(order) do
        table.insert(items, "'" .. key .. "': " .. counts[key])
    end
    return "{" .. table.concat(items, ", ") .. "}"
end

local function counter(values)
    local order, counts = {}, {}
    for _, value in ipairs(values) do
        if counts[value] == nil then
            table.insert(order, value)
            counts[value] = 0
        end
        counts[value] = counts[value] + 1
    end
    return order, counts
end

local function set_size(set)
    local count = 0
    for _ in pairs(set) do
        count = count + 1
    end
    return count
end

local function load_dumps(cache)
    local dumps, present, missing = {}, {}, {}
    for _, rung in ipairs(RUNG_ARCH) do
        local release = rung[1]
        local names = {}
        local file = path.join(cache, "cache-" .. release .. ".tsv")
        if os.isfile(file) then
            local handle = io.open(file, "rb")
            local text = handle:read("a")
            handle:close()
            for _, line in ipairs(tsv.lines(text)) do
                local parts = tsv.fields(line)
                if #parts == 2 then
                    names[parts[1]] = true
                end
            end
        end
        dumps[release] = names
        if set_size(names) > 0 then
            table.insert(present, release)
        else
            table.insert(missing, release)
        end
    end
    return dumps, present, missing
end

local function symbols_for(api, kind)
    local out = {}
    if kind == "class" or kind == "protocol" then
        table.insert(out, "_OBJC_CLASS_$_" .. api)
        table.insert(out, "_OBJC_METACLASS_$_" .. api)
    else
        local method = string.match(api, "^[-+]%[([A-Za-z0-9_]+) (.+)%]$")
        if method then
            local selector = string.match(api, "^[-+]%[[A-Za-z0-9_]+ (.+)%]$")
            table.insert(out, (string.sub(api, 1, 1) == "+" and "_OBJC_CLASS_METHOD_$_" or "_OBJC_METHOD_$_") .. selector)
        end
        if string.match(api, "^[A-Za-z0-9_]+%.[A-Za-z0-9_]+$") then
            table.insert(out, "_OBJC_IVAR_$_" .. api)
        end
        if string.match(api, "^[A-Za-z0-9_]+%(") then
            table.insert(out, api)
        end
        if string.match(api, "^_[A-Za-z0-9_]+$") then
            table.insert(out, api)
            table.insert(out, "_" .. api)
        end
    end
    return out
end

local function carried_at(symbols, dumps)
    for _, rung in ipairs(RUNG_ARCH) do
        for _, symbol in ipairs(symbols) do
            if dumps[rung[1]][symbol] then
                return rung[1]
            end
        end
    end
    return NONE_OF_THE_15
end

local function owner_of(api, kind)
    if kind == "class" or kind == "protocol" then
        return api
    end
    return string.match(api, "^[-+]%[([A-Za-z0-9_]+) ")
        or string.match(api, "^([A-Za-z0-9_]+)%.")
        or string.match(api, "^([A-Za-z0-9_]+)%(")
        or api
end

local function read_ledger(filepath)
    local handle = io.open(filepath, "rb")
    local lines = tsv.lines(handle:read("a"))
    handle:close()
    local head = tsv.fields(lines[1] or "")
    local rows = {}
    for index = 2, #lines do
        local fields = tsv.fields(lines[index])
        if #fields >= #head then
            local row = {}
            for column, name in ipairs(head) do
                row[name] = fields[column] or ""
            end
            table.insert(rows, row)
        end
    end
    return rows
end

local function read_demand(filepath)
    local order = {}
    if not filepath or not os.isfile(filepath) then
        return order
    end
    local handle = io.open(filepath, "rb")
    local lines = tsv.lines(handle:read("a"))
    handle:close()
    local head = tsv.fields(lines[1] or "")
    local column = {}
    for index, name in ipairs(head) do
        column[name] = index
    end
    for index = 2, #lines do
        local fields = tsv.fields(lines[index])
        if #fields >= #head then
            local key = fields[column.framework] .. "\t" .. fields[column.api]
            if order[key] == nil then
                local rank = fields[column.rank]
                order[key] = string.match(rank, "^%d+$") and tonumber(rank) or 1000000
            end
        end
    end
    return order
end

local function chosen_before(a, b)
    if (a.demand_rank == nil) ~= (b.demand_rank == nil) then
        return b.demand_rank == nil
    end
    local rank_a, rank_b = a.demand_rank or 0, b.demand_rank or 0
    if rank_a ~= rank_b then
        return rank_a < rank_b
    end
    if a.framework ~= b.framework then
        return byteorder.less(a.framework, b.framework)
    end
    if a.api ~= b.api then
        return byteorder.less(a.api, b.api)
    end
    return a.position < b.position
end

local function member_before(a, b)
    if a.owner ~= b.owner then
        return byteorder.less(a.owner, b.owner)
    end
    if a.api ~= b.api then
        return byteorder.less(a.api, b.api)
    end
    return a.position < b.position
end

local function sorted_by(items, before)
    local ordered = table.join(items)
    table.sort(ordered, before)
    return ordered
end

local function ranked(rank)
    return rank ~= nil and rank ~= 0
end

function main(...)
    local args = {...}
    local out, cache, demand_path, limit, every, dry_run = nil, nil, nil, 0, false, false
    local ledger_specs = {}
    local index = 1
    while index <= #args do
        local argument = args[index]
        local function value_of(option)
            if string.sub(argument, 1, #option + 1) == option .. "=" then
                return string.sub(argument, #option + 2)
            end
            index = index + 1
            assert(args[index], option .. " needs a value")
            return args[index]
        end
        if string.sub(argument, 1, 8) == "--cache" then
            cache = value_of("--cache")
        elseif string.sub(argument, 1, 8) == "--demand" then
            demand_path = value_of("--demand")
        elseif string.sub(argument, 1, 8) == "--ledger" then
            table.insert(ledger_specs, value_of("--ledger"))
        elseif string.sub(argument, 1, 7) == "--limit" then
            limit = tonumber(value_of("--limit"))
        elseif argument == "--all" then
            every = true
        elseif argument == "--dry-run" then
            dry_run = true
        else
            assert(out == nil, "usage: xmake l tools/gen/ledger_rungs.lua <out dir> [options]")
            out = argument
        end
        index = index + 1
    end
    assert(out, "usage: xmake l tools/gen/ledger_rungs.lua <out dir> [options]")

    cache = cache or path.join(os.scriptdir(), "..", "corpus", "caches")
    local dumps, present, missing = load_dumps(cache)
    print(string.format("# caches found: %d of %d rungs %s", #present, #RUNG_ARCH, list_repr(present)))
    if #missing > 0 then
        print("# NO DUMP for: " .. table.concat(missing, ", "))
    end
    local control = nil
    local seen_nonsense = {}
    for _, rung in ipairs(RUNG_ARCH) do
        if control == nil and dumps[rung[1]][CONTROL] then
            control = rung[1]
        end
        if dumps[rung[1]][NONSENSE] then
            table.insert(seen_nonsense, rung[1])
        end
    end
    print(string.format("# the planted control %s is found at: %s", CONTROL, control or "NO RUNG - the measurement is void"))
    if not control then
        io.stderr:write("no control in any cache: refusing to report a measurement\n")
        os.exit(1)
    end
    print(string.format("# the nonsense control is found at: %s", #seen_nonsense > 0 and list_repr(seen_nonsense) or "nowhere, as it must be"))

    local ledgers = {}
    for _, spec in ipairs(ledger_specs) do
        local name, filepath = string.match(spec, "^([^=]*)=(.*)$")
        assert(name, "--ledger takes NAME=PATH, not " .. spec)
        table.insert(ledgers, {name = name, rows = read_ledger(filepath)})
    end
    local demand = read_demand(demand_path)

    local chosen = {}
    for _, ledger in ipairs(ledgers) do
        for _, row in ipairs(ledger.rows) do
            local needs = row.needs or ""
            if needs == "code" or needs == "code+lift" then
                local rank = demand[ledger.name .. "\t" .. row.api]
                if every or rank ~= nil then
                    local chosen_row = {}
                    for key, value in pairs(row) do
                        chosen_row[key] = value
                    end
                    chosen_row.framework = ledger.name
                    chosen_row.demand_rank = rank
                    chosen_row.position = #chosen + 1
                    table.insert(chosen, chosen_row)
                end
            end
        end
    end
    chosen = sorted_by(chosen, chosen_before)
    if limit ~= 0 then
        local kept = {}
        for index = 1, math.min(limit, #chosen) do
            table.insert(kept, chosen[index])
        end
        chosen = kept
    end

    local measured = {}
    for _, row in ipairs(chosen) do
        local symbols = symbols_for(row.api, row.kind)
        local first = carried_at(symbols, dumps)
        local measured_row = {}
        for key, value in pairs(row) do
            measured_row[key] = value
        end
        measured_row.owner = owner_of(row.api, row.kind)
        measured_row.first_held_rung = first
        table.insert(measured, measured_row)
    end

    local demanded = 0
    local kinds, owners, owner_seen = {}, 0, {}
    local owner_list = {}
    for _, row in ipairs(measured) do
        if ranked(row.demand_rank) then
            demanded = demanded + 1
        end
        table.insert(kinds, row.kind)
        table.insert(owner_list, row.first_held_rung)
        if not owner_seen[row.owner] then
            owner_seen[row.owner] = true
            owners = owners + 1
        end
    end
    local kind_order, kind_counts = counter(kinds)
    local rung_order, rung_counts = counter(owner_list)
    print()
    print(string.format("# rows selected: %d  (demanded %d)", #measured, demanded))
    print("# by kind: " .. counts_repr(kind_order, kind_counts))
    print("# by first held rung: " .. counts_repr(rung_order, rung_counts))
    print(string.format("# owners: %d", owners))

    local groups, group_names = {}, {}
    for _, row in ipairs(measured) do
        if groups[row.first_held_rung] == nil then
            groups[row.first_held_rung] = {}
            table.insert(group_names, row.first_held_rung)
        end
        table.insert(groups[row.first_held_rung], row)
    end
    byteorder.sort(group_names)
    for _, group in ipairs(group_names) do
        groups[group] = sorted_by(groups[group], member_before)
    end

    if dry_run then
        for _, rung in ipairs(group_names) do
            print()
            print(string.format("## rung %s: %d rows", rung, #groups[rung]))
            for _, row in ipairs(groups[rung]) do
                local demand_text = ranked(row.demand_rank) and ("demand#" .. row.demand_rank .. " ") or ""
                print(string.format("   %-46s %-9s %-9s introduced=%-7s", demand_text, row.kind, row.owner, row.introduced or ""))
            end
        end
        return
    end

    os.mkdir(out)
    local rows = {}
    for _, rung in ipairs(group_names) do
        local members = groups[rung]
        local label = rung == NONE_OF_THE_15 and "Unheld" or (string.gsub(string.gsub(rung, "%.", ""), "%-", "M"))
        local apis = {}
        for _, row in ipairs(members) do
            table.insert(apis, row.api)
        end
        table.insert(rows, {object = {
            {"rung", rung},
            {"object", "Demand" .. label},
            {"count", #members},
            {"apis", {array = apis}},
        }})
    end
    local rungs_searched = {}
    for _, rung in ipairs(RUNG_ARCH) do
        table.insert(rungs_searched, rung[1])
    end
    local nonsense_found = {}
    for _, release in ipairs(seen_nonsense) do
        table.insert(nonsense_found, release)
    end
    local manifest = {object = {
        {"rungs_searched", {array = rungs_searched}},
        {"control_found_at", control},
        {"nonsense_found_at", {array = nonsense_found}},
        {"rows", {array = rows}},
    }}
    io.writefile(path.join(out, "manifest.json"), pyjson.encode(manifest, " "), {encoding = "binary"})
    print()
    print(string.format("# wrote %s/manifest.json: %d objects", out, #rows))
end
