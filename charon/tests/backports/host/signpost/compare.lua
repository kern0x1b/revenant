-- compare.lua HOSTFILE - the port's os_signpost claims, held to the host's records.
--
-- Requires the port's os_signpost answers to be the host's, and the port's own store to have kept an interval an application
-- marked. The ids are the pair that would have found the high-bit convention this series carried and the review measured
-- against the host: the host answers 0x1 with the bit clear and returns a pointer unmasked.
--
-- Usage: xmake l ./compare.lua <host.json>

import("core.base.json")

-- What the port's code comments, facts and registry entries say the host does, and what the host does. A change of host would
-- make one of these fail, which is the point: the records are claims, and this is what holds them to it.
local CLAIMS = {
    { "signpost.enabled", "1", "the port answers true, and says why: the header's own emit macro compiles the whole call away when it is false, so a family that recorded nothing would make every metric empty by construction" },
    { "id.isNotNull", "1", "the port's generate never returns OS_SIGNPOST_ID_NULL" },
    { "id.distinct", "1", "the port's generate counts up, so two calls differ" },
    { "id.pointerIsNotReserved", "1", "the port's make_with_pointer never returns one of the two reserved values" },
}

-- Python's repr of a value the records hold: None for a key it does not have, and 'text' for a string.
local function repr(value)
    if value == nil then
        return "None"
    end
    return "'" .. tostring(value) .. "'"
end

-- The records as an id: a hexadecimal number of at most 64 bits, with the 0x prefix Python's int(text, 16) allows. A wider
-- number is refused rather than read, since no id the host can return is wider than 64 bits.
local function hex_value(text)
    local digits = text:match("^%s*(.-)%s*$"):gsub("^0[xX]", "")
    if not digits:find("^%x+$") then
        raise("signpost: the host's record " .. text .. " is not a hexadecimal number")
    end
    if #digits > 16 then
        raise("signpost: the host's record " .. text .. " is wider than 64 bits")
    end
    return tonumber(digits, 16)
end

function main(hostFile)
    if not hostFile then
        raise("compare.lua: pass the host's records")
    end
    local handle = assert(io.open(hostFile, "rb"))
    local system = json.decode(handle:read("a"))
    handle:close()
    local bad = {}
    for _, claim in ipairs(CLAIMS) do
        local name, wanted, why = claim[1], claim[2], claim[3]
        if system[name] ~= wanted then
            bad[#bad + 1] = string.format("%s: the port's records say %s and the host answers %s - %s",
                name, repr(wanted), repr(system[name]), why)
        end
    end
    -- The high bit: the port's records say the host leaves it clear, and that is what the review measured twice. This is the
    -- check that would have found the convention the port used to carry.
    for _, name in ipairs({ "id.first", "id.second" }) do
        local value = hex_value(system[name] or "0")
        if value & (1 << 63) ~= 0 then
            bad[#bad + 1] = string.format("%s is %s: the high bit is set, and the port's records say the host leaves it clear",
                name, system[name])
        end
        if value == 0 or value == -1 then
            bad[#bad + 1] = name .. " is a reserved value"
        end
    end
    if system["id.first"] ~= "1" then
        bad[#bad + 1] = string.format("the host's first generated id is %s; the port's records say 1", repr(system["id.first"]))
    end
    if #bad > 0 then
        for _, line in ipairs(bad) do
            print("DIFFERS " .. line)
        end
        os.exit(1)
    end
    local count = 0
    for _ in pairs(system) do
        count = count + 1
    end
    print(string.format("compared %d host records against the port's claims about them", count))
end
