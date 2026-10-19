function byte_at(text, i)
    if i < 1 then
        return nil
    end
    return string.byte(text, i)
end

function is_space(b)
    return b ~= nil and ((b >= 9 and b <= 13) or (b >= 28 and b <= 32))
end

function is_word(b)
    return b ~= nil and ((b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b == 95)
end

function is_digit(b)
    return b ~= nil and b >= 48 and b <= 57
end

function is_upper_or_underscore(b)
    return b ~= nil and ((b >= 65 and b <= 90) or b == 95)
end

function is_upper_digit_or_underscore(b)
    return is_upper_or_underscore(b) or is_digit(b)
end

function skip_space(text, i)
    while is_space(string.byte(text, i)) do
        i = i + 1
    end
    return i
end

function skip_word(text, i)
    while is_word(string.byte(text, i)) do
        i = i + 1
    end
    return i
end

function split_on(text, sep)
    local out = {}
    local start = 1
    while true do
        local stop = string.find(text, sep, start, true)
        if not stop then
            out[#out + 1] = string.sub(text, start)
            return out
        end
        out[#out + 1] = string.sub(text, start, stop - 1)
        start = stop + #sep
    end
end

function split_newlines(text)
    return split_on(text, "\n")
end

function strip(text)
    local first = 1
    while first <= #text and is_space(string.byte(text, first)) do
        first = first + 1
    end
    local last = #text
    while last >= first and is_space(string.byte(text, last)) do
        last = last - 1
    end
    return string.sub(text, first, last)
end

function collapse(text)
    local out = {}
    local i = 1
    local n = #text
    while i <= n do
        if is_space(string.byte(text, i)) then
            i = skip_space(text, i)
        else
            local j = i
            while j <= n and not is_space(string.byte(text, j)) do
                j = j + 1
            end
            out[#out + 1] = string.sub(text, i, j - 1)
            i = j
        end
    end
    return table.concat(out, " ")
end

function starts_with(text, prefix)
    return string.sub(text, 1, #prefix) == prefix
end

function ends_with(text, suffix)
    return suffix == "" or string.sub(text, -#suffix) == suffix
end

function contains(text, needle)
    return string.find(text, needle, 1, true) ~= nil
end

function is_word_string(text)
    if text == "" then
        return false
    end
    return skip_word(text, 1) == #text + 1
end

function last_piece(text, sep)
    local start = 1
    local last = nil
    while true do
        local stop = string.find(text, sep, start, true)
        if not stop then
            break
        end
        last = stop
        start = stop + #sep
    end
    if last == nil then
        return text
    end
    return string.sub(text, last + #sep)
end

function normpath(path)
    if string.sub(path, 1, 1) ~= "/" then
        path = (os.getenv("PWD") or ".") .. "/" .. path
    end
    local parts = {}
    for part in string.gmatch(path, "[^/]+") do
        if part == ".." then
            parts[#parts] = nil
        elseif part ~= "." then
            parts[#parts + 1] = part
        end
    end
    return "/" .. table.concat(parts, "/")
end

function basename(path)
    return string.match(path, "([^/]*)$")
end

function count_newlines(text)
    local n = 0
    local start = 1
    while true do
        local stop = string.find(text, "\n", start, true)
        if not stop then
            return n
        end
        n = n + 1
        start = stop + 1
    end
end
