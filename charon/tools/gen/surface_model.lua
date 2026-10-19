local layout = import("layout", {anonymous = true})
local headers = import("headers", {anonymous = true})
local files = import("files", {anonymous = true})
local order = import("order", {anonymous = true})
local tsv = import("tsv", {anonymous = true})
local decl = import("decl", {anonymous = true})
local surface_impl = import("surface_impl", {anonymous = true})
local swift_match = import("swift_match", {anonymous = true})
local strings = import("strings", {anonymous = true})

local AFTER = "6.1"
local NO_VALUE = "-"
local SWIFT_SHARD_FILE = "swift.tsv"
local INTERFACE_FILE = "swiftinterface.tsv"
local SWIFT_PREFIX = "swift-"
local OBJC_KINDS = {interface = "class", protocol = "protocol", method = "method", property = "property", var = "constant",
                    enumconst = "constant", ["function"] = "function", enum = "enum", struct = "struct"}
local SWIFT_KINDS = {class = true, struct = true, enum = true, protocol = true, typealias = true, method = true, property = true,
                     constant = true, ["function"] = true}
local ENRICHED = {"demand-rank", "demand-severity", "demand-apps", "demand-telegram", "impl-lead", "impl-file-lead"}
local COLUMNS = {"framework", "kind", "lang", "api", "usr", "introduced", "deprecated", "obsoleted", "unavailable", "via", "getter"}
for _, name in ipairs(ENRICHED) do
    table.insert(COLUMNS, name)
end

local function found(tree, name)
    return import("found." .. name, {rootdir = path.join(tree, "tools"), anonymous = true})
end

function shard_folders(tree)
    local root = path.join(tree, layout.constants().SNAP_ROOT)
    local seen, names = {}, {}
    for _, pattern in ipairs({"*", "*/*"}) do
        for _, file in ipairs({layout.constants().SHARD_FILE, SWIFT_SHARD_FILE, INTERFACE_FILE}) do
            for _, filepath in ipairs(files.glob(path.join(root, pattern, file))) do
                local fw = path.relative(path.directory(filepath), root)
                if not seen[fw] then
                    seen[fw] = true
                    table.insert(names, fw)
                end
            end
        end
    end
    table.sort(names, order.less)
    return names
end

local function surface_name(fw)
    return string.match(fw, "^[^/]+")
end

function frameworks(tree)
    local seen, names = {}, {}
    for _, fw in ipairs(shard_folders(tree)) do
        local name = surface_name(fw)
        if not seen[name] then
            seen[name] = true
            table.insert(names, name)
        end
    end
    table.sort(names, order.less)
    return names
end

local function objc_record(fw, r, shard, avail)
    local kind = OBJC_KINDS[r.kind]
    if kind == nil then
        return nil
    end
    if r.kind == "var" and not string.match(r.usr, "^c:[^@]*@[^@]+$") then
        return nil
    end
    local name = shard.decode(r.kind, r.usr, r.name or "", r.side or "")
    local container = r.container or NO_VALUE
    local api, owner
    if kind == "method" or kind == "property" then
        owner = string.match(r.usr, "^c:objc%(%a+%)([^%(]+)%(")
        if owner == nil then
            return nil
        end
        if kind == "method" then
            local sign = string.find(r.usr, "(cm)", 1, true) and "+" or "-"
            api = sign .. "[" .. owner .. " " .. name .. "]"
        else
            api = owner .. "." .. name
        end
    elseif kind == "function" then
        api = name .. "()"
    else
        api = name
    end
    local parsed = avail.parse_availability(r.availability or NO_VALUE)
    local ios = parsed.entries.ios
    local intro = ios and ios.intro ~= NO_VALUE and ios.intro or nil
    local dep = ios and ios.dep ~= NO_VALUE and ios.dep or nil
    local obs = ios and ios.obs ~= NO_VALUE and ios.obs or nil
    if dep == nil and parsed.always_deprecated then
        dep = "yes"
    end
    local unavailable = (ios and ios.unavailable) or parsed.always_unavailable
    local getter = NO_VALUE
    if kind == "property" then
        local value = decl.attribute_value(r.attrs, "getter")
        if value and value ~= name then
            getter = value
        end
    end
    local category = owner ~= nil and container ~= NO_VALUE and container ~= ""
    return {framework = fw, kind = kind, lang = "objc", api = api, usr = r.usr, owner = owner, container = container, category = category,
            introduced = intro, deprecated = dep or NO_VALUE, obsoleted = obs or NO_VALUE,
            unavailable = unavailable and "yes" or "", getter = getter, via = intro and "own" or "none"}
end

local function swift_record(fw, r)
    local kind = string.sub(r.kind or "", #SWIFT_PREFIX + 1)
    if not SWIFT_KINDS[kind] then
        return nil
    end
    local container = r.container or NO_VALUE
    local api = strings.backslash_replace(container ~= NO_VALUE and (container .. "." .. r.name) or r.name)
    local intro = string.match(r.availability or NO_VALUE, "ios=([^,]+)")
    return {framework = fw, kind = kind, lang = "swift", api = api, usr = r.usr, container = container,
            introduced = intro, deprecated = NO_VALUE, obsoleted = NO_VALUE, unavailable = "", getter = NO_VALUE,
            via = intro and "own" or "none"}
end

local function check_release(tree, folder, release)
    local file = path.join(tree, layout.constants().SNAP_ROOT, folder, layout.constants().SHARD_FILE)
    if not os.isfile(file) then
        return
    end
    local header = nil
    for line in io.lines(file) do
        header = line
        break
    end
    local sdk_name = string.match(header or "", "\tsdk=([^\t]*)")
    assert(sdk_name == "iPhoneOS" .. release, "the declaration shard " .. file .. " is for " .. tostring(sdk_name)
           .. ", not iPhoneOS" .. release .. ": the surface of a release reads its own shards")
end

local function records(tree, avail, release)
    local shard = found(tree, "shard")
    local out, totals = {}, {}
    for _, fw in ipairs(frameworks(tree)) do
        out[fw] = {}
    end
    for _, folder in ipairs(shard_folders(tree)) do
        local name = surface_name(folder)
        local list = out[name]
        check_release(tree, folder, release)
        for _, r in ipairs(headers.shard_records(tree, folder)) do
            local record = objc_record(name, r, shard, avail)
            if record then
                record.unit = folder
                table.insert(list, record)
            end
        end
        local digester = {}
        local text = files.read_text(path.join(tree, layout.constants().SNAP_ROOT, folder, SWIFT_SHARD_FILE)) or ""
        for _, r in ipairs(tsv.records(text)) do
            local record = swift_record(name, r)
            if record then
                table.insert(digester, record)
            end
        end
        local interface = files.read_text(path.join(tree, layout.constants().SNAP_ROOT, folder, INTERFACE_FILE))
        if interface or #digester > 0 then
            local reconciled, counts = swift_match.reconcile(name, digester, interface and tsv.records(interface) or {})
            for _, record in ipairs(reconciled) do
                record.unit = folder
                table.insert(list, record)
            end
            for key, n in pairs(counts) do
                totals[key] = (totals[key] or 0) + n
            end
        end
    end
    return out, totals
end

local function class_floors(all, number)
    local floor = {}
    for _, list in pairs(all) do
        for _, record in ipairs(list) do
            if record.lang == "objc" and (record.kind == "class" or record.kind == "protocol") and record.introduced then
                local have = floor[record.api]
                if have == nil or number(record.introduced) < number(have) then
                    floor[record.api] = record.introduced
                end
            end
        end
    end
    return floor
end

local function inherit(list, floor)
    local own = {}
    for _, record in ipairs(list) do
        local type_kind = record.kind == "class" or record.kind == "protocol" or record.kind == "struct" or record.kind == "enum"
            or record.kind == "typealias"
        if type_kind and record.lang == "objc" and record.introduced and own["objc\t" .. record.api] == nil then
            own["objc\t" .. record.api] = record.introduced
        end
    end
    for _, record in ipairs(list) do
        if record.introduced == nil and record.lang == "objc" and (record.kind == "method" or record.kind == "property") then
            if not record.category and own["objc\t" .. record.owner] then
                record.introduced, record.via = own["objc\t" .. record.owner], "container"
            elseif floor[record.owner] then
                record.introduced, record.via = floor[record.owner], "class-floor"
            end
        elseif record.introduced == nil and record.lang == "objc" and record.kind == "constant" and record.container ~= NO_VALUE then
            record.introduced, record.via = own["objc\t" .. record.container], "container"
        end
    end
end

local function demand_index(corpus)
    local text = files.read_text(path.join(corpus, "crash-demand-top.tsv"))
    assert(text, "no crash demand table in the corpus: " .. path.join(corpus, "crash-demand-top.tsv"))
    local out = {}
    for _, r in ipairs(tsv.records(text)) do
        if out[r.api] == nil then
            out[r.api] = r
        end
    end
    return out
end

local function demand_for(demand, kind, api)
    local row = demand[api]
    if row == nil and (kind == "constant" or kind == "function") then
        row = demand["_" .. string.match(api, "^([^(]*)")]
    end
    return row
end

local function enrich(record, demand, corpus)
    local row = demand_for(demand, record.kind, record.api)
    record["demand-rank"] = row and row.rank or ""
    record["demand-severity"] = row and row.severity or ""
    record["demand-apps"] = row and row.apps or ""
    local telegram = false
    if row then
        for caller in string.gmatch(row.crash_callers or "", "[^,]+") do
            telegram = telegram or caller == "telegram"
        end
    end
    record["demand-telegram"] = telegram and "yes" or ""
    local leads = surface_impl.leads(corpus, record.framework, record.kind, record.lang, record.api)
    local sources, locations = {}, {}
    for _, lead in ipairs(leads) do
        table.insert(sources, lead.source)
        table.insert(locations, lead.file)
    end
    record["impl-lead"] = table.concat(sources, ",")
    record["impl-file-lead"] = table.concat(locations, ";")
end

local function swift_module(usr)
    local digits = string.match(usr, "^s:(%d+)")
    if digits == nil then
        return nil
    end
    local start = 3 + #digits
    return string.sub(usr, start, start + tonumber(digits) - 1)
end

local function own_usrs(all)
    local out = {}
    for fw, list in pairs(all) do
        local set = {}
        for _, record in ipairs(list) do
            if record.lang == "objc" and record.usr and record.usr ~= NO_VALUE then
                set[record.usr] = true
            end
        end
        out[fw] = set
    end
    return out
end

local function owner_of(usr, holders, own)
    local module = swift_module(usr)
    local owner, count = nil, 0
    for _, fw in ipairs(holders) do
        local owns
        if module then
            owns = fw == module
        else
            owns = own[fw][usr] == true
        end
        if owns then
            owner, count = fw, count + 1
        end
    end
    if count == 1 then
        return owner
    end
    return nil
end

function rows(tree, corpus, release)
    local avail = found(tree, "avail")
    local number = avail.version_number
    local all, totals = records(tree, avail, release)
    local floor = class_floors(all, number)
    local out, repeats = {}, 0
    local holders = {}
    for _, fw in ipairs(frameworks(tree)) do
        inherit(all[fw], floor)
        local seen = {}
        for _, record in ipairs(all[fw]) do
            if record.introduced and number(record.introduced) > number(AFTER) then
                local usr = record.usr or ""
                if usr ~= "" and usr ~= NO_VALUE and seen[usr] then
                    repeats = repeats + 1
                else
                    seen[usr] = true
                    table.insert(out, record)
                    if usr ~= "" and usr ~= NO_VALUE then
                        holders[usr] = holders[usr] or {}
                        table.insert(holders[usr], fw)
                    end
                end
            end
        end
    end
    local own = own_usrs(all)
    local cross = {usrs = 0, dropped = 0, undecided_usrs = 0, undecided_rows = 0}
    local dropped_for = {}
    for usr, fws in pairs(holders) do
        if #fws > 1 then
            cross.usrs = cross.usrs + 1
            local owner = owner_of(usr, fws, own)
            if owner == nil then
                cross.undecided_usrs = cross.undecided_usrs + 1
                cross.undecided_rows = cross.undecided_rows + #fws
            else
                for _, fw in ipairs(fws) do
                    if fw ~= owner then
                        dropped_for[fw] = dropped_for[fw] or {}
                        dropped_for[fw][usr] = true
                        cross.dropped = cross.dropped + 1
                    end
                end
            end
        end
    end
    local kept = {}
    for _, record in ipairs(out) do
        local drop = dropped_for[record.framework]
        if not (drop and record.usr and drop[record.usr]) then
            record.sequence = #kept + 1
            table.insert(kept, record)
        end
    end
    out = kept
    local demand = demand_index(corpus)
    for _, record in ipairs(out) do
        enrich(record, demand, corpus)
    end
    table.sort(out, function(a, b)
        local na, nb = number(a.introduced), number(b.introduced)
        if na ~= nb then
            return na < nb
        end
        if a.framework ~= b.framework then
            return order.less(a.framework, b.framework)
        end
        if a.lang ~= b.lang then
            return a.lang < b.lang
        end
        if a.kind ~= b.kind then
            return a.kind < b.kind
        end
        if a.api ~= b.api then
            return order.less(a.api, b.api)
        end
        return a.sequence < b.sequence
    end)
    return out, repeats, totals, cross
end

function declarations(tree, release)
    local all = records(tree, found(tree, "avail"), release)
    local holders = {}
    for _, fw in ipairs(frameworks(tree)) do
        local seen = {}
        for _, record in ipairs(all[fw]) do
            local usr = record.usr or ""
            if usr ~= "" and usr ~= NO_VALUE and not seen[usr] then
                seen[usr] = true
                holders[usr] = holders[usr] or {}
                table.insert(holders[usr], fw)
            end
        end
    end
    local own = own_usrs(all)
    local out = {}
    for _, fw in ipairs(frameworks(tree)) do
        out[fw] = {}
        for _, record in ipairs(all[fw]) do
            local usr = record.usr or ""
            local claimed = fw
            if usr ~= "" and usr ~= NO_VALUE and #holders[usr] > 1 then
                claimed = owner_of(usr, holders[usr], own)
            end
            record.claimed_by = claimed
            table.insert(out[fw], record)
        end
    end
    return out
end

function table_text(list)
    local lines = {table.concat(COLUMNS, "\t")}
    for _, record in ipairs(list) do
        local cells = {}
        for index, name in ipairs(COLUMNS) do
            local value = tostring(record[name] or NO_VALUE)
            cells[index] = (string.gsub(value, "[\t\n]", " "))
        end
        table.insert(lines, table.concat(cells, "\t"))
    end
    return table.concat(lines, "\n") .. "\n"
end
