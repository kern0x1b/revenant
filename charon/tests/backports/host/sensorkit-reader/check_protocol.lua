local WANT_OPTIONAL = 10
local WANT_REQUIRED = 0

local function read_text(path)
    local handle = assert(io.open(path, "rb"))
    local text = handle:read("a")
    handle:close()
    return (text:gsub("\r\n", "\n"):gsub("\r", "\n"))
end

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
