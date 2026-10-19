-- swap_stop.lua SOURCE OUT - the object half's own plant: -stopRecording claims it stopped.
--
--    xmake l ./swap_stop.lua <the port's SRSensorReader.m> <where to write the copy>
--
-- Rewrites the one send inside -stopRecording so the reader tells its delegate recording stopped, which is one of the six methods
-- nothing in this port should ever send. Exits 1 when the line it anchors to is not there exactly once, so a plant that stops
-- applying is refused rather than quietly passing.
--
-- It is its own file rather than a heredoc in run.sh because the same rewrite is wanted twice - once for the source check's plant
-- and once for the object's - and one definition of a mutation is worth more than two spellings of it.

local NEEDLE_TAIL = "sensorReader:self stopRecordingFailedWithError:"
local REPLACEMENT = "[delegate sensorReaderDidStopRecording:self];"

-- The text of a file as Python's text mode reads it: "\r\n" and a lone "\r" are line ends, and become "\n".
local function read_text(path)
    local handle = assert(io.open(path, "rb"))
    local text = handle:read("a")
    handle:close()
    return (text:gsub("\r\n", "\n"):gsub("\r", "\n"))
end

-- The lines of a text, as Python's split("\n") gives them: a text that ends in a newline ends in an empty line.
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
        -- run.sh indents the send by eight spaces; match on the tail so the anchor survives a re-indent.
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
