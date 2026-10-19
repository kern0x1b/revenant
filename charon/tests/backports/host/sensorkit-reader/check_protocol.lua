-- check_protocol.lua - the metadata the port emits for SRSensorReaderDelegate, counted.
--
--    xmake l ./check_protocol.lua <the output of protocol-count>
--
-- Reads one line of the form the probe prints and holds it to what the port is supposed to ship: the protocol found, TEN optional
-- method descriptions and NONE required. Exits 1 otherwise, naming what it saw.
--
-- WHY THIS EXISTS, because the first version of this harness's header shipped a protocol with zero methods and said nothing about
-- it. Measured, on this machine, by taking @protocol(SRSensorReaderDelegate) into a Protocol * and counting:
--
--     forward declaration only   ->  found,  0 optional
--     a declared body            ->  found, 10 optional,  0 required
--
-- A forward declaration emits the protocol object and leaves it empty, so an application asking
-- `[objc_getProtocol("SRSensorReaderDelegate") conformsToSelector:@selector(sensorReaderWillStartRecording:)]` got a NO for a method
-- its own class implements. The header now declares the ten members and the count is this check's job.
--
-- There is also a measurement here that had to be got wrong twice, and the harness should not repeat it: the first probe put
-- `(void)@protocol(X)` in a `static` function that main never called, the linker dead-stripped it, and the probe printed "protocol
-- ABSENT" for both shapes. protocol-count.m calls the function and prints the object it returns, so what it counts is in the image.

local WANT_OPTIONAL = 10
local WANT_REQUIRED = 0

-- The text of a file as Python's text mode reads it: "\r\n" and a lone "\r" are line ends, and become "\n".
local function read_text(path)
    local handle = assert(io.open(path, "rb"))
    local text = handle:read("a")
    handle:close()
    return (text:gsub("\r\n", "\n"):gsub("\r", "\n"))
end

-- Python's repr of a string, for the message that quotes what the probe printed. The probe prints ASCII, so only the quote, the
-- backslash and the line ends need care.
local function py_repr(text)
    local quote = "'"
    if text:find("'", 1, true) and not text:find('"', 1, true) then
        quote = '"'
    end
    local out = text:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
    if quote == "'" then
        out = out:gsub("'", "\\'")
    end
    return quote .. out .. quote
end

-- The first line of the form "protocol found, N optional, M required" or "protocol ABSENT, N optional, M required", with the
-- colon the probe may print after the word. Returns the state, the two counts, or nil when there is no such line.
local function find_count(text)
    local from = 1
    while true do
        local start = text:find("protocol", from, true)
        if not start then
            return nil
        end
        local rest = text:sub(start)
        local state, optional, required = rest:match("^protocol: (%a+), (%d+) optional, (%d+) required")
        if not state then
            state, optional, required = rest:match("^protocol (%a+), (%d+) optional, (%d+) required")
        end
        if state == "found" or state == "ABSENT" then
            return state, tonumber(optional), tonumber(required)
        end
        from = start + 1
    end
end

function main(...)
    local args = { ... }
    if #args ~= 1 then
        print("check_protocol.lua: pass the output of protocol-count")
        os.exit(1)
    end
    local text = read_text(args[1])
    local state, optional, required = find_count(text)
    if not state then
        local trimmed = text:match("^%s*(.-)%s*$"):sub(1, 120)
        print("FAIL the probe printed no line this check can read: " .. py_repr(trimmed))
        print("sensorkit-protocol: 0 failures  <- SEE FAIL")
        os.exit(1)
    end

    local present = state == "found"
    local failures = {}
    if not present then
        failures[#failures + 1] = "the port emits no __OBJC_PROTOCOL_$_SRSensorReaderDelegate at all"
    end
    if optional ~= WANT_OPTIONAL then
        failures[#failures + 1] = string.format("the protocol carries %d optional method descriptions and it must carry %d - an empty protocol answers NO to conformsToSelector: for a method a conformer implements",
            optional, WANT_OPTIONAL)
    end
    if required ~= WANT_REQUIRED then
        failures[#failures + 1] = string.format("the protocol carries %d required method descriptions and it must carry %d, because SRSensorReader.h:22 marks every one @optional",
            required, WANT_REQUIRED)
    end

    for _, failure in ipairs(failures) do
        print("FAIL " .. failure)
    end
    print(string.format("sensorkit-protocol: %s, %d optional, %d required, %d failures%s",
        present and "present" or "ABSENT", optional, required, #failures, #failures == 0 and "" or "  <- SEE FAIL"))
    if #failures > 0 then
        os.exit(1)
    end
end
