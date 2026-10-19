-- availability.lua - WHICH IOS RELEASE DECLARES A CLASS, read from the SDK's own headers.
-- A MODULE: import("availability", {rootdir = os.scriptdir()}); its exports are the functions below.
-- Port of availability.py, function for function. Python's regular expressions are matched by hand here
-- (the windows, the paren count and the \bios( search); each is stated in the comment beside its code.
--
-- Four spellings of a class declaration exist in the SDK's headers, and the rule is the same for all of
-- them: the class is found ANYWHERE in the text, and its availability is the LAST API_AVAILABLE in the
-- window between the previous @end or @interface and the class's own @interface. Parentheses are
-- counted, because API_AVAILABLE(macos(15.4), ios(26.0)) carries parentheses of its own.
--
-- Offsets: find_interface and the window arithmetic use Python's 0-based offsets, so each line below
-- that adds or subtracts 1 when it indexes a Lua string says so.

local S = import("pystr", {rootdir = os.scriptdir()})

-- The 0-based start of the LAST occurrence of needle that lies wholly inside text, or -1: Python's
-- text.rfind(needle).
local function last_index(text, needle)
    local found = -1
    local start = 1
    while true do
        local at = string.find(text, needle, start, true)
        if not at then
            return found
        end
        found = at - 1
        start = at + 1
    end
end

-- Python's re.search(r'@interface\s+' + re.escape(name) + r'\b', text), returning the 0-based start of
-- the match, or nil. Hand-matched: each "@interface" occurrence is tried in order, then one or more
-- whitespace bytes (\s+ takes the whole run, since the name begins with a non-space byte), then the name
-- byte for byte, then \b, which holds where the last byte of the name and the byte after it differ in
-- word-ness. Every class name here ends in a word byte, so \b holds exactly when the next byte is not one.
function interface_at(text, name)
    local start = 1
    while true do
        local at = string.find(text, "@interface", start, true)
        if not at then
            return nil
        end
        local name_at = S.skip_space(text, at + 10)
        if name_at > at + 10 and string.sub(text, name_at, name_at + #name - 1) == name then
            local after = name_at + #name
            if S.is_word(string.byte(name, #name)) ~= S.is_word(S.byte_at(text, after)) then
                return at - 1
            end
        end
        start = at + 1
    end
end

-- Python's find_interface(text, name): where this class's @interface is, or raise naming it.
function find_interface(text, name)
    local at = interface_at(text, name)
    if at == nil then
        raise("no @interface " .. name)
    end
    return at
end

-- Python's _balanced(text, start): the parenthesised group beginning at the 0-based index start, to its
-- matching ')'. Counts depth; a ')' that returns the depth to 0 ends the group. Raises when it never does.
function _balanced(text, start)
    local depth = 0
    for i = start, #text - 1 do
        local b = string.byte(text, i + 1)
        if b == 40 then
            depth = depth + 1
        elseif b == 41 then
            depth = depth - 1
            if depth == 0 then
                return string.sub(text, start + 1, i + 1)
            end
        end
    end
    raise("unbalanced parentheses")
end

-- Python's re.search(r'\bios\(\s*([0-9]+(?:\.[0-9]+)*)\s*\)', macro).group(1), or nil.
-- Hand-matched: each "ios(" occurrence is tried in order; it must begin a word (the byte before it is not
-- a word byte, which is what \b means before the 'i'); then whitespace, then digits, then any number of
-- ".digits" groups, then whitespace, then ')'. The digit and dot-group run is maximal: a shorter run would
-- end on a digit or a '.', and neither can be followed by whitespace or ')', so no backtracking is needed.
local function ios_version(macro)
    local start = 1
    while true do
        local at = string.find(macro, "ios(", start, true)
        if not at then
            return nil
        end
        if not S.is_word(S.byte_at(macro, at - 1)) then
            local first = S.skip_space(macro, at + 4)
            if S.is_digit(S.byte_at(macro, first)) then
                local k = first
                while S.is_digit(S.byte_at(macro, k)) do
                    k = k + 1
                end
                while S.byte_at(macro, k) == 46 and S.is_digit(S.byte_at(macro, k + 1)) do
                    k = k + 1
                    while S.is_digit(S.byte_at(macro, k)) do
                        k = k + 1
                    end
                end
                local close = S.skip_space(macro, k)
                if S.byte_at(macro, close) == 41 then
                    return string.sub(macro, first, k - 1)
                end
            end
        end
        start = at + 1
    end
end

-- Python's availability_of(text, name): (ios version, the line the macro is on), or raise naming the
-- class and printing the window.
function availability_of(text, name)
    local pos = find_interface(text, name)
    local head = string.sub(text, 1, pos)
    -- bound = max(head.rfind('@end'), head.rfind('@interface'))
    local bound = math.max(last_index(head, "@end"), last_index(head, "@interface"))
    -- window = head[bound + 1:]
    local window = string.sub(head, bound + 2)
    -- hits = [m.start() for m in re.finditer(r'API_AVAILABLE\(', window)], 0-based
    local hits = {}
    local start = 1
    while true do
        local at = string.find(window, "API_AVAILABLE(", start, true)
        if not at then
            break
        end
        hits[#hits + 1] = at - 1
        start = at + 1
    end
    if #hits == 0 then
        raise(name .. ": no API_AVAILABLE above its @interface; window:\n" .. window)
    end
    local last = hits[#hits]
    -- macro = _balanced(window, hits[-1] + len('API_AVAILABLE'))
    local macro = _balanced(window, last + #"API_AVAILABLE")
    local version = ios_version(macro)
    if version == nil then
        raise(name .. ": no ios() in " .. macro)
    end
    -- line = head[:bound + 1 + hits[-1]].count('\n') + 1
    local line = S.count_newlines(string.sub(head, 1, bound + 1 + last)) + 1
    return version, line
end
