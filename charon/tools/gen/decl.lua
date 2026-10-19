-- The typed fields the trace layer reads (design-foundation.md 5.7): the spelling of a type, the kind a type is, the parameters of a
-- method or a C function, the NSError ** test, and the names an api gives. Each function reads the typed columns of a shard row
-- (type, params, attrs) and the typedef index (name -> the underlying type the shard's typedef row gives). None reads declaration
-- text. member_name and selector_of are the names the spec rows and the hand sources are keyed by.

local strings = import("strings", {anonymous = true})

-- The types a scalar is: a type of one of these spellings, or a typedef of one, is a scalar.
local SCALAR_TYPES = strings.set({"BOOL", "bool", "_Bool", "char", "signed char", "unsigned char", "short", "unsigned short", "int",
                                  "signed", "unsigned", "unsigned int", "long", "unsigned long", "long long", "unsigned long long",
                                  "long double", "float", "double", "NSInteger", "NSUInteger", "CGFloat", "NSTimeInterval", "size_t",
                                  "int8_t", "int16_t", "int32_t", "int64_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t"})

-- The words the SDK's nullability annotations spell: removed from every type.
local NULLABILITY_WORDS = strings.set({"_Nullable", "_Nonnull", "__nullable", "__nonnull", "_Null_unspecified", "nullable",
                                       "nonnull", "null_resettable", "null_unspecified"})

-- The words a parameter's name cannot be: a type keyword, a qualifier, or a tag, so that the last word of a parameter is its type.
local KEYWORD_WORDS = strings.set({"void", "char", "short", "int", "long", "float", "double", "signed", "unsigned", "_Bool", "bool",
                                   "const", "volatile", "restrict", "struct", "enum", "union", "id", "instancetype", "__kindof",
                                   "__autoreleasing", "__strong", "__weak", "__unsafe_unretained"})

-- The words a parameter's last word is not a name after: the tag or the qualifier of an unnamed type.
local TYPE_LEADERS = strings.set({"struct", "enum", "union", "const", "volatile"})

-- True when a word is a macro the extractor leaves in a type: all capitals with an underscore after the first letter (API_AVAILABLE,
-- NS_REFINED_FOR_SWIFT, __TVOS_PROHIBITED). A typedef named so (CBLAS_TRANSPOSE) is not one.
local function is_macro_word(word)
    return string.match(word, "^_*[A-Z][A-Z0-9]*_[A-Z0-9_]*$") ~= nil
end

-- The spelling of a type as a stub writes it: no nullability word and no macro word (index names are kept), single spaces, and each
-- run of stars one run ("NSError * *" is "NSError **"). index: typedef name -> underlying type.
function canonical(text, index)
    index = index or {}
    local out = string.gsub(text or "", "[%w_]+", function(word)
        if NULLABILITY_WORDS[word] or (is_macro_word(word) and index[word] == nil) then
            return " "
        end
    end)
    out = strings.collapse(out)
    -- the space a removed word leaves before a closing bracket or a comma, and after an opening one, goes
    out = string.gsub(string.gsub(out, "%s+([%),>])", "%1"), "([%(<])%s+", "%1")
    local joined = string.gsub(out, "%*%s+%*", "**")
    while joined ~= out do
        out = joined
        joined = string.gsub(out, "%*%s+%*", "**")
    end
    return strings.strip(out)
end

-- 'void', 'object', 'scalar' or 'struct' for a type, through the typedefs (index: typedef name -> the underlying type the shard gives).
-- nil when the type is not known: a name no typedef names and no scalar spells is not guessed. A typedef chain is followed to its end;
-- a name met again on the chain (a typedef that names itself, through others) is a cycle and gives nil, so no depth is capped.
-- visited: the typedef names already on the chain (for the callers' use, nil at the top).
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
    -- a vector type (simd's float3 and the like, spelled "float __attribute__((ext_vector_type(3)))") is a value a compound literal
    -- zeroes as a struct is, so it is a struct here
    if string.find(bare, "__attribute__((ext_vector_type(", 1, true) then
        return "struct"
    end
    if index[bare] ~= nil and not visited[bare] then
        visited[bare] = true
        return kind_of(index[bare], index, visited)
    end
    return nil
end

-- True when a parameter's type is NSError ** once its nullability words are gone (the out-error argument of a method or a function).
function is_error_out(type_text, index)
    return string.gsub(canonical(type_text, index), " ", "") == "NSError**"
end

-- The name a parameter part gives, and its type: the last word is the name when it is not a keyword and the word before it is not a
-- tag or a qualifier (so "unsigned int", "struct CGRect" and "NSError **" are types). Returns type, name (name nil when unnamed).
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

-- The parameters of a method or a function from its params column ("TYPE NAME | TYPE NAME"; "-" or "" for none): a list of {type, name}
-- in order, the name nil for an unnamed parameter. index: typedef name -> underlying type (the nullability and macro words go).
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

-- The return type of a C function from its type text ("RET (PARAMS)"): the text before the parameter list, which is the parenthesised
-- group that closes the text. nil when the text does not close with one.
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

-- The value of one attribute of a property's attrs column ("nonatomic,getter=isEnabled"), or nil. "-" and "" have none.
function attribute_value(attrs, key)
    for entry in string.gmatch(attrs or "", "[^,]+") do
        local value = string.match(entry, "^" .. key .. "=(.*)$")
        if value then
            return strings.strip(value)
        end
    end
    return nil
end

-- True when the attrs column has the attribute by its bare name (readonly, copy, class).
function has_attribute(attrs, name)
    for entry in string.gmatch(attrs or "", "[^,]+") do
        if strings.strip(entry) == name then
            return true
        end
    end
    return false
end

-- The name a member row's api ends in: its last word once the closing brackets are gone (api.rstrip("]").split()[-1]).
function member_name(api)
    local trimmed = string.gsub(api, "%]+$", "")
    return string.match(trimmed, "(%S+)%s*$")
end

-- The index just past the parenthesised group that opens at text[i] (nested groups counted), or nil when the group does not close.
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

-- The selector a statement names: each parameter's keyword with its colon, or the last word of a selector with no colon. A parameter is
-- its keyword (possibly empty), its colon, its type (a group) and its name (the word after the group). The name is read as a name, so the
-- colon after it is the next parameter's, and an empty keyword stays: size:(size_t)width :(size_t)height format:(int)f names size::format:.
-- The statement's return type (its first group) is skipped. nil or "" when the statement names none. The hand sources' method signatures
-- are read through it (hand.lua).
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
