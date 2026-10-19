local HEADER = "^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d%.%d+[+-]%d%d%d%d %S+%[%d+:%d+%] %[c(%d+)%] "

local function read_bytes(file)
    local handle = assert(io.open(file, "rb"))
    local text = handle:read("a")
    handle:close()
    return text
end

local function system_cases(text)
    local starts = { 1 }
    for position in text:gmatch("()\n") do
        starts[#starts + 1] = position + 1
    end
    local matches = {}
    local pointer = 1
    for _, start in ipairs(starts) do
        if start >= pointer then
            local s, e, digits = text:find(HEADER, start)
            if s then
                matches[#matches + 1] = { first = s, last = e, index = tonumber(digits) }
                pointer = e + 1
            end
        end
    end
    local cases = {}
    for n, match in ipairs(matches) do
        local stop = matches[n + 1] and (matches[n + 1].first - 1) or #text
        cases[match.index] = text:sub(match.last + 1, stop):gsub("\n+$", "")
    end
    return cases
end

local function ours_cases(bytes)
    local cases = {}
    local start = 1
    while start <= #bytes do
        local stop = bytes:find("\0", start, true) or (#bytes + 1)
        local record = bytes:sub(start, stop - 1)
        if record ~= "" then
            local separator = record:find("\31", 1, true)
            local index = tonumber(separator and record:sub(1, separator - 1) or record)
            if not index then
                raise("compare.lua: a record of the backport's output has no case index: " .. record)
            end
            cases[index] = separator and record:sub(separator + 1) or ""
        end
        start = stop + 1
    end
    return cases
end

local function characters(bytes)
    local out = {}
    local i = 1
    while i <= #bytes do
        local b = bytes:byte(i)
        local length = 1
        if b >= 0xC2 and b <= 0xDF then
            length = 2
        elseif b >= 0xE0 and b <= 0xEF then
            length = 3
        elseif b >= 0xF0 and b <= 0xF4 then
            length = 4
        end
        if length > 1 and i + length - 1 <= #bytes and utf8.len(bytes:sub(i, i + length - 1)) == 1 then
            out[#out + 1] = bytes:sub(i, i + length - 1)
            i = i + length
        else
            out[#out + 1] = bytes:sub(i, i)
            i = i + 1
        end
    end
    return out
end

local function repr(text)
    if text == nil then
        return "None"
    end
    local quote = (text:find("'", 1, true) and not text:find('"', 1, true)) and '"' or "'"
    local out = { quote }
    for _, c in ipairs(characters(text)) do
        if c == quote or c == "\\" then
            out[#out + 1] = "\\" .. c
        elseif c == "\t" then
            out[#out + 1] = "\\t"
        elseif c == "\n" then
            out[#out + 1] = "\\n"
        elseif c == "\r" then
            out[#out + 1] = "\\r"
        elseif #c == 1 and (c:byte() < 32 or c:byte() == 127) then
            out[#out + 1] = string.format("\\x%02x", c:byte())
        elseif #c == 1 and c:byte() >= 128 then
            out[#out + 1] = string.format("\\udc%02x", c:byte())
        else
            out[#out + 1] = c
        end
    end
    out[#out + 1] = quote
    return table.concat(out)
end

local function first_characters(text, n)
    local chars = characters(text)
    local out = {}
    for i = 1, math.min(n, #chars) do
        out[i] = chars[i]
    end
    return table.concat(out)
end

local function escaped(text)
    local out = {}
    for i = 1, #text do
        local b = text:byte(i)
        local c = string.char(b)
        if b >= 32 and b < 127 and c ~= '"' and c ~= "\\" then
            out[i] = c
        else
            out[i] = string.format("\\%03o", b)
        end
    end
    return table.concat(out)
end

function main(systemFile, oursFile, expectations, limit)
    if not systemFile or not oursFile then
        raise("compare.lua: pass the system's log and the backport's output")
    end
    local system = system_cases((read_bytes(systemFile):gsub("\r\n", "\n"):gsub("\r", "\n")))
    local ours = ours_cases(read_bytes(oursFile))
    local indexes = {}
    for index in pairs(ours) do
        indexes[#indexes + 1] = index
    end
    table.sort(indexes)
    local failures = 0
    for _, index in ipairs(indexes) do
        local a, b = system[index], ours[index]
        if a == b then
            print(string.format("ok   case %d: %s", index, first_characters(b:gsub("\n", "\\n"), 110)))
        else
            failures = failures + 1
            print(string.format("FAIL case %d: the system answers %s, the backport answers %s", index, repr(a), repr(b)))
        end
    end
    local count = #indexes
    print(string.format("%d checks, %d failures", count, failures))
    if expectations and failures == 0 then
        limit = tonumber(limit)
        local system_indexes = {}
        for index in pairs(system) do
            system_indexes[#system_indexes + 1] = index
        end
        table.sort(system_indexes)
        local rows = {}
        for _, index in ipairs(system_indexes) do
            if index <= limit then
                rows[#rows + 1] = string.format('    {%d, "%s"},', index, escaped(system[index]))
            end
        end
        local handle = assert(io.open(expectations, "wb"))
        handle:write("static const struct {\n    int index;\n    const char *text;\n} revenant_oslog_expected[] = {\n"
            .. table.concat(rows, "\n") .. "\n};\n")
        handle:close()
    end
    if failures > 0 then
        os.exit(1)
    end
end
