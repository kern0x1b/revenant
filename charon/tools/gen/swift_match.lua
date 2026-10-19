local NO_VALUE = "-"

local function base_of(api)
    return string.match(api, "^([^(]*)")
end

local function arity_of(api)
    local labels = string.match(api, "%((.*)%)$")
    if labels == nil then
        return nil
    end
    local _, colons = string.gsub(labels, ":", "")
    return colons
end

local function last_of(api)
    return string.match(base_of(api), "([^.]*)$")
end

local function container_of(api)
    return string.match(base_of(api), "^(.*)%.[^.]*$") or NO_VALUE
end

local function earlier(a, b)
    if a.introduced == "" then
        return false
    end
    if b.introduced == "" then
        return true
    end
    return (tonumber(a.introduced) or math.huge) < (tonumber(b.introduced) or math.huge)
end

local function index_interface(interface)
    local by_key, order = {}, {}
    for _, row in ipairs(interface) do
        local key = row.kind .. "\t" .. row.api
        if by_key[key] == nil then
            by_key[key] = row
            table.insert(order, key)
        elseif earlier(row, by_key[key]) then
            by_key[key] = row
        end
    end
    local by_last = {}
    for _, key in ipairs(order) do
        local row = by_key[key]
        local last_key = row.kind .. "\t" .. last_of(row.api)
        by_last[last_key] = by_last[last_key] or {}
        table.insert(by_last[last_key], row)
    end
    return by_key, by_last, order
end

local function unique_fit(candidates, fits)
    local found, count = nil, 0
    for _, row in ipairs(candidates or {}) do
        if fits(row) then
            found = row
            count = count + 1
        end
    end
    return count == 1 and found or nil, count
end

local function take(record, row)
    record.api = row.api
    record.container = container_of(row.api)
    if row.introduced ~= "" then
        record.introduced, record.via = row.introduced, row.via
    end
    record.deprecated = row.deprecated ~= "" and row.deprecated or NO_VALUE
    record.obsoleted = row.obsoleted ~= "" and row.obsoleted or NO_VALUE
    record.unavailable = row.unavailable
end

function reconcile(framework, digester, interface)
    local by_key, by_last, order = index_interface(interface)
    local matched_key = {}
    local out = {}
    local counts = {exact = 0, qualified = 0, relabelled = 0, digester_only = 0, ambiguous = 0, interface_only = 0}
    for _, record in ipairs(digester) do
        local row = by_key[record.kind .. "\t" .. record.api]
        if row then
            counts.exact = counts.exact + 1
        else
            local candidates = by_last[record.kind .. "\t" .. last_of(record.api)]
            local count
            row, count = unique_fit(candidates, function(c)
                return string.sub(c.api, -(#record.api + 1)) == "." .. record.api
            end)
            if row then
                counts.qualified = counts.qualified + 1
            else
                local ambiguous = count > 1
                local base, arity = base_of(record.api), arity_of(record.api)
                if arity then
                    row, count = unique_fit(candidates, function(c)
                        local cbase = base_of(c.api)
                        return arity_of(c.api) == arity
                            and (cbase == base or string.sub(cbase, -(#base + 1)) == "." .. base)
                    end)
                    ambiguous = ambiguous or count > 1
                end
                if row then
                    counts.relabelled = counts.relabelled + 1
                elseif ambiguous then
                    counts.ambiguous = counts.ambiguous + 1
                end
            end
        end
        if row then
            take(record, row)
            matched_key[row.kind .. "\t" .. row.api] = true
        else
            counts.digester_only = counts.digester_only + 1
        end
        table.insert(out, record)
    end
    for _, key in ipairs(order) do
        local row = by_key[key]
        if not matched_key[key] then
            counts.interface_only = counts.interface_only + 1
            table.insert(out, {framework = framework, kind = row.kind, lang = "swift", api = row.api, usr = NO_VALUE,
                               container = container_of(row.api), introduced = row.introduced ~= "" and row.introduced or nil,
                               deprecated = row.deprecated ~= "" and row.deprecated or NO_VALUE,
                               obsoleted = row.obsoleted ~= "" and row.obsoleted or NO_VALUE,
                               unavailable = row.unavailable, getter = NO_VALUE, via = row.introduced ~= "" and row.via or "none"})
        end
    end
    return out, counts
end
