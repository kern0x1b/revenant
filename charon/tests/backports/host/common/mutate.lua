local common = import("compare", {rootdir = os.scriptdir(), anonymous = true})

local TAIL = 200
local SLACK = 4
local USAGE = "usage: MUTATE=<file> MUTATE_OLD=<text> MUTATE_NEW=<text> MUTATE_NTH=<n> mutate.lua"

local WHITESPACE = "[ \t\n\r\11\12\28-\31]"
local BREAKS = {"\r\n", "\n", "\r", "\11", "\12", "\28", "\29", "\30", "\194\133", "\226\128\168", "\226\128\169"}

local function strip(text)
    return (text:gsub("^" .. WHITESPACE .. "+", ""):gsub(WHITESPACE .. "+$", ""))
end

local function characters(text)
    local list = {}
    for _, code in utf8.codes(text) do
        table.insert(list, utf8.char(code))
    end
    return list
end

local function last_characters(text, count)
    local list = characters(text)
    return table.concat(list, "", math.max(1, #list - count + 1))
end

local function line_count(text)
    local count, at = 0, 1
    while at <= #text do
        local nearest, width
        for _, separator in ipairs(BREAKS) do
            local found = text:find(separator, at, true)
            if found and (not nearest or found < nearest or (found == nearest and #separator > width)) then
                nearest, width = found, #separator
            end
        end
        count = count + 1
        if not nearest then
            break
        end
        at = nearest + width
    end
    return count
end

local function occurrences(text, old)
    local starts, at = {}, 1
    while true do
        local first, last = text:find(old, at, true)
        if not first then
            return starts
        end
        table.insert(starts, first)
        at = last + 1
    end
end

function mutated(text, old, new, nth)
    local starts = occurrences(text, old)
    if nth < 1 or #starts < nth then
        return nil, string.format("the mutant's line is in the file %d times and the mutant wants the %d of them: %s", #starts, nth, common.repr(old))
    end
    local tail = text:sub(starts[nth] + #old)
    local result = text:sub(1, starts[nth] - 1) .. new .. tail
    local kept = last_characters(strip(tail), TAIL)
    if strip(text):sub(-#kept) ~= kept and not text:find(kept, 1, true) then
        return nil, "the mutation dropped the end of the file, so it is refused rather than written"
    end
    if line_count(result) < line_count(text) - math.abs(line_count(new) - line_count(old)) - SLACK then
        return nil, string.format("the mutation made the file %d lines shorter than the change accounts for, so it is refused",
                                  line_count(text) - line_count(result))
    end
    return result
end

function mutate(file, old, new, nth)
    local text = io.readfile(file, {encoding = "binary"}):gsub("\r\n", "\n"):gsub("\r", "\n")
    local result, refusal = mutated(text, old, new, nth)
    if not result then
        return false, refusal
    end
    io.writefile(file, result, {encoding = "binary"})
    return true
end

function main()
    local file = os.getenv("MUTATE") or ""
    local old = os.getenv("MUTATE_OLD") or ""
    local new = os.getenv("MUTATE_NEW") or ""
    local nth = os.getenv("MUTATE_NTH") or ""
    if file == "" or old == "" or nth == "" then
        io.stderr:write(USAGE .. "\n")
        os.exit(2)
    end
    local number = tonumber(nth)
    if not number or math.type(number) ~= "integer" then
        io.stderr:write(string.format("MUTATE_NTH is %s, which is not a whole number\n", common.repr(nth)))
        os.exit(1)
    end
    local ok, refusal = mutate(file, old, new, number)
    if not ok then
        io.stderr:write(refusal .. "\n")
        os.exit(1)
    end
end
