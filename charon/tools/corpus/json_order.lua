local ESCAPES = {['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t"}

local function read_string(text, i)
    local parts, j = {}, i + 1
    while true do
        local e = text:find('["\\]', j)
        if e == nil then
            raise("json_order: the string at %d is not closed", i)
        end
        table.insert(parts, text:sub(j, e - 1))
        if text:sub(e, e) == '"' then
            return table.concat(parts), e
        end
        local escape = text:sub(e + 1, e + 1)
        if escape == "u" then
            raise("json_order: a \\u escape at %d is not decoded here", e)
        end
        if ESCAPES[escape] == nil then
            raise("json_order: the escape \\%s at %d is not JSON", escape, e)
        end
        table.insert(parts, ESCAPES[escape])
        j = e + 2
    end
end

function top_level_keys(text)
    if text:match("^%s*{") == nil then
        raise("json_order: the text does not open an object")
    end
    local keys, depth, last, pos = {}, 0, nil, 1
    while true do
        local at = text:find('["{}%[%],:]', pos)
        if at == nil then
            return keys
        end
        local c = text:sub(at, at)
        if c == '"' then
            local value, close = read_string(text, at)
            if depth == 1 and (last == "{" or last == ",") then
                table.insert(keys, value)
            end
            last = "value"
            pos = close + 1
        else
            pos = at + 1
            if c == "{" or c == "[" then
                depth = depth + 1
                if depth == 1 then
                    last = c
                end
            elseif c == "}" or c == "]" then
                depth = depth - 1
                if depth == 1 then
                    last = "value"
                end
            elseif depth == 1 then
                last = c
            end
        end
    end
end
