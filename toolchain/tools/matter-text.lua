function digest(text)
    local h = 0
    for k = 1, #text, 4096 do
        for _, b in ipairs({text:byte(k, math.min(k + 4095, #text))}) do
            h = (h * 31 + b) % 4294967296
        end
    end
    return string.format("%08x", h)
end

function cells_of(line)
    local out = {}
    for cell in (line .. "\t"):gmatch("([^\t]*)\t") do
        out[#out + 1] = cell
    end
    return out
end
