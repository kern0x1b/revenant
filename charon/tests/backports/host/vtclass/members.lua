-- members.lua - WHAT A CLASS HAS, derived once. A MODULE: import("members", {rootdir = os.scriptdir()}).
-- Port of members.py. Its exports are the functions below; each Python module constant is a function that
-- returns the constant (a regular expression's constant is its Python pattern text, and the matching is
-- done by the hand-written function beside it).
--
--     members_of("VTMotionBlurConfiguration") -> {entries = {{kind, registry name}, ...},
--                                                 accessors = {selector or property -> property or false}}
--
-- entries is the Python set, returned SORTED by kind and then by registry name (byte order), because no
-- caller depends on a set's own order. accessors is the Python dict; Python's None is false here, since
-- a Lua table holds no nil value and "key present with no property" must stay distinguishable from
-- "key absent" (HAND_ACCESSOR's `selector in accessors`).
--
-- HERE is the directory of the running script. The modules are reached only from the vtclass directory,
-- so that is the directory of this file for every caller (Python's __file__ is this file, and
-- abspath(__file__) is what HERE is made from).

local S = import("pystr", {rootdir = os.scriptdir()})
local V = import("vtlib", {rootdir = os.scriptdir()})

-- Module constants --------------------------------------------------------------------------------------

function HERE()
    return S.normpath(os.scriptdir())
end

-- os.path.abspath(os.path.join(HERE, "..", "..", "..", "..")): the worktree.
function WORKTREE()
    return S.normpath(HERE() .. "/../../../..")
end

function VT_DIR()
    return WORKTREE() .. "/packages/a/apple-backports/VideoToolbox"
end

function HEADER()
    return VT_DIR() .. "/CharonVideoToolbox.h"
end

-- The template's class lives in the file that carries the protocols, hand-written, with its initialiser
-- already in it. Every other class has a generated file of its own.
function TEMPLATE_CLASS()
    return "VTMotionBlurConfiguration"
end

function TEMPLATE_FILE()
    return "VideoToolboxValue26.m"
end

-- The Python patterns, as text. The matchers are the functions further down, and each states the
-- pattern it stands for.
function INITIALISER()
    return [==[^[+-]\s*\([^)]*instancetype[^)]*\)([^;]*);]==]
end

function SELECTOR_KEYWORD()
    return [==[(\w+):]==]
end

function PROPERTY_ROW()
    return [==[@property\s*\(([^)]*)\)\s*[^;]*?\s(\w+)\s*(?:[A-Z_][A-Z_0-9]*\s*(?:\([^)]*\))?)?;]==]
end

-- Defined in members.py and never used there (no caller, no match): kept so the constant exists.
function METHOD_DECL()
    return [==[^([+-])\s*\(([^)]*)\)\s*(\w*[:\w]*)]==]
end

function MACRO_ACCESSOR()
    return [==[CHARON_\w+_PROPERTY\((.*)\)]==]
end

function HAND_ACCESSOR()
    return [==[([-+])\s*\([^)]*\)\s*(\w+)]==]
end

-- Defined in members.py and never used there.
function INITIALISER_KEYWORD()
    return [==[@"(charon\.private\.)?(\w+)"]==]
end

-- Helpers -----------------------------------------------------------------------------------------------

-- Python's open(path).read(): the file's text, with the newlines text mode gives. A missing file is an
-- uncaught FileNotFoundError in Python, which exits 1.
local function read_checked(path)
    if not os.isfile(path) then
        V.fail("FileNotFoundError: [Errno 2] No such file or directory: '" .. path .. "'")
    end
    return V.read_text(path)
end

-- Python's _value_file_for(class_name).
function _value_file_for(class_name)
    local file = class_name .. ".m"
    if class_name == TEMPLATE_CLASS() then
        file = TEMPLATE_FILE()
    end
    return VT_DIR() .. "/" .. file
end

-- Python's _registry_name(kind, class_name, member).
function _registry_name(kind, class_name, member)
    if kind == "class" then
        return class_name
    end
    if kind == "method" then
        return "-[" .. class_name .. " " .. member .. "]"
    end
    return class_name .. "." .. member
end

-- Python's selector_of(declaration_span): the whole selector, every keyword between the return type and
-- the ';', each with its colon. Python: "".join(k + ":" for k in SELECTOR_KEYWORD.findall(span)).
-- SELECTOR_KEYWORD = r'(\w+):'. Hand-matched: a match is a maximal run of word bytes that is followed
-- directly by ':'. A run not followed by ':' cannot be matched from any of its starts either, so the scan
-- steps over the whole run; after a match the scan resumes after the ':'.
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

-- Python's joined_declarations(text): every declaration, as {first line number, text}, from its first
-- non-blank line to the line holding the ';' that ends it, with the whitespace collapsed to single spaces.
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

-- The class block -----------------------------------------------------------------------------------------

-- re.match(r'@interface\s+' + re.escape(class_name) + r'\b', line): anchored at the start of the line.
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

-- re.match(r'@(interface|protocol|end)\b', line): anchored, and the keyword ends at a word boundary.
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

-- Python's class_block(header, class_name): this class's own block, from its @interface line to the line
-- BEFORE the next @interface, @protocol or @end; to the end of the header when none follows; nil when the
-- class has no @interface line. A line scan, so the block is not cut at the first "@end" of the text.
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

-- The pattern matchers -------------------------------------------------------------------------------------

-- Python: INITIALISER.findall(text), INITIALISER = r'^[+-]\s*\([^)]*instancetype[^)]*\)([^;]*);' with re.M.
-- Returns the group, which is the span after the return type's ')' up to the ';'.
-- Hand-matched. A match begins at a '+' or '-' that opens a line (position 1, or just after a "\n"). Then
-- \s* (whitespace, newlines included), then '(', then the text up to the FIRST ')' must contain
-- "instancetype" (the two [^)]* together say exactly that: they cannot cross a ')'). The ')' is the first
-- ')' after the '('. Then ([^;]*) takes everything up to the FIRST ';' after that ')', crossing newlines
-- and ')' characters alike, and ';' is that first ';'. Every choice is forced, so there is nothing to
-- backtrack over. findall resumes after the ';'.
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

-- Python: re.search(r'getter\s*=\s*(\w+)', attrs).group(1), or nil.
-- Hand-matched: each "getter" occurrence is tried in order; then \s*, then '=', then \s*, then the word run
-- (at least one byte). A run of whitespace that is not followed by a word byte cannot be given back.
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

-- The tail of PROPERTY_ROW after its (\w+): \s*(?:[A-Z_][A-Z_0-9]*\s*(?:\([^)]*\))?)?; taken from index r.
-- Returns the index after the ';', or nil. The regex order is kept: the macro group before the group's
-- absence, and within the group the paren part before its absence.
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

-- One PROPERTY_ROW match beginning at index at (which holds "@property"): returns attrs, name and the index
-- after the match, or nil.
-- Python: @property\s*\(([^)]*)\)\s*[^;]*?\s(\w+)\s*(?:...)?; with re.S (no '.' in the pattern, so re.S
-- changes nothing). Hand-matched, with every choice enumerated in the order the regex engine tries them:
--   1. \s* is skipped and '(' must follow; ([^)]*) runs to the FIRST ')', which must be there.
--   2. The outer \s* takes its whitespace greedily: k = all of it, then one byte fewer, and so on.
--   3. [^;]*? is lazy: the \s after it is tried at base, base+1, ... and the walk stops at the first ';'
--      (a ';' cannot be consumed by [^;]).
--   4. \s is that byte, and (\w+) must start right after it: the longest word run first, then each shorter.
--   5. property_tail decides the rest. The paren part of the macro group, [^)]*, MAY cross a ';', so the
--      terminating ';' is not always the first ';' after the attributes.
-- The first success is the match, which is what Python's search returns.
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

-- Python: PROPERTY_ROW.findall(text), as {attrs, name} pairs in order.
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

-- Python: MACRO_ACCESSOR.findall(text), MACRO_ACCESSOR = r'CHARON_\w+_PROPERTY\((.*)\)' with re.S.
-- Returns the groups, as a list (at most one element, as the analysis below shows).
-- Hand-matched. At "CHARON_" the word run that follows it is taken whole; the pattern needs "_PROPERTY("
-- to end that run exactly (the '(' is not a word byte), and the \w+ before it must be at least one byte.
-- Then (.*) is greedy with re.S, so it runs to the LAST ')' of the whole text. The first "CHARON_" whose
-- '(' comes before that last ')' matches, and its group is everything between the two. Nothing follows
-- the last ')', so no later match can start, and the scan stops after the first.
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
        local at = string.find(text, "CHARON_", i, true)
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

-- Python: HAND_ACCESSOR.findall(text), HAND_ACCESSOR = r'([-+])\s*\([^)]*\)\s*(\w+)' with no flags. Returns
-- the second group (the sign is not used by members.py), as a list.
-- Hand-matched: at each '-' or '+' (no anchor): \s*, then '(', then the text up to the FIRST ')', then \s*,
-- then the word run, which must hold at least one byte. The whitespace after ')' cannot be given back
-- to the word, since a word byte is not whitespace. findall resumes after the word.
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

-- members_of ---------------------------------------------------------------------------------------------

-- Adds a (kind, name) to a set keyed by both.
local function add_entry(entries, kind, name)
    entries[kind .. "\0" .. name] = {kind, name}
end

-- The set's members, sorted by kind and then by name, as byte order.
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

-- Python's members_of(class_name): {"entries": {(kind, registry name), ...}, "accessors": {...}}.
-- The header and the value file are read in the Python's order, and the class block's absence is the
-- ValueError it raises (uncaught, so exit 1).
function members_of(class_name)
    local header = read_checked(HEADER())
    local source = read_checked(_value_file_for(class_name))

    local body = class_block(header, class_name)
    if body == nil then
        V.fail("ValueError: " .. class_name .. ": the port's header declares no such class")
    end
    -- COMMENTS ARE STRIPPED, LINE BY LINE, BEFORE ANY DECLARATION IS JOINED: a line whose stripped text
    -- begins with "//", "/*" or "*" (which "*/" begins with too) is dropped.
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

    -- properties: the PROPERTY name, with its getter if it has one
    for _, row in ipairs(property_rows(body_text)) do
        local attrs, name = row[1], row[2]
        add_entry(entries, "property", _registry_name("property", class_name, name))
        local getter = getter_of(attrs)
        accessors[getter or name] = name
    end
    -- initialisers, as the SDK spells the selector: the whole selector, after the join
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

    -- the accessors the value file implements, and the properties they belong to
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

-- Python's accessors_of_class(class_name): just the accessor map.
function accessors_of_class(class_name)
    return members_of(class_name).accessors
end
