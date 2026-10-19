local NEEDLE_TAIL = "sensorReader:self stopRecordingFailedWithError:"
local REPLACEMENT = "[delegate sensorReaderDidStopRecording:self];"

local function read_text(path)
    local handle = assert(io.open(path, "rb"))
    local text = handle:read("a")
    handle:close()
    return (text:gsub("\r\n", "\n"):gsub("\r", "\n"))
end

local function split_lines(text)
    local out, start = {}, 1
    while true do
        local newline = text:find("\n", start, true)
        if not newline then
            out[#out + 1] = text:sub(start)
            return out
        end
        out[#out + 1] = text:sub(start, newline - 1)
        start = newline + 1
    end
end

function main(...)
    local args = { ... }
    if #args ~= 2 then
        io.stderr:write("swap_stop.lua: pass the source and where to write the copy\n")
        os.exit(1)
    end
    local src, out = args[1], args[2]
    local lines = split_lines(read_text(src))
    local hit = 0
    for index, line in ipairs(lines) do
        if line:find(NEEDLE_TAIL, 1, true) and line:find("[delegate", 1, true) then
            lines[index] = "        " .. REPLACEMENT
            hit = hit + 1
        end
    end
    if hit ~= 1 then
        io.stderr:write(string.format("swap_stop.lua: the send to rewrite was found %d times, and it must be exactly 1\n", hit))
        os.exit(1)
    end
    local handle = assert(io.open(out, "wb"))
    handle:write(table.concat(lines, "\n"))
    handle:close()
end
