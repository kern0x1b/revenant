local S = import("pystr", {rootdir = os.scriptdir()})
local V = import("vtlib", {rootdir = os.scriptdir()})

function HERE()
    return S.normpath(os.scriptdir())
end

function WORKTREE()
    return S.normpath(HERE() .. "/../../../..")
end

function VT_DIR()
    return WORKTREE() .. "/packages/a/apple-backports/VideoToolbox"
end

function HEADER()
    return VT_DIR() .. "/RevenantVideoToolbox.h"
end

function TEMPLATE_CLASS()
    return "VTMotionBlurConfiguration"
end

function TEMPLATE_FILE()
    return "VideoToolboxValue26.m"
end

function INITIALISER()
    return [==[^[+-]\s*\([^)]*instancetype[^)]*\)([^;]*);]==]
end

function SELECTOR_KEYWORD()
    return [==[(\w+):]==]
end

function PROPERTY_ROW()
    return [==[@property\s*\(([^)]*)\)\s*[^;]*?\s(\w+)\s*(?:[A-Z_][A-Z_0-9]*\s*(?:\([^)]*\))?)?;]==]
end

function METHOD_DECL()
    return [==[^([+-])\s*\(([^)]*)\)\s*(\w*[:\w]*)]==]
end

function MACRO_ACCESSOR()
    return [==[REVENANT_\w+_PROPERTY\((.*)\)]==]
end

function HAND_ACCESSOR()
    return [==[([-+])\s*\([^)]*\)\s*(\w+)]==]
end

function INITIALISER_KEYWORD()
    return [==[@"(revenant\.private\.)?(\w+)"]==]
end

local function read_checked(path)
    if not os.isfile(path) then
        V.fail("FileNotFoundError: [Errno 2] No such file or directory: '" .. path .. "'")
    end
    return V.read_text(path)
end

function _value_file_for(class_name)
    local file = class_name .. ".m"
    if class_name == TEMPLATE_CLASS() then
        file = TEMPLATE_FILE()
    end
    return VT_DIR() .. "/" .. file
end

function _registry_name(kind, class_name, member)
    if kind == "class" then
        return class_name
    end
    if kind == "method" then
        return "-[" .. class_name .. " " .. member .. "]"
    end
    return class_name .. "." .. member
end

function selector_of(declaration_span)
    local parts = {}
    local i = 1
    local n = #declaration_span
    while i <= n do
        if S.is_word(string.byte(declaration_span, i)) then
            local stop = S.skip_word(declaration_span, i)
            if string.byte(declaration_span, stop) == 58 then
                parts[#parts + 1] = string.sub(declaration_span, i, stop - 1) .. ":"
                i = stop + 1
            else
                i = stop
            end
        else
            i = i + 1
        end
    end
    return table.concat(parts)
end

function joined_declarations(text)
    local out = {}
    local buffer = nil
    local start = 0
    local lines = S.split_newlines(text)
    for index = 1, #lines do
        local line = lines[index]
        local skip = buffer == nil and S.strip(line) == ""
        if not skip then
            if buffer == nil then
                start = index
                buffer = line
            else
                buffer = buffer .. " " .. S.strip(line)
            end
            if S.contains(buffer, ";") then
                out[#out + 1] = {start, S.collapse(buffer)}
                buffer = nil
            end
        end
    end
    if buffer ~= nil then
        out[#out + 1] = {start, S.collapse(buffer)}
    end
    return out
end

local function interface_line(line, class_name)
    if string.sub(line, 1, 10) ~= "@interface" then
        return false
    end
    local name_at = S.skip_space(line, 11)
    if name_at == 11 then
        return false
    end
    if string.sub(line, name_at, name_at + #class_name - 1) ~= class_name then
        return false
    end
    local after = name_at + #class_name
    return S.is_word(string.byte(class_name, #class_name)) ~= S.is_word(S.byte_at(line, after))
end

local function block_end(line)
    local words = {"interface", "protocol", "end"}
    for _, word in ipairs(words) do
        local keyword = "@" .. word
        if string.sub(line, 1, #keyword) == keyword and not S.is_word(S.byte_at(line, #keyword + 1)) then
            return true
        end
    end
    return false
end

function class_block(header, class_name)
    local lines = S.split_newlines(header)
    local start = nil
    for index = 1, #lines do
        local line = lines[index]
        if start == nil then
            if interface_line(line, class_name) then
                start = index
            end
        elseif block_end(line) then
            return table.concat(lines, "\n", start, index - 1)
        end
    end
    if start ~= nil then
        return table.concat(lines, "\n", start, #lines)
    end
    return nil
end

function initialiser_spans(text)
    local spans = {}
    local i = 1
    local n = #text
    while i <= n do
        local b = string.byte(text, i)
        local opens_line = (i == 1) or string.byte(text, i - 1) == 10
        local matched = false
        if opens_line and (b == 43 or b == 45) then
            local open = S.skip_space(text, i + 1)
            if S.byte_at(text, open) == 40 then
                local close = string.find(text, ")", open + 1, true)
                if close ~= nil and S.contains(string.sub(text, open + 1, close - 1), "instancetype") then
                    local semi = string.find(text, ";", close + 1, true)
                    if semi ~= nil then
                        spans[#spans + 1] = string.sub(text, close + 1, semi - 1)
                        i = semi + 1
                        matched = true
                    end
                end
            end
        end
        if not matched then
            i = i + 1
        end
    end
    return spans
end

local function getter_of(attrs)
    local start = 1
    while true do
        local at = string.find(attrs, "getter", start, true)
        if at == nil then
            return nil
        end
        local equals = S.skip_space(attrs, at + 6)
        if S.byte_at(attrs, equals) == 61 then
            local word = S.skip_space(attrs, equals + 1)
            local word_end = S.skip_word(attrs, word)
            if word_end > word then
                return string.sub(attrs, word, word_end - 1)
            end
        end
        start = at + 1
    end
end

local function property_tail(text, r)
    local t = S.skip_space(text, r)
    if S.is_upper_or_underscore(S.byte_at(text, t)) then
        local u = t + 1
        while S.is_upper_digit_or_underscore(S.byte_at(text, u)) do
            u = u + 1
        end
        local v = S.skip_space(text, u)
        if S.byte_at(text, v) == 40 then
            local close = string.find(text, ")", v + 1, true)
            if close ~= nil and S.byte_at(text, close + 1) == 59 then
                return close + 2
            end
        end
        if S.byte_at(text, v) == 59 then
            return v + 1
        end
    end
    if S.byte_at(text, t) == 59 then
        return t + 1
    end
    return nil
end

local function property_match_at(text, at)
    local open = S.skip_space(text, at + 9)
    if S.byte_at(text, open) ~= 40 then
        return nil
    end
    local close = string.find(text, ")", open + 1, true)
    if close == nil then
        return nil
    end
    local attrs = string.sub(text, open + 1, close - 1)
    local after_attrs = close + 1
    local kmax = S.skip_space(text, after_attrs) - after_attrs
    local n = #text
    for k = kmax, 0, -1 do
        local base = after_attrs + k
        local p = base
        while p <= n do
            local b = string.byte(text, p)
            if S.is_space(b) and S.is_word(S.byte_at(text, p + 1)) then
                local word_start = p + 1
                local word_end = S.skip_word(text, word_start)
                for r = word_end, word_start + 1, -1 do
                    local stop = property_tail(text, r)
                    if stop ~= nil then
                        return attrs, string.sub(text, word_start, r - 1), stop
                    end
                end
            end
            if b == 59 then
                break
            end
            p = p + 1
        end
    end
    return nil
end

function property_rows(text)
    local rows = {}
    local i = 1
    while true do
        local at = string.find(text, "@property", i, true)
        if at == nil then
            break
        end
        local attrs, name, stop = property_match_at(text, at)
        if attrs ~= nil then
            rows[#rows + 1] = {attrs, name}
            i = stop
        else
            i = at + 1
        end
    end
    return rows
end

function macro_accessor_calls(text)
    local calls = {}
    local last_close = nil
    for i = #text, 1, -1 do
        if string.byte(text, i) == 41 then
            last_close = i
            break
        end
    end
    if last_close == nil then
        return calls
    end
    local i = 1
    while true do
        local at = string.find(text, "REVENANT_", i, true)
        if at == nil then
            break
        end
        local run_end = S.skip_word(text, at + 7)
        if S.byte_at(text, run_end) == 40
                and run_end - 9 >= at + 8
                and string.sub(text, run_end - 9, run_end - 1) == "_PROPERTY"
                and last_close > run_end then
            calls[#calls + 1] = string.sub(text, run_end + 1, last_close - 1)
            return calls
        end
        i = at + 1
    end
    return calls
end

function hand_accessors(text)
    local out = {}
    local i = 1
    local n = #text
    while i <= n do
        local b = string.byte(text, i)
        local matched = false
        if b == 45 or b == 43 then
            local open = S.skip_space(text, i + 1)
            if S.byte_at(text, open) == 40 then
                local close = string.find(text, ")", open + 1, true)
                if close ~= nil then
                    local word = S.skip_space(text, close + 1)
                    local word_end = S.skip_word(text, word)
                    if word_end > word then
                        out[#out + 1] = string.sub(text, word, word_end - 1)
                        i = word_end
                        matched = true
                    end
                end
            end
        end
        if not matched then
            i = i + 1
        end
    end
    return out
end

local function add_entry(entries, kind, name)
    entries[kind .. "\0" .. name] = {kind, name}
end

local function sorted_entries(entries)
    local list = {}
    for _, entry in pairs(entries) do
        list[#list + 1] = entry
    end
    table.sort(list, function(a, b)
        if a[1] ~= b[1] then
            return V.byte_less(a[1], b[1])
        end
        return V.byte_less(a[2], b[2])
    end)
    return list
end

function members_of(class_name)
    local header = read_checked(HEADER())
    local source = read_checked(_value_file_for(class_name))

    local body = class_block(header, class_name)
    if body == nil then
        V.fail("ValueError: " .. class_name .. ": the port's header declares no such class")
    end
    local kept = {}
    for _, line in ipairs(S.split_newlines(body)) do
        local stripped = S.strip(line)
        if not (S.starts_with(stripped, "//") or S.starts_with(stripped, "/*") or S.starts_with(stripped, "*")) then
            kept[#kept + 1] = line
        end
    end
    body = table.concat(kept, "\n")

    local entries = {}
    local accessors = {}
    add_entry(entries, "class", _registry_name("class", class_name, class_name))

    local body_decls = {}
    for _, decl in ipairs(joined_declarations(body)) do
        body_decls[#body_decls + 1] = decl[2]
    end
    local body_text = table.concat(body_decls, ";\n")

    for _, row in ipairs(property_rows(body_text)) do
        local attrs, name = row[1], row[2]
        add_entry(entries, "property", _registry_name("property", class_name, name))
        local getter = getter_of(attrs)
        accessors[getter or name] = name
    end
    for _, span in ipairs(initialiser_spans(body_text)) do
        local selector = selector_of(span)
        add_entry(entries, "method", _registry_name("method", class_name, selector))
        accessors[selector] = false
    end

    local source_decls = {}
    for _, decl in ipairs(joined_declarations(source)) do
        source_decls[#source_decls + 1] = decl[2]
    end
    local source_text = table.concat(source_decls, "\n")

    for _, call in ipairs(macro_accessor_calls(source_text)) do
        local last = S.strip(S.last_piece(call, ","))
        if S.is_word_string(last) then
            if accessors[last] == nil then
                accessors[last] = false
            end
        end
    end
    for _, selector in ipairs(hand_accessors(source_text)) do
        local known = accessors[selector] ~= nil
        if not known and not S.starts_with(selector, "init") then
            accessors[selector] = false
        end
    end

    return {entries = sorted_entries(entries), accessors = accessors}
end

function accessors_of_class(class_name)
    return members_of(class_name).accessors
end
