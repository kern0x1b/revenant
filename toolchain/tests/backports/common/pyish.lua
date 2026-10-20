function float(text)
    local lower = text:lower()
    local sign, word = lower:match("^([+-]?)(%a+)$")
    if word == "inf" or word == "infinity" then
        return sign == "-" and -math.huge or math.huge
    end
    if word == "nan" then
        return 0.0 / 0.0
    end
    local value = tonumber(text)
    if value == nil or text:match("^%s") or text:match("%s$") or text:match("^[+-]?0[xX]") then
        raise(string.format("could not convert string to float: '%s'", text), 0)
    end
    return value + 0.0
end

function isdigit(text)
    return text ~= "" and text:match("^%d+$") ~= nil
end

function split(text)
    local out = {}
    for word in text:gmatch("%S+") do
        table.insert(out, word)
    end
    return out
end

function strip(text)
    return (text:match("^%s*(.-)%s*$"))
end

function contains(list, value)
    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end

function same_list(a, b)
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

function sorted_keys(map)
    local keys = {}
    for k in pairs(map) do
        table.insert(keys, k)
    end
    table.sort(keys)
    return keys
end

function lines_of(file)
    if not os.isfile(file) then
        raise(string.format("no such file: %s", file), 0)
    end
    return io.lines(file)
end

function find_plain(text, needle)
    return text:find(needle, 1, true) ~= nil
end

function float_repr(x)
    if x ~= x then
        return "nan"
    end
    if x == math.huge then
        return "inf"
    end
    if x == -math.huge then
        return "-inf"
    end
    local text
    for digits = 0, 16 do
        text = string.format("%." .. digits .. "e", x)
        if tonumber(text) == x then
            break
        end
    end
    local sign, mantissa, exponent = text:match("^(%-?)([%d%.]+)e([%+%-]%d+)$")
    local digits = mantissa:gsub("%.", "")
    local exp = tonumber(exponent)
    local out
    if exp >= -4 and exp < 16 then
        if exp >= 0 then
            if #digits <= exp + 1 then
                out = digits .. string.rep("0", exp + 1 - #digits) .. ".0"
            else
                out = digits:sub(1, exp + 1) .. "." .. digits:sub(exp + 2)
            end
        else
            out = "0." .. string.rep("0", -exp - 1) .. digits
        end
    else
        local head = digits:sub(1, 1)
        if #digits > 1 then
            head = head .. "." .. digits:sub(2)
        end
        out = head .. "e" .. (exp < 0 and "-" or "+") .. string.format("%02d", math.abs(exp))
    end
    return sign .. out
end

function pyround(x)
    local floor = math.floor(x)
    local frac = x - floor
    if frac > 0.5 then
        return floor + 1
    end
    if frac < 0.5 then
        return floor
    end
    if floor % 2 == 0 then
        return floor
    end
    return floor + 1
end

function list_repr(values)
    local quoted = {}
    for _, v in ipairs(values) do
        table.insert(quoted, "'" .. v .. "'")
    end
    return "[" .. table.concat(quoted, ", ") .. "]"
end

function pymax(first, ...)
    local best = first
    for _, value in ipairs({...}) do
        if value > best then
            best = value
        end
    end
    return best
end
