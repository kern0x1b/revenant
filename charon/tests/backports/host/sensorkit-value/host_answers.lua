-- host_answers.lua HOST.OUT - the port's answers must be the host's, over what the host actually said.
--
--    xmake l ./host_answers.lua <the output of host-answers.m>
--
-- Reads the ten COUNT lines, the two PROPERTY lines and the INIT line, and holds the port to them:
--
--   - both counts must be 0 for every one of the ten sentiment categories. 0 and not nil: the host answers an integer, and a
--     count of nothing typed in a category is zero.
--   - both speech properties must be nil for a metrics object with no session, which is what the header's own nullable means
--     with nothing behind it.
--   - -[SRSensorReader init] must raise. The port produces that raise, in SRSensorReader.m, and this line is the measurement it
--     is held to; the whole of the eighteen classes whose headers close the pair is in tests/backports/host/unavailable-init,
--     which is where that one is now held twice - to the source and to the compiled object - so a harness that quoted the
--     header's NS_UNAVAILABLE without measuring what the framework does about it would be quoting rather than checking.
--
-- Prints the three verdicts and a summary; exits 1 if the host answered something else, because a golden file that no longer
-- matches what the host says is a harness that has stopped being evidence.
--
-- The HOST COUNTS verdict is yes only when every count is 0. The Python it was ported from read the failure texts for the word
-- "count" instead, so a category that answered 3 still said yes; the verdict now reads the values it is about.

-- Names are sorted by their bytes, as Python sorts strings; the string comparison of Lua follows the locale's collation.
local function byte_less(a, b)
    for i = 1, math.min(#a, #b) do
        local x, y = a:byte(i), b:byte(i)
        if x ~= y then
            return x < y
        end
    end
    return #a < #b
end

-- The fields of a line, split at every tab, with its line end taken off first: handle:lines() keeps the "\n" on each line.
local function fields(line)
    line = line:gsub("\n$", ""):gsub("\r$", "")
    local out, start = {}, 1
    while true do
        local tab = line:find("\t", start, true)
        if not tab then
            out[#out + 1] = line:sub(start)
            return out
        end
        out[#out + 1] = line:sub(start, tab - 1)
        start = tab + 1
    end
end

-- Python's spelling of a value that may be missing: None, which %s would otherwise fail on.
local function py(value)
    return value == nil and "None" or value
end

function main(...)
    local args = { ... }
    if #args ~= 1 then
        print("host_answers.lua: pass the output of host-answers.m")
        os.exit(1)
    end
    local counts, categories, properties, init = {}, {}, {}, nil
    local handle = assert(io.open(args[1], "rb"))
    for line in handle:lines() do
        local parts = fields(line)
        if parts[1] == "COUNT" and #parts == 4 then
            if counts[parts[2]] == nil then
                categories[#categories + 1] = parts[2]
            end
            counts[parts[2]] = { parts[3], parts[4] }
        elseif parts[1] == "PROPERTY" and #parts == 3 then
            properties[parts[2]] = parts[3]
        elseif parts[1] == "INIT" and #parts == 2 then
            init = parts[2]
        end
    end
    handle:close()
    table.sort(categories, byte_less)

    local failures = {}
    local counts_zero = true
    if #categories ~= 10 then
        failures[#failures + 1] = string.format("the host answered %d sentiment categories, and this harness expects 10", #categories)
    end
    for _, category in ipairs(categories) do
        local word, emoji = counts[category][1], counts[category][2]
        if word ~= "word=0" or emoji ~= "emoji=0" then
            counts_zero = false
            failures[#failures + 1] = string.format("category %s: the host answers %s and %s, and it must answer word=0 emoji=0",
                category, word, emoji)
        end
    end
    for _, name in ipairs({ "speechRecognition", "soundClassification" }) do
        if properties[name] ~= "nil" then
            failures[#failures + 1] = string.format("%s: the host answers [%s], and it must answer nil", name, py(properties[name]))
        end
    end
    if init == nil then
        failures[#failures + 1] = "the host said nothing about -[SRSensorReader init]"
    elseif init:sub(1, 6) ~= "RAISES" then
        failures[#failures + 1] = string.format("-[SRSensorReader init]: the host answers [%s], and it must raise", init)
    end

    local properties_nil = properties["speechRecognition"] == "nil" and properties["soundClassification"] == "nil"
    print(string.format("HOST COUNTS   %d categories, every word and emoji count 0: %s", #categories,
        (#categories == 10 and counts_zero) and "yes" or "NO"))
    print(string.format("HOST PROPERTY %s and %s both nil: %s", "speechRecognition", "soundClassification",
        properties_nil and "yes" or "NO"))
    print(string.format("HOST INIT     %s", (init and init ~= "") and init or "(the host said nothing)"))
    for _, failure in ipairs(failures) do
        print("FAIL " .. failure)
    end
    print(string.format("sensorkit-value-host: %d failures%s", #failures, #failures == 0 and "" or "  <- SEE FAIL"))
    if #failures > 0 then
        os.exit(1)
    end
end
