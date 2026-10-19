local SAMPLES = {
    { name = "kVTAlphaChannelMode_PremultipliedAlpha", wanted = "13.0" },
    { name = "kVTCompressionPropertyKey_PreserveDynamicHDRMetadata", wanted = "14.0" },
}
local DECOY = "kVTCharonDecoyNameThatIsNotInAnyHeader"
local CONSTANT_TYPE = "const CFStringRef"
local USR_PREFIX = "c:@"

local function fields(line)
    local out, start = {}, 1
    while true do
        local tab = string.find(line, "\t", start, true)
        if tab == nil then
            out[#out + 1] = string.sub(line, start)
            return out
        end
        out[#out + 1] = string.sub(line, start, tab - 1)
        start = tab + 1
    end
end

local function ios_release(availability)
    for entry in string.gmatch(availability, "[^,]+") do
        local platform, rest = string.match(entry, "^(%w+)=(.*)$")
        if platform == "ios" then
            local introduced = string.match(rest, "^([^/]*)")
            if introduced ~= nil and introduced ~= "" and introduced ~= "-" then
                return introduced
            end
            return nil
        end
    end
    return nil
end

local function read_constants(path)
    local handle = assert(io.open(path, "rb"), "availability.lua: cannot open " .. path)
    local out, stated = {}, 0
    for line in handle:lines() do
        line = string.gsub(line, "\n$", "")
        if string.sub(line, 1, 1) ~= "#" and line ~= "" then
            local row = fields(line)
            if row[1] == "var" and row[6] == CONSTANT_TYPE and string.sub(row[2], 1, #USR_PREFIX) == USR_PREFIX then
                local name = string.sub(row[2], #USR_PREFIX + 1)
                local release = ios_release(row[9] or "")
                out[name] = release or false
                if release ~= nil then
                    stated = stated + 1
                end
            end
        end
    end
    handle:close()
    return out, stated
end

function main(...)
    local path = (...) or (os.scriptdir() .. "/../../../../packages/a/apple-backports/spec/VideoToolbox/declarations.tsv")
    local constants, stated = read_constants(path)
    local bad = {}
    for _, sample in ipairs(SAMPLES) do
        local got = constants[sample.name]
        if got == nil then
            bad[#bad + 1] = sample.name .. ": the table does not declare it, so the self-test has nothing to read"
        elseif got ~= sample.wanted then
            bad[#bad + 1] = string.format("%s: read %s, the table states %s", sample.name, tostring(got), sample.wanted)
        else
            print(string.format("  %-56s %s", sample.name, got))
        end
    end
    if constants[DECOY] ~= nil then
        bad[#bad + 1] = DECOY .. " read " .. tostring(constants[DECOY]) .. "; a reader that invents a release is the failure this is for"
    else
        print("  decoy: no release read for a name no SDK declares")
    end
    print(string.format("  %d constants declared; %d state an iOS release", (function()
        local total = 0
        for _ in pairs(constants) do
            total = total + 1
        end
        return total
    end)(), stated))
    for _, line in ipairs(bad) do
        print("FAIL " .. line)
    end
    if #bad > 0 then
        os.exit(1)
    end
    print("constant availability: both samples read from the table, and the decoy invents nothing")
end
