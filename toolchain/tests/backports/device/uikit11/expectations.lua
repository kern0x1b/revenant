local function json_string(text)
    local out = {'"'}
    local at, count = 1, #text
    while at <= count do
        local byte = text:byte(at)
        local code, width = nil, 1
        if byte < 0x80 then
            code = byte
        elseif byte >= 0xC2 and byte <= 0xDF then
            width = 2
        elseif byte >= 0xE0 and byte <= 0xEF then
            width = 3
        elseif byte >= 0xF0 and byte <= 0xF4 then
            width = 4
        end
        if code == nil and width > 1 then
            local valid = at + width - 1 <= count
            for index = 1, width - 1 do
                if valid then
                    local follow = text:byte(at + index)
                    valid = follow >= 0x80 and follow <= 0xBF
                end
            end
            if valid then
                code = byte & (0xFF >> (width + 1))
                for index = 1, width - 1 do
                    code = (code << 6) | (text:byte(at + index) & 0x3F)
                end
            else
                code, width = 0xFFFD, 1
            end
        elseif code == nil then
            code = 0xFFFD
        end
        if code < 0x80 then
            local escapes = {[0x22] = '\\"', [0x5C] = "\\\\", [0x0A] = "\\n", [0x0D] = "\\r", [0x09] = "\\t", [0x08] = "\\b", [0x0C] = "\\f"}
            if escapes[code] then
                table.insert(out, escapes[code])
            elseif code < 0x20 then
                table.insert(out, string.format("\\u%04x", code))
            else
                table.insert(out, string.char(code))
            end
        elseif code > 0xFFFF then
            local rest = code - 0x10000
            table.insert(out, string.format("\\u%04x\\u%04x", 0xD800 + (rest >> 10), 0xDC00 + (rest & 0x3FF)))
        else
            table.insert(out, string.format("\\u%04x", code))
        end
        at = at + width
    end
    table.insert(out, '"')
    return table.concat(out)
end

local function file_lines(text)
    local out, at = {}, 1
    while at <= #text do
        local stop = text:find("\n", at, true)
        if stop then
            table.insert(out, text:sub(at, stop - 1))
            at = stop + 1
        else
            table.insert(out, text:sub(at))
            break
        end
    end
    return out
end

function main(...)
    local sources = {}
    for _, argument in ipairs({...}) do
        local name, file = argument:match("^(.-)=(.*)$")
        if name == nil then
            raise("expectations.lua: pass test=path pairs")
        end
        table.insert(sources, {name, file})
    end
    local out = {"static const char *const charon_expected[][3] = {"}
    local count = 0
    for _, source in ipairs(sources) do
        local test, file = source[1], source[2]
        for _, line in ipairs(file_lines(io.readfile(file, {encoding = "binary"}))) do
            local name, value = line:match("^  (.-): (.*)$")
            if name == nil then
                name, value = line:match("^ok   (.-): (.*)$")
            end
            if name ~= nil and name ~= "" and not name:match("^%s*%d+ |") and not line:match("^%s*%d+ |") then
                local skipped = (test == "systemspacing" and name:find("baseline", 1, true) ~= nil)
                    or (test == "batchupdates" and name == "the order of everything")
                if not skipped then
                    table.insert(out, string.format("    {%s, %s, %s},", json_string(test), json_string(name), json_string(value)))
                    count = count + 1
                end
            end
        end
    end
    table.insert(out, "};")
    table.insert(out, string.format("static const unsigned charon_expected_count = %d;", count))
    print(table.concat(out, "\n"))
end
