local function byte_at(hex, offset)
    local pair = hex:sub(offset + 1, offset + 2)
    local value = tonumber(pair, 16)
    if not value or #pair ~= 2 then
        raise(string.format("not two hex digits at byte %d: %s", offset // 2, pair), 0)
    end
    return value
end

function element(hex, k)
    local bytes = {}
    for i = 0, 3 do
        bytes[i + 1] = byte_at(hex, 2 * k + 2 * i)
    end
    return bytes
end

function word(hex, k)
    local bytes = element(hex, k)
    return bytes[1] + bytes[2] * 256 + bytes[3] * 65536 + bytes[4] * 16777216
end

function float(hex, k)
    local bytes = element(hex, k)
    return (string.unpack("<f", string.char(bytes[1], bytes[2], bytes[3], bytes[4])))
end

function ordered(bits)
    if bits < 0x80000000 then
        return bits
    end
    return 0x80000000 - (bits - 0x80000000) - 1 + 0x80000000
end

function distance(shex, phex, slen)
    local worst = 0
    for k = 0, slen - 1, 4 do
        local d = math.abs(ordered(word(shex, k)) - ordered(word(phex, k)))
        if d > worst then
            worst = d
        end
    end
    return worst
end

function lines_of(path)
    if not os.isfile(path) then
        raise(string.format("no such file: %s", path), 0)
    end
    return io.lines(path)
end

function cases(path)
    local out = {}
    for line in lines_of(path) do
        if line:sub(1, 5) == "case " then
            local fields = {}
            for field in line:gmatch("%S+") do
                table.insert(fields, field)
            end
            if #fields >= 4 then
                local length = fields[#fields - 1]
                if not length:match("^[+-]?%d+$") then
                    raise(string.format("the length of a case is not an integer: %s", length), 0)
                end
                local name = table.concat(fields, " ", 2, #fields - 2)
                table.insert(out, {name = name, length = math.tointeger(tonumber(length)), hex = fields[#fields]})
            end
        end
    end
    return out
end
