local function byte_less(a, b)
    for i = 1, math.min(#a, #b) do
        local x, y = a:byte(i), b:byte(i)
        if x ~= y then
            return x < y
        end
    end
    return #a < #b
end

local TEN = {
    "sensorReader:fetchingRequest:didFetchResult:",
    "sensorReader:didCompleteFetch:",
    "sensorReader:fetchingRequest:failedWithError:",
    "sensorReader:didChangeAuthorizationStatus:",
    "sensorReaderWillStartRecording:",
    "sensorReader:startRecordingFailedWithError:",
    "sensorReaderDidStopRecording:",
    "sensorReader:stopRecordingFailedWithError:",
    "sensorReader:didFetchDevices:",
    "sensorReader:fetchDevicesDidFailWithError:",
}
local EXPECTED = {
    "sensorReader:startRecordingFailedWithError:",
    "sensorReader:stopRecordingFailedWithError:",
    "sensorReader:fetchingRequest:failedWithError:",
    "sensorReader:fetchDevicesDidFailWithError:",
}

local function methnames(obj)
    local out = os.iorunv("otool", { "-v", "-s", "__TEXT", "__objc_methname", obj })
    local found = {}
    for line in out:gmatch("[^\n]+") do
        local address, name = line:match("^([0-9a-f]+)  (%S+)$")
        if address and #address >= 6 then
            found[name] = true
        end
    end
    return found
end

local function contains(list, value)
    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end

function main(...)
    local args = { ... }
    if #args ~= 1 then
        print("objc_selectors.lua: pass the path to a compiled object")
        os.exit(1)
    end
    local seen = methnames(args[1])
    local held = {}
    for _, selector in ipairs(TEN) do
        if seen[selector] then
            held[#held + 1] = selector
        end
    end
    table.sort(held, byte_less)

    for _, selector in ipairs(TEN) do
        print(string.format("%-8s %s", contains(held, selector) and "IN" or "OUT", selector))
    end

    local failures = {}
    local missing = {}
    for _, selector in ipairs(EXPECTED) do
        if not contains(held, selector) then
            missing[#missing + 1] = selector
        end
    end
    if #missing > 0 then
        failures[#failures + 1] = "the object does not carry " .. table.concat(missing, ", ")
    end
    local extra = {}
    for _, selector in ipairs(held) do
        if not contains(EXPECTED, selector) then
            extra[#extra + 1] = selector
        end
    end
    if #extra > 0 then
        failures[#failures + 1] = "the object also carries " .. table.concat(extra, ", ") .. ", which the port's reader must never send"
    end

    for _, failure in ipairs(failures) do
        print("FAIL " .. failure)
    end
    print(string.format("sensorkit-reader-object: %d of %d protocol selectors in the object, %d failures%s", #held, #TEN, #failures,
        #failures == 0 and "" or "  <- SEE FAIL"))
    if #failures > 0 then
        os.exit(1)
    end
end
