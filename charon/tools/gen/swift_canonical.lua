local NO_VALUE = "-"
local TYPE_KINDS = {["class"] = true, ["struct"] = true, ["enum"] = true, ["protocol"] = true, ["typealias"] = true}
local CANONICAL_PARAMETER = "\207\132_(%d+)_(%d+)"

local function signature_names(signature)
    local names = {}
    if signature == nil or signature == NO_VALUE then
        return names
    end
    local body = string.match(signature, "^<(.*)>$")
    if body == nil then
        return names
    end
    local head = string.match(body, "^(.-) where ") or body
    for term in string.gmatch(head, "[^,]+") do
        local name = string.match(term, "^%s*each%s+([%w_]+)") or string.match(term, "^%s*([%w_]+)")
        if name and name ~= "Self" then
            table.insert(names, name)
        end
    end
    return names
end

local function type_parameter_names(row)
    if row.kind == "swift-protocol" then
        return {"Self"}
    end
    local count = 0
    for index in string.gmatch(row.generic_sig or "", "\207\132_0_(%d+)") do
        count = math.max(count, tonumber(index) + 1)
    end
    if count == 0 then
        return signature_names(row.generic_sig)
    end
    local names = {}
    for i = 1, count do
        names[i] = "T0_" .. (i - 1)
    end
    return names
end

function rows(rows)
    local names_of = {}
    for _, row in ipairs(rows) do
        if TYPE_KINDS[string.match(row.kind, "^swift%-(.*)$")] then
            names_of[row.container ~= NO_VALUE and (row.container .. "." .. row.name) or row.name] = type_parameter_names(row)
        end
    end
    local out = {}
    for _, row in ipairs(rows) do
        local is_type = TYPE_KINDS[string.match(row.kind, "^swift%-(.*)$")] ~= nil
        local owner = is_type and (row.container ~= NO_VALUE and (row.container .. "." .. row.name) or row.name) or row.container
        local outer = names_of[owner] or {}
        local function resolve(depth, index)
            if depth == 0 and outer[index + 1] then
                return outer[index + 1]
            end
            return "T" .. depth .. "_" .. index
        end
        local spelled = {}
        for k, v in pairs(row) do
            spelled[k] = v
        end
        for _, field in ipairs({"type", "params", "generic_sig", "superclass", "alias", "conformances"}) do
            if type(row[field]) == "string" then
                spelled[field] = (string.gsub(row[field], CANONICAL_PARAMETER, function(depth, index)
                    return resolve(tonumber(depth), tonumber(index))
                end))
            end
        end
        spelled.outer_names = {}
        for _, name in ipairs(names_of[row.container] or {}) do
            spelled.outer_names[name] = true
        end
        table.insert(out, spelled)
    end
    return out
end
