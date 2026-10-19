-- Requires the port's four time functions to satisfy the relations the header states, and requires the host's own to satisfy
-- them too - the host is the only oracle SensorKit has, and the port's numbers are its own anchor, so what can be compared is
-- the relation and not the value.
--
-- Usage: xmake l ./compare.lua <system.json> <port.json>

import("core.base.json")

local function load(file)
    local handle = assert(io.open(file, "rb"))
    local records = json.decode(handle:read("a"))
    handle:close()
    return records
end

-- Python's repr of the value a record holds: None for a key it does not have, and 'text' for a string.
local function repr(value)
    if value == nil then
        return "None"
    end
    return "'" .. tostring(value) .. "'"
end

local function count(records)
    local n = 0
    for _ in pairs(records) do
        n = n + 1
    end
    return n
end

function main(systemFile, portFile)
    if not systemFile or not portFile then
        raise("compare.lua: pass the host's records and the port's")
    end
    local system = load(systemFile)
    local port = load(portFile)
    local sides = { { "the host's", "system", system }, { "the port's", "port", port } }
    local bad = {}
    for _, side in ipairs(sides) do
        local who, prefix, records = side[1], side[2], side[3]
        for _, relation in ipairs({ "neverBackwards", "thirdReadingAdvances", "notNull", "agreesWithCFAbsoluteTime",
                "roundTripWithinAMicrosecond", "fromContinuousNonZero" }) do
            local key = prefix .. "." .. relation
            if records[key] ~= "1" then
                bad[#bad + 1] = string.format("%s does not satisfy %s (%s)", who, relation, repr(records[key]))
            end
        end
    end
    -- The NSDate category's three relations, asked of BOTH builds: the host is the only oracle SensorKit has, and the
    -- port's numbers are its own anchor, so what can be compared is the relation. IT WAS WRITTEN ONCE WITH AN EXPECTED
    -- DIFFERENCE - that the host's own build would not have the class method - and the run said otherwise, because the
    -- probe behind that belief used class_getInstanceMethod, which finds an INSTANCE method: the class method lives on the
    -- metaclass, so the probe answered "no" for a method the host has. The host answers yes to all three, and both sides
    -- are held to the same three relations.
    for _, side in ipairs(sides) do
        local who, prefix, records = side[1], side[2], side[3]
        for _, relation in ipairs({ "categoryInitPresent", "categoryGetterPresent", "categoryClassMethodPresent",
                "categoryRoundTrip", "categoryAgreesWithClock", "categoryNeverBackwards" }) do
            local key = prefix .. "." .. relation
            if records[key] ~= "1" then
                bad[#bad + 1] = string.format("%s does not satisfy %s (%s)", who, relation, repr(records[key]))
            end
        end
    end
    print(string.format("compared %d records: the host's relations and the port's", count(port)))
    if #bad > 0 then
        for _, line in ipairs(bad) do
            print("DIFFERS " .. line)
        end
        os.exit(1)
    end
end
