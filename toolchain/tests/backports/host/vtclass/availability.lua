local S = import("pystr", {rootdir = os.scriptdir()})

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

function find_interface(text, name)
    local at = interface_at(text, name)
    if at == nil then
        raise("no @interface " .. name)
    end
    return at
end

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

function availability_of(text, name)
    local pos = find_interface(text, name)
    local head = string.sub(text, 1, pos)
    local bound = math.max(last_index(head, "@end"), last_index(head, "@interface"))
    local window = string.sub(head, bound + 2)
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
    local macro = _balanced(window, last + #"API_AVAILABLE")
    local version = ios_version(macro)
    if version == nil then
        raise(name .. ": no ios() in " .. macro)
    end
    local line = S.count_newlines(string.sub(head, 1, bound + 1 + last)) + 1
    return version, line
end
