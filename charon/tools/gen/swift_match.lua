-- The Swift rows of one module, from its two sources: the digester's dump (swift.tsv: one row per declaration, with its usr, but no
-- availability of an extension and no name of a nested type's outer types) and the interface text (swiftinterface.tsv, written by
-- swiftiface from the .swiftinterface: one row per api, with the availability each declaration has by its own @available or its
-- enclosing one's, and the api qualified by every type it sits in). reconcile() gives one row per declaration:
--   - a digester row the interface names (the same kind and api) takes the interface's introduction, deprecation, obsoletion and
--     unavailability, and its via;
--   - a digester row the interface names under its outer types (Configuration.cornerStyle for UIPasteControl.Configuration.cornerStyle)
--     takes the qualified api and the same fields, when exactly one interface api fits;
--   - a digester row the interface names with other labels (==(_:_:) for ==(a:b:)) takes the interface's api and fields, when exactly
--     one interface api of the same name and arity fits;
--   - an interface api no digester row matched is a row of its own (usr "-"): a member the dump leaves out.
-- A digester row no interface api fits keeps its own availability (the dump's ios=) and no more: nothing is guessed from a container.
-- An api the interface states more than once (the same name in two extensions with different constraints) is one row, with the earliest
-- introduction: the api is there from the first declaration that has it.

local NO_VALUE = "-"

-- The api up to its parameter list: "A.b(_:_:)" is "A.b", and an api with no list is itself.
local function base_of(api)
    return string.match(api, "^([^(]*)")
end

-- The number of parameters of an api's list (its labels, each ending in a colon), or nil when it has no list.
local function arity_of(api)
    local labels = string.match(api, "%((.*)%)$")
    if labels == nil then
        return nil
    end
    local _, colons = string.gsub(labels, ":", "")
    return colons
end

-- The last name of an api's base: "b" for "A.b" and for "A.b(_:)".
local function last_of(api)
    return string.match(base_of(api), "([^.]*)$")
end

-- The container of an api: the api without its last name, or NO_VALUE for a name with no type around it.
local function container_of(api)
    return string.match(base_of(api), "^(.*)%.[^.]*$") or NO_VALUE
end

-- Whether interface row a is the earlier introduction of an api than row b: a row with no introduction is later than any with one.
local function earlier(a, b)
    if a.introduced == "" then
        return false
    end
    if b.introduced == "" then
        return true
    end
    return (tonumber(a.introduced) or math.huge) < (tonumber(b.introduced) or math.huge)
end

-- The interface's rows of one module, indexed: by kind and api (the earliest row of an api), and by kind and last name (each api once).
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

-- The one interface row that fits a digester row by the given test, or nil when none or several fit; and how many fit.
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

-- Takes the interface's fields into a digester-shaped row: its api, container, introduction, deprecation, obsoletion, unavailability.
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

-- The rows of one module. digester is the module's Swift records (framework, kind, lang, api, usr, container, introduced ...), and
-- interface its interface rows (kind, api, introduced, deprecated, obsoleted, unavailable, via: the shard's cells). Returns the rows
-- (the digester's, reconciled, then the interface's own) and the counts of how each row was matched.
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
