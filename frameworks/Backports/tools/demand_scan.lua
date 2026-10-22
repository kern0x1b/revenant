local SWIFT = "swift"
local OBJC = "objc"
local C = "c"

local LANGUAGES = {swift = SWIFT, m = OBJC, mm = OBJC, h = OBJC, c = C, cc = C, cpp = C, cxx = C, hh = C, hpp = C,
    hxx = C, inl = C, ipp = C}

local CLOSE = {["["] = "]", ["("] = ")", ["{"] = "}"}
local CLOSERS = {["]"] = true, [")"] = true, ["}"] = true}
local MESSAGE_AFTER = {["return"] = true, ["case"] = true, ["else"] = true, ["do"] = true, ["throw"] = true}
local TYPE_KEYWORDS = {class = true, struct = true, enum = true, protocol = true, typealias = true, actor = true}
local OBJC_DECLARATIONS = {interface = true, implementation = true, protocol = true}

function language_of(file)
    local extension = file:match("%.([%w]+)$")
    return extension and LANGUAGES[extension:lower()] or nil
end

function bytes_less(a, b)
    local index = 1
    while true do
        local x, y = a:byte(index), b:byte(index)
        if x == nil or y == nil then
            return x == nil and y ~= nil
        end
        if x ~= y then
            return x < y
        end
        index = index + 1
    end
end

local function string_end(text, stop)
    local quote = text:sub(stop, stop)
    local pattern = quote == "\"" and "[\\\"\n]" or "[\\'\n]"
    local at = stop + 1
    while true do
        local hit = text:find(pattern, at)
        if not hit then
            return #text
        end
        local mark = text:sub(hit, hit)
        if mark == "\\" then
            at = hit + 2
        elseif mark == "\n" then
            return hit - 1
        else
            return hit
        end
    end
end

local function blank(text)
    return (text:gsub("[^\n]", " "))
end

function strip(text, language)
    local out, at, size = {}, 1, #text
    local swift = language == SWIFT
    while at <= size do
        local stop = text:find("[/\"']", at)
        if not stop then
            table.insert(out, text:sub(at))
            break
        end
        table.insert(out, text:sub(at, stop - 1))
        local mark = text:sub(stop, stop)
        local after = text:sub(stop + 1, stop + 1)
        if mark == "/" and after == "/" then
            at = text:find("\n", stop, true) or size + 1
        elseif mark == "/" and after == "*" then
            local _, close = text:find("*/", stop + 2, true)
            close = close or size
            table.insert(out, blank(text:sub(stop, close)))
            at = close + 1
        elseif swift and mark == "\"" and text:sub(stop, stop + 2) == "\"\"\"" then
            local _, close = text:find("\"\"\"", stop + 3, true)
            close = close or size
            table.insert(out, blank(text:sub(stop, close)))
            at = close + 1
        elseif mark == "\"" or (mark == "'" and not swift) then
            local close = string_end(text, stop)
            table.insert(out, " ")
            at = close + 1
        else
            table.insert(out, mark)
            at = stop + 1
        end
    end
    return table.concat(out)
end

local function tokenize(text)
    local kind, value, count, pos = {}, {}, 0, 1
    for start, word in text:gmatch("()([%a_][%w_]*)") do
        for mark in text:sub(pos, start - 1):gmatch("%S") do
            count = count + 1
            kind[count], value[count] = "p", mark
        end
        count = count + 1
        kind[count], value[count] = "w", word
        pos = start + #word
    end
    for mark in text:sub(pos):gmatch("%S") do
        count = count + 1
        kind[count], value[count] = "p", mark
    end
    return {kind = kind, value = value, count = count}
end

local function is_punct(tok, at, mark)
    return at >= 1 and at <= tok.count and tok.kind[at] == "p" and tok.value[at] == mark
end

local function close_of(tok, open)
    local depth = 0
    for at = open, tok.count do
        if tok.kind[at] == "p" then
            local mark = tok.value[at]
            if CLOSE[mark] then
                depth = depth + 1
            elseif CLOSERS[mark] then
                depth = depth - 1
                if depth == 0 then
                    return at
                end
            end
        end
    end
    return nil
end

local function skip_group(tok, at, limit)
    if tok.kind[at] == "p" and CLOSE[tok.value[at]] then
        return math.min((close_of(tok, at) or limit) + 1, limit + 1)
    end
    return at + 1
end

local function selector_from(tok, first, close)
    local parts, unary, at = {}, nil, first
    while at < close do
        if tok.kind[at] == "w" then
            if is_punct(tok, at + 1, ":") then
                table.insert(parts, tok.value[at] .. ":")
                at = at + 2
            else
                if at + 1 == close and #parts == 0 then
                    unary = tok.value[at]
                end
                at = at + 1
            end
        else
            at = skip_group(tok, at, close)
        end
    end
    if #parts > 0 then
        return table.concat(parts)
    end
    return unary
end

local function inferred_class(tok, open)
    local close = close_of(tok, open)
    if close == open + 3 and tok.kind[open + 1] == "w" and tok.kind[open + 2] == "w" then
        local sel, name = tok.value[open + 2], tok.value[open + 1]
        if (sel == "alloc" or sel == "new" or sel:find("^init")) and name:find("^%u") then
            return name
        end
    end
    return nil
end

local function starts_message(tok, open)
    local before = open - 1
    if before < 1 then
        return true
    end
    if tok.kind[before] == "w" then
        return MESSAGE_AFTER[tok.value[before]] == true
    end
    local mark = tok.value[before]
    return mark ~= "]" and mark ~= "@" and not mark:find("%d")
end

local function message_at(tok, open)
    local close = close_of(tok, open)
    if not close then
        return nil
    end
    local first, class, class_method = open + 1, nil, false
    if is_punct(tok, first, "[") then
        class = inferred_class(tok, first)
        first = skip_group(tok, first, close)
    elseif is_punct(tok, first, "(") then
        first = skip_group(tok, first, close)
    elseif tok.kind[first] == "w" then
        local after = first + 1
        if is_punct(tok, after, ".") then
            while is_punct(tok, after, ".") and tok.kind[after + 1] == "w" do
                after = after + 2
            end
            first = after
        else
            if tok.kind[after] == "w" and tok.value[first]:find("^%u") then
                class, class_method = tok.value[first], true
            end
            first = after
        end
    end
    local selector = selector_from(tok, first, close)
    if not selector then
        return nil
    end
    return {selector = selector, class = class, class_method = class_method}
end

local function selector_literal(tok, at)
    if not (is_punct(tok, at, "@") and tok.kind[at + 1] == "w" and tok.value[at + 1] == "selector"
        and is_punct(tok, at + 2, "(")) then
        return nil
    end
    local close = close_of(tok, at + 2)
    if not close then
        return nil
    end
    return selector_from(tok, at + 3, close)
end

local function unique(list, seen, name)
    if not seen[name] then
        seen[name] = true
        table.insert(list, name)
    end
end

local function imports_of(stripped)
    local list, seen = {}, {}
    for name in stripped:gmatch("#%s*import%s*<([%w_]+)/") do
        unique(list, seen, name)
    end
    for name in stripped:gmatch("#%s*include%s*<([%w_]+)/") do
        unique(list, seen, name)
    end
    for name in stripped:gmatch("@import%s+([%w_]+)") do
        unique(list, seen, name)
    end
    for line in stripped:gmatch("[^\n]+") do
        local name = line:match("^%s*@?testable%s+import%s+([%w_]+)") or line:match("^%s*import%s+%a+%s+([%w_]+)")
            or line:match("^%s*import%s+([%w_]+)")
        if name then
            unique(list, seen, name)
        end
    end
    return list
end

local function declarations(tok, declared, members)
    local declared_seen, members_seen = {}, {}
    for at = 1, tok.count do
        if is_punct(tok, at, "@") and tok.kind[at + 1] == "w" then
            local keyword = tok.value[at + 1]
            if OBJC_DECLARATIONS[keyword] and tok.kind[at + 2] == "w" then
                unique(declared, declared_seen, tok.value[at + 2])
            elseif keyword == "class" then
                local stop = at + 2
                while stop <= tok.count and not is_punct(tok, stop, ";") do
                    if tok.kind[stop] == "w" then
                        unique(declared, declared_seen, tok.value[stop])
                    end
                    stop = stop + 1
                end
            elseif keyword == "property" then
                local stop, depth, last = at + 2, 0, nil
                while stop <= tok.count and not (depth == 0 and is_punct(tok, stop, ";")) do
                    if is_punct(tok, stop, "(") then
                        depth = depth + 1
                    elseif is_punct(tok, stop, ")") then
                        depth = depth - 1
                    elseif depth == 0 and tok.kind[stop] == "w" then
                        last = tok.value[stop]
                    end
                    stop = stop + 1
                end
                if last then
                    unique(members, members_seen, last)
                end
            end
        elseif tok.kind[at] == "w" then
            local word = tok.value[at]
            local imported = at > 1 and tok.kind[at - 1] == "w" and tok.value[at - 1] == "import"
            if TYPE_KEYWORDS[word] and tok.kind[at + 1] == "w" and not imported then
                unique(declared, declared_seen, tok.value[at + 1])
            elseif (word == "func" or word == "var" or word == "let") and tok.kind[at + 1] == "w" then
                unique(members, members_seen, tok.value[at + 1])
            end
        end
    end
end

function scan(file)
    local language = language_of(file)
    local stripped = strip(io.readfile(file), language)
    local tok = tokenize(stripped)
    local record = {file = file, language = language, imports = imports_of(stripped), messages = {}, selectors = {},
        words = {}, calls = {}, members = {}, declared = {}, declared_members = {}}
    local seen = {words = {}, calls = {}, members = {}}
    declarations(tok, record.declared, record.declared_members)
    for at = 1, tok.count do
        if tok.kind[at] == "w" then
            local word = tok.value[at]
            if is_punct(tok, at - 1, ".") then
                unique(record.members, seen.members, word)
            else
                unique(record.words, seen.words, word)
                if is_punct(tok, at + 1, "(") then
                    unique(record.calls, seen.calls, word)
                end
            end
        elseif language == OBJC and is_punct(tok, at, "[") and starts_message(tok, at) then
            local message = message_at(tok, at)
            if message then
                table.insert(record.messages, message)
            end
        end
        local literal = selector_literal(tok, at)
        if literal then
            table.insert(record.selectors, literal)
        end
    end
    return record
end
