local RELATIONS = {["<"] = true, ["<="] = true, [">"] = true, [">="] = true, ["=="] = true, ["!="] = true}

local function lines(text)
    local out = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(out, line)
    end
    return out
end

local function trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function isConstant(text)
    return text:match("^%(%s*%-?%d+%.?%d*%s*%)$") ~= nil or text:match("^%-?%d+%.?%d*$") ~= nil
end

local function headerName(head)
    local parts = {}
    for part in (head .. ";"):gmatch("(.-);") do
        table.insert(parts, part)
    end
    if #parts ~= 3 then
        return nil, "a for header that is not init; condition; update"
    end
    local kind, name, init = parts[1]:match("^%s*(%a+)%s+([%a_][%w_]*)%s*=%s*(.-)%s*$")
    if kind ~= "int" and kind ~= "float" then
        return nil, "a for loop whose index is not declared int or float"
    end
    if not init or not isConstant(init) then
        return nil, "a for loop whose index starts at something other than a constant-expression"
    end
    local variable, relation, bound = parts[2]:match("^%s*([%a_][%w_]*)%s*([<>=!]+)%s*(.-)%s*$")
    if variable ~= name then
        return nil, "a for loop whose condition does not compare its index"
    end
    if not RELATIONS[relation] then
        return nil, "a for loop whose condition uses " .. tostring(relation)
    end
    if not bound or not isConstant(bound) then
        return nil, "a for loop whose bound is not a constant-expression"
    end
    local update = trim(parts[3])
    if update ~= name .. "++" and update ~= name .. "--" then
        local operator, amount = update:match("^" .. name .. "%s*([%+%-]=)%s*(.-)$")
        if not operator or not isConstant(amount) then
            return nil, "a for loop whose update is not ++, --, += or -= a constant"
        end
    end
    return name
end

local function assignsTo(body, name)
    local patterns = {
        "%f[%w_]" .. name .. "%s*[%+%-%*/]?=[^=]",
        "%f[%w_]" .. name .. "%s*%+%+",
        "%f[%w_]" .. name .. "%s*%-%-",
        "%+%+%s*" .. name .. "%f[^%w_]",
        "%-%-%s*" .. name .. "%f[^%w_]",
    }
    for _, pattern in ipairs(patterns) do
        if body:find(pattern) then
            return true
        end
    end
    return false
end

local function count(text, character)
    local _, found = text:gsub(character, "")
    return found
end

function check(source)
    local text = lines(source)
    for number, line in ipairs(text) do
        local where = "line " .. number .. ": "
        if line:find("%f[%w_]while%s*%(") or line:find("%f[%w_]do%s*{") or line:find("%f[%w_]do%s*$") then
            return where .. "a while or do-while loop, which ES 2.0 does not mandate (Appendix A, section 4)"
        end
        local head = line:match("%f[%w_]for%s*%((.*)%)%s*{%s*$")
        if line:find("%f[%w_]for%s*%(") and not head then
            return where .. "a for statement without a header and braces that this checker reads"
        end
        if head then
            local name, reason = headerName(head)
            if not name then
                return where .. reason .. " (Appendix A, section 4)"
            end
            local depth, body, closed = 1, {}, false
            for later = number + 1, #text do
                depth = depth + count(text[later], "{") - count(text[later], "}")
                if depth == 0 then
                    closed = true
                    break
                end
                table.insert(body, text[later])
            end
            if not closed then
                return where .. "a for loop whose braces do not close"
            end
            local inside = table.concat(body, "\n")
            if inside:find("for%s*%(%s*%a+%s+" .. name .. "%s") then
                return where .. "a nested loop that declares its index " .. name .. " again"
            end
            if assignsTo(inside, name) then
                return where .. "a loop body that assigns to its index " .. name .. " (Appendix A, section 4)"
            end
        end
        for index in line:gmatch("%[([^%]]*)%]") do
            if not index:match("^%s*%d+%s*$") then
                return where .. "an array index that is not a constant-index-expression (Appendix A, section 5)"
            end
        end
    end
    return nil
end
