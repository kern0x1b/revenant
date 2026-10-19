import("core.base.json")

local CLAIMS = {
    { "signpost.enabled", "1", "the port answers true, and says why: the header's own emit macro compiles the whole call away when it is false, so a family that recorded nothing would make every metric empty by construction" },
    { "id.isNotNull", "1", "the port's generate never returns OS_SIGNPOST_ID_NULL" },
    { "id.distinct", "1", "the port's generate counts up, so two calls differ" },
    { "id.pointerIsNotReserved", "1", "the port's make_with_pointer never returns one of the two reserved values" },
}

local function repr(value)
    if value == nil then
        return "None"
    end
    return "'" .. tostring(value) .. "'"
end

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
