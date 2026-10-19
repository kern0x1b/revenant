local ORDERS = {}
local ARRAYS = {}

local function new_table()
    local map = {}
    ORDERS[map] = {}
    return map
end

local function remember(map, key)
    local ordered = ORDERS[map]
    if ordered == nil then
        ordered = {}
        ORDERS[map] = ordered
    end
    table.insert(ordered, key)
end

local function is_empty(value)
    for _ in pairs(value) do
        return false
    end
    return true
end

function is_array(value)
    if type(value) ~= "table" then
        return false
    end
    if ARRAYS[value] then
        return true
    end
    if is_empty(value) then
        return false
    end
    for key in pairs(value) do
        if type(key) ~= "number" then
            return false
        end
    end
    return true
end

function is_table(value)
    return type(value) == "table" and not is_array(value)
end

function keys(map)
    local listed, seen = {}, {}
    for _, key in ipairs(ORDERS[map] or {}) do
        if map[key] ~= nil and not seen[key] then
            seen[key] = true
            table.insert(listed, key)
        end
    end
    local rest = {}
    for key in pairs(map) do
        if not seen[key] then
            table.insert(rest, key)
        end
    end
    table.sort(rest, function (a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(rest) do
        table.insert(listed, key)
    end
    return listed
end

function copy(value)
    if type(value) ~= "table" then
        return value
    end
    local out = {}
    if ARRAYS[value] then
        ARRAYS[out] = true
        for index = 1, #value do
            table.insert(out, copy(value[index]))
        end
        return out
    end
    ORDERS[out] = {}
    for _, key in ipairs(keys(value)) do
        out[key] = copy(value[key])
        remember(out, key)
    end
    return out
end

function merge(base, over)
    local out = copy(base)
    if not ORDERS[out] then
        ORDERS[out] = {}
    end
    for _, key in ipairs(keys(over)) do
        if out[key] == nil then
            remember(out, key)
        end
        out[key] = copy(over[key])
    end
    return out
end

local function fail(state, message, ...)
    raise("%s:%d: %s", state.name, state.line, string.format(message, ...))
end

local function peek(state, offset)
    local at = state.pos + (offset or 0)
    return state.text:sub(at, at)
end

local function advance(state, count)
    state.pos = state.pos + (count or 1)
end

local function at_end(state)
    return state.pos > #state.text
end

local function skip_blank(state)
    while peek(state) == " " or peek(state) == "\t" do
        advance(state)
    end
end

local function skip_comment(state)
    if peek(state) == "#" then
        while not at_end(state) and peek(state) ~= "\n" do
            advance(state)
        end
    end
end

local function newline(state)
    if peek(state) == "\r" and peek(state, 1) == "\n" then
        advance(state, 2)
    else
        advance(state)
    end
    state.line = state.line + 1
end

local function is_newline(state)
    return peek(state) == "\n" or (peek(state) == "\r" and peek(state, 1) == "\n")
end

local function end_of_line(state)
    skip_blank(state)
    skip_comment(state)
    if at_end(state) then
        return
    end
    if not is_newline(state) then
        fail(state, "expected the end of the line, found %q", peek(state))
    end
    newline(state)
end

local function skip_separators(state)
    while true do
        skip_blank(state)
        if is_newline(state) then
            newline(state)
        elseif peek(state) == "#" then
            skip_comment(state)
        else
            return
        end
    end
end

local function code_point(state, digits)
    local hex = state.text:sub(state.pos, state.pos + digits - 1)
    if #hex ~= digits or not hex:match("^%x+$") then
        fail(state, "a unicode escape needs %d hex digits", digits)
    end
    advance(state, digits)
    return utf8.char(tonumber(hex, 16))
end

local ESCAPES = {b = "\b", t = "\t", n = "\n", f = "\f", r = "\r", ['"'] = '"', ["\\"] = "\\"}

local function escape(state)
    advance(state)
    local c = peek(state)
    if ESCAPES[c] then
        advance(state)
        return ESCAPES[c]
    end
    if c == "u" then
        advance(state)
        return code_point(state, 4)
    end
    if c == "U" then
        advance(state)
        return code_point(state, 8)
    end
    fail(state, "unknown escape \\%s", c)
end

local function basic_string(state)
    advance(state)
    local parts = {}
    while true do
        local c = peek(state)
        if at_end(state) or c == "\n" then
            fail(state, "a basic string is not closed on its line")
        elseif c == '"' then
            advance(state)
            return table.concat(parts)
        elseif c == "\\" then
            table.insert(parts, escape(state))
        else
            table.insert(parts, c)
            advance(state)
        end
    end
end

local function literal_string(state)
    advance(state)
    local start = state.pos
    while not at_end(state) and peek(state) ~= "'" do
        if peek(state) == "\n" then
            fail(state, "a literal string is not closed on its line")
        end
        advance(state)
    end
    if at_end(state) then
        fail(state, "a literal string is not closed")
    end
    local text = state.text:sub(start, state.pos - 1)
    advance(state)
    return text
end

local function multiline_string(state, quote, escapes)
    advance(state, 3)
    if is_newline(state) then
        newline(state)
    end
    local parts = {}
    while true do
        if at_end(state) then
            fail(state, "a multi-line string is not closed")
        end
        if peek(state) == quote and peek(state, 1) == quote and peek(state, 2) == quote then
            local run = 0
            while peek(state, run) == quote do
                run = run + 1
            end
            if run > 5 then
                fail(state, "a multi-line string ends with more than five quotes")
            end
            for _ = 1, run - 3 do
                table.insert(parts, quote)
            end
            advance(state, run)
            return table.concat(parts)
        end
        if escapes and peek(state) == "\\" and state.text:match("^\\[ \t]*\r?\n", state.pos) then
            advance(state)
            while peek(state):match("^[ \t\r\n]$") do
                if peek(state) == "\n" then
                    state.line = state.line + 1
                end
                advance(state)
            end
        elseif escapes and peek(state) == "\\" then
            table.insert(parts, escape(state))
        elseif peek(state) == "\n" then
            table.insert(parts, "\n")
            newline(state)
        elseif peek(state) == "\r" and peek(state, 1) == "\n" then
            table.insert(parts, "\n")
            newline(state)
        else
            table.insert(parts, peek(state))
            advance(state)
        end
    end
end

local function number(state, token)
    local digits = token:gsub("_", "")
    if digits:match("^[+-]?%d+$") then
        return tonumber(digits)
    end
    if digits:match("^[+-]?%d+%.%d+$") or digits:match("^[+-]?%d+[eE][+-]?%d+$")
        or digits:match("^[+-]?%d+%.%d+[eE][+-]?%d+$") then
        return tonumber(digits) + 0.0
    end
    if digits:match("^0x%x+$") then
        return tonumber(digits:sub(3), 16)
    end
    fail(state, "%s is a value this reader does not take", token)
end

local parse_value

local function assign(state, map, path, value)
    local target = map
    for index = 1, #path - 1 do
        local key = path[index]
        local inner = target[key]
        if inner == nil then
            inner = new_table()
            target[key] = inner
            remember(target, key)
        elseif type(inner) ~= "table" or ARRAYS[inner] then
            fail(state, "%s is already set to a value", key)
        end
        target = inner
    end
    local last = path[#path]
    if target[last] ~= nil then
        fail(state, "%s is set twice", last)
    end
    target[last] = value
    remember(target, last)
end

local function inline_table(state)
    advance(state)
    local map = new_table()
    skip_blank(state)
    if peek(state) == "}" then
        advance(state)
        return map
    end
    while true do
        skip_blank(state)
        local path = key_path(state)
        skip_blank(state)
        if peek(state) ~= "=" then
            fail(state, "expected = after a key in an inline table")
        end
        advance(state)
        skip_blank(state)
        assign(state, map, path, parse_value(state))
        skip_blank(state)
        local c = peek(state)
        if c == "," then
            advance(state)
        elseif c == "}" then
            advance(state)
            return map
        else
            fail(state, "expected , or } in an inline table")
        end
    end
end

local function array(state)
    advance(state)
    local items = {}
    ARRAYS[items] = true
    while true do
        skip_separators(state)
        if peek(state) == "]" then
            advance(state)
            return items
        end
        table.insert(items, parse_value(state))
        skip_separators(state)
        local c = peek(state)
        if c == "," then
            advance(state)
        elseif c == "]" then
            advance(state)
            return items
        else
            fail(state, "expected , or ] in an array")
        end
    end
end

parse_value = function (state)
    local c = peek(state)
    if c == '"' then
        if peek(state, 1) == '"' and peek(state, 2) == '"' then
            return multiline_string(state, '"', true)
        end
        return basic_string(state)
    elseif c == "'" then
        if peek(state, 1) == "'" and peek(state, 2) == "'" then
            return multiline_string(state, "'", false)
        end
        return literal_string(state)
    elseif c == "[" then
        return array(state)
    elseif c == "{" then
        return inline_table(state)
    end
    local start = state.pos
    while not at_end(state) and peek(state):match("[A-Za-z0-9_%+%-%.:]") do
        advance(state)
    end
    local token = state.text:sub(start, state.pos - 1)
    if token == "true" then
        return true
    elseif token == "false" then
        return false
    elseif token == "" then
        fail(state, "expected a value")
    end
    return number(state, token)
end

function key_path(state)
    local path = {}
    while true do
        local c = peek(state)
        if c == '"' then
            table.insert(path, basic_string(state))
        elseif c == "'" then
            table.insert(path, literal_string(state))
        else
            local start = state.pos
            while peek(state):match("^[A-Za-z0-9_%-]$") do
                advance(state)
            end
            if state.pos == start then
                fail(state, "expected a key, found %q", c)
            end
            table.insert(path, state.text:sub(start, state.pos - 1))
        end
        skip_blank(state)
        if peek(state) ~= "." then
            return path
        end
        advance(state)
        skip_blank(state)
    end
end

local function header_table(state, root, path, element)
    local target = root
    for index = 1, #path do
        local key = path[index]
        local inner = target[key]
        if index == #path and element then
            if inner == nil then
                inner = {}
                ARRAYS[inner] = true
                target[key] = inner
                remember(target, key)
            elseif not ARRAYS[inner] then
                fail(state, "%s is a table, not an array of tables", key)
            end
            local fresh = new_table()
            table.insert(inner, fresh)
            return fresh
        end
        if inner == nil then
            inner = new_table()
            target[key] = inner
            remember(target, key)
        elseif ARRAYS[inner] then
            inner = inner[#inner]
        elseif type(inner) ~= "table" then
            fail(state, "%s is already set to a value", key)
        end
        target = inner
    end
    return target
end

function map_from(names, values)
    local out = new_table()
    for _, key in ipairs(names) do
        if values[key] ~= nil then
            out[key] = values[key]
            remember(out, key)
        end
    end
    return out
end

function parse(text, name)
    local state = {text = text, pos = 1, line = 1, name = name or "toml"}
    local defined = {}
    local root = new_table()
    local current = root
    while true do
        skip_separators(state)
        if at_end(state) then
            break
        end
        if peek(state) == "[" then
            local element = peek(state, 1) == "["
            advance(state, element and 2 or 1)
            skip_blank(state)
            local path = key_path(state)
            skip_blank(state)
            local closing = element and "]]" or "]"
            if state.text:sub(state.pos, state.pos + #closing - 1) ~= closing then
                fail(state, "expected %s to close a table header", closing)
            end
            advance(state, #closing)
            if not element then
                local key = table.concat(path, "\0")
                if defined[key] then
                    fail(state, "table %s is defined twice", table.concat(path, "."))
                end
                defined[key] = true
            end
            current = header_table(state, root, path, element)
            end_of_line(state)
        else
            local path = key_path(state)
            skip_blank(state)
            if peek(state) ~= "=" then
                fail(state, "expected = after a key")
            end
            advance(state)
            skip_blank(state)
            assign(state, current, path, parse_value(state))
            end_of_line(state)
        end
    end
    return root
end
