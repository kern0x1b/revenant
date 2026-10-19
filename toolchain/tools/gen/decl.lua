local strings = import("strings", {anonymous = true})

local SCALAR_TYPES = strings.set({"BOOL", "bool", "_Bool", "char", "signed char", "unsigned char", "short", "unsigned short", "int",
                                  "signed", "unsigned", "unsigned int", "long", "unsigned long", "long long", "unsigned long long",
                                  "long double", "float", "double", "NSInteger", "NSUInteger", "CGFloat", "NSTimeInterval", "size_t",
                                  "int8_t", "int16_t", "int32_t", "int64_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t"})

local NULLABILITY_WORDS = strings.set({"_Nullable", "_Nonnull", "__nullable", "__nonnull", "_Null_unspecified", "nullable",
                                       "nonnull", "null_resettable", "null_unspecified"})

local KEYWORD_WORDS = strings.set({"void", "char", "short", "int", "long", "float", "double", "signed", "unsigned", "_Bool", "bool",
                                   "const", "volatile", "restrict", "struct", "enum", "union", "id", "instancetype", "__kindof",
                                   "__autoreleasing", "__strong", "__weak", "__unsafe_unretained"})

local TYPE_LEADERS = strings.set({"struct", "enum", "union", "const", "volatile"})

local function is_macro_word(word)
    return string.match(word, "^_*[A-Z][A-Z0-9]*_[A-Z0-9_]*$") ~= nil
end

function canonical(text, index)
    index = index or {}
    local out = string.gsub(text or "", "[%w_]+", function(word)
        if NULLABILITY_WORDS[word] or (is_macro_word(word) and index[word] == nil) then
            return " "
        end
    end)
    out = strings.collapse(out)
    out = string.gsub(string.gsub(out, "%s+([%),>])", "%1"), "([%(<])%s+", "%1")
    local joined = string.gsub(out, "%*%s+%*", "**")
    while joined ~= out do
        out = joined
        joined = string.gsub(out, "%*%s+%*", "**")
    end
    return strings.strip(out)
end

function kind_of(type_text, index, visited)
    index = index or {}
    visited = visited or {}
    local text = canonical(type_text, index)
    if text == "void" then
        return "void"
    end
    if text == "id" or text == "instancetype" or string.find(text, "*", 1, true) or string.find(text, "^", 1, true)
            or string.find(text, "<", 1, true) then
        return "object"
    end
    local bare = string.match(text, "^const%s+(.*)$") or text
    if SCALAR_TYPES[bare] then
        return "scalar"
    end
    if string.sub(bare, 1, 5) == "enum " then
        return "scalar"
    end
    if string.sub(bare, 1, 7) == "struct " or string.sub(bare, 1, 6) == "union " then
        return "struct"
    end
    if string.find(bare, "__attribute__((ext_vector_type(", 1, true) then
        return "struct"
    end
    if index[bare] ~= nil and not visited[bare] then
        visited[bare] = true
        return kind_of(index[bare], index, visited)
    end
    return nil
end

function is_error_out(type_text, index)
    return string.gsub(canonical(type_text, index), " ", "") == "NSError**"
end

local function split_name(part, index)
    local text = canonical(part, index)
    local words = {}
    for word in string.gmatch(text, "%S+") do
        table.insert(words, word)
    end
    local count = #words
    local last = words[count]
    if count >= 2 and string.match(last, "^[%a_][%w_]*$") and not KEYWORD_WORDS[last] and not TYPE_LEADERS[words[count - 1]] then
        table.remove(words)
        return table.concat(words, " "), last
    end
    return text, nil
end

function parse_params(text, index)
    local out = {}
    if text == nil or text == "" or text == "-" then
        return out
    end
    local pos = 1
    while true do
        local at = string.find(text, " | ", pos, true)
        local part = at and string.sub(text, pos, at - 1) or string.sub(text, pos)
        local type_text, name = split_name(part, index)
        table.insert(out, {type = type_text, name = name})
        if at == nil then
            return out
        end
        pos = at + 3
    end
end

function function_return(type_text, index)
    local text = strings.strip(type_text or "")
    if string.sub(text, -1) ~= ")" then
        return nil
    end
    local depth = 0
    for i = #text, 1, -1 do
        local c = string.sub(text, i, i)
        if c == ")" then
            depth = depth + 1
        elseif c == "(" then
            depth = depth - 1
            if depth == 0 then
                return canonical(string.sub(text, 1, i - 1), index)
            end
        end
    end
    return nil
end

function attribute_value(attrs, key)
    for entry in string.gmatch(attrs or "", "[^,]+") do
        local value = string.match(entry, "^" .. key .. "=(.*)$")
        if value then
            return strings.strip(value)
        end
    end
    return nil
end

function has_attribute(attrs, name)
    for entry in string.gmatch(attrs or "", "[^,]+") do
        if strings.strip(entry) == name then
            return true
        end
    end
    return false
end

function member_name(api)
    local trimmed = string.gsub(api, "%]+$", "")
    return string.match(trimmed, "(%S+)%s*$")
end

local function group_end(text, i)
    local depth = 0
    for j = i, #text do
        local c = string.sub(text, j, j)
        if c == "(" then
            depth = depth + 1
        elseif c == ")" then
            depth = depth - 1
            if depth == 0 then
                return j + 1
            end
        end
    end
    return nil
end

function selector_of(statement)
    local s = strings.strip((string.gsub(statement, "^[%-%+ ]+", "")))
    local pos = 1
    if string.sub(s, 1, 1) == "(" then
        pos = group_end(s, 1) or (#s + 1)
    end
    local rest = string.sub(s, pos)
    if string.find(rest, ":", 1, true) == nil then
        local word = nil
        for run in string.gmatch(rest, "[%w_]+") do
            word = string.match(run, "[%a_][%w_]*") or word
        end
        return word
    end
    local parts = {}
    local i = pos
    local colon = string.find(s, ":", i, true)
    while colon ~= nil do
        local keyword = string.match(string.sub(s, i, colon - 1), "([%a_][%w_]*)%s*$") or ""
        table.insert(parts, keyword .. ":")
        local after = colon + 1
        local open = string.match(s, "^%s*()%(", after)
        if open ~= nil then
            after = group_end(s, open) or (#s + 1)
        end
        i = string.match(s, "^%s*[%a_][%w_]*()", after) or after
        colon = string.find(s, ":", i, true)
    end
    return table.concat(parts)
end
