local json = import("core.base.json")
local modules = path.join(os.scriptdir(), "..", "..", "..", "..", "modules")
local byteorder = import("byteorder", {rootdir = modules, anonymous = true})
local runtime = import("gyb.runtime", {rootdir = modules, anonymous = true})

local PAIRED = {
    ["sheet.trustHeld"] = "trust.exists", ["sheet.title"] = false, ["sheet.message"] = false, ["sheet.helpURL"] = false,
    ["sheet.trustIsOurs"] = false, ["sheet.titleIsCopy"] = false, ["sheet.trustOfUnavailableInit"] = false
}

local SET_AND_READ = {
    {"sheet.title", "Revenant title"}, {"sheet.message", "Revenant message"},
    {"sheet.helpURL", "https://example.invalid/help"}, {"sheet.trustIsOurs", "1"},
    {"sheet.trustHeld", "1"}, {"sheet.titleIsCopy", "1"},
    {"sheet.trustOfUnavailableInit", "1"}
}

local WORDING = {["trusted"] = "Trusted", ["not-trusted-yet"] = "Not trusted yet", ["not-trusted"] = "Not trusted"}
local VERDICTS = {["Trusted"] = true, ["Not trusted yet"] = true, ["Not trusted"] = true}

local function repr(value)
    if value == nil then
        return "None"
    end
    return runtime.to_repr(value)
end

local function load(file)
    return json.decode(io.readfile(file, {encoding = "binary"}))
end

local function list_repr(list)
    local shown = {}
    for _, item in ipairs(list) do
        table.insert(shown, repr(item))
    end
    return "[" .. table.concat(shown, ", ") .. "]"
end

function main(system_file, port_file)
    local system, port = load(system_file), load(port_file)
    local bad = {}
    local function fail(...)
        table.insert(bad, string.format(...))
    end
    local shared = 0
    for _, name in ipairs(byteorder.keys(system)) do
        shared = shared + 1
        local value = system[name]
        if port[name] == nil then
            fail("the port recorded no %s, the host answered %s", name, repr(value))
        elseif port[name] ~= value then
            fail("%s: host %s, port %s", name, repr(value), repr(port[name]))
        end
    end
    for _, name in ipairs(byteorder.keys(PAIRED)) do
        local host_name = PAIRED[name]
        if port[name] == nil then
            fail("the port recorded no %s", name)
        elseif host_name and system[host_name] ~= nil and system[host_name] ~= port[name] then
            fail("%s: host %s, port %s", name, repr(system[host_name]), repr(port[name]))
        end
    end
    for _, name in ipairs(byteorder.keys(port)) do
        if system[name] == nil and PAIRED[name] == nil and not name:startswith("sheet.line.")
                and name ~= "sheet.lineCount" and name ~= "sheet.linesForNullTrust" then
            fail("the port recorded %s, which nothing on the host answers", name)
        end
    end
    for _, pair in ipairs(SET_AND_READ) do
        local name, wanted = pair[1], pair[2]
        if port[name] ~= wanted then
            fail("%s: the case set %s and read back %s", name, repr(wanted), repr(port[name]))
        end
    end

    local chain = tonumber(system["trust.certificateCount"] or "1")
    local verdict = system["trust.verdict"]
    local lines = {}
    for index = 0, tonumber(port["sheet.lineCount"] or "0") - 1 do
        table.insert(lines, port["sheet.line." .. index])
    end
    if #lines == 0 then
        fail("the sheet built no lines for a trust the host's Security answered with %d certificate(s) and %s", chain, tostring(verdict))
    elseif lines[1] ~= system["trust.subjectSummary"] then
        fail("the sheet's first line is %s, the trust's own subject summary is %s", repr(lines[1]), repr(system["trust.subjectSummary"]))
    else
        local wanted = WORDING[verdict or ""]
        local said = {}
        for _, line in ipairs(lines) do
            if VERDICTS[line] then
                table.insert(said, line)
            end
        end
        if wanted == nil then
            if #said > 0 then
                fail("SecTrustEvaluate answered %s and the sheet still said %s", repr(verdict), list_repr(said))
            end
        elseif #said ~= 1 or said[1] ~= wanted then
            fail("SecTrustEvaluate answered %s, which the sheet words as %s, and the sheet said %s", repr(verdict), repr(wanted), list_repr(said))
        end
    end
    if port["sheet.linesForNullTrust"] ~= "0" then
        fail("a NULL trust gave the sheet %s lines, and the header's unavailable -init holds exactly that", tostring(port["sheet.linesForNullTrust"]))
    end

    if #bad > 0 then
        for _, line in ipairs(bad) do
            print("DIFFERS " .. line)
        end
        os.exit(1)
    end
    print(string.format("compared %d shared records and %d sheet lines", shared, #lines))
end
