local function byte_less(a, b)
    for i = 1, math.min(#a, #b) do
        local x, y = a:byte(i), b:byte(i)
        if x ~= y then
            return x < y
        end
    end
    return #a < #b
end

local function read_text(path)
    local handle = assert(io.open(path, "rb"))
    local text = handle:read("a")
    handle:close()
    return (text:gsub("\r\n", "\n"):gsub("\r", "\n"))
end

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

local function contains(list, value)
    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end

local ALL_TEN = {
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
local EXPECTED_SENT = {
    "sensorReader:startRecordingFailedWithError:",
    "sensorReader:stopRecordingFailedWithError:",
    "sensorReader:fetchingRequest:failedWithError:",
    "sensorReader:fetchDevicesDidFailWithError:",
}
local STORE_UNAVAILABLE = "[SRSensorReader storeUnavailableError]"
local DENIED = "SRAuthorizationStatusDenied"

local function tokens_for(selector)
    local parts = {}
    for part in selector:gmatch("[^:]+") do
        parts[#parts + 1] = part
    end
    local tokens = {}
    for i = 1, #parts - 1 do
        tokens[#tokens + 1] = parts[i] .. ":"
    end
    tokens[#tokens + 1] = parts[#parts] .. (selector:sub(-1) == ":" and ":" or "")
    return tokens
end

local function sends(line, selector)
    local tokens = tokens_for(selector)
    local from = 1
    while true do
        local _, word_end = line:find("[delegate", from, true)
        if not word_end then
            return false
        end
        from = word_end + 1
        local first = line:find("%S", word_end + 1)
        if first and first > word_end + 1 then
            local close = line:find("]", first, true)
            if close then
                local position = first
                local ok = true
                local index = 1
                if #tokens >= 2 then
                    if line:sub(first, first + #tokens[1] - 1) == tokens[1] then
                        position = first + #tokens[1]
                        index = 2
                    else
                        ok = false
                    end
                end
                while ok and index <= #tokens do
                    local _, token_end = line:find(tokens[index], position, true)
                    if not token_end or token_end >= close then
                        ok = false
                    else
                        position = token_end + 1
                        index = index + 1
                    end
                end
                if ok then
                    return true
                end
            end
        end
    end
end

local function sent_selectors(lines)
    local found = {}
    for _, line in ipairs(lines) do
        if not line:find("respondsToSelector", 1, true) and line:find("[delegate", 1, true) then
            for _, selector in ipairs(ALL_TEN) do
                if sends(line, selector) and not contains(found, selector) then
                    found[#found + 1] = selector
                end
            end
        end
    end
    return found
end

function main(...)
    local args = { ... }
    if #args ~= 1 then
        print("check_delegate.lua: pass the path to the port's SRSensorReader.m")
        os.exit(1)
    end
    local body = read_text(args[1])
    local lines = split_lines(body)
    local sent = sent_selectors(lines)

    for _, selector in ipairs(ALL_TEN) do
        print(string.format("%-8s %s", contains(sent, selector) and "SENT" or "NEVER", selector))
    end

    local failures = {}

    local missing = {}
    for _, selector in ipairs(EXPECTED_SENT) do
        if not contains(sent, selector) then
            missing[#missing + 1] = selector
        end
    end
    if #missing > 0 then
        failures[#failures + 1] = "the reader no longer sends " .. table.concat(missing, ", ")
    end
    local extra = {}
    for _, selector in ipairs(sent) do
        if not contains(EXPECTED_SENT, selector) then
            extra[#extra + 1] = selector
        end
    end
    if #extra > 0 then
        failures[#failures + 1] = "the reader now sends " .. table.concat(extra, ", ") .. ", which nothing in this port should send"
    end

    for _, selector in ipairs(EXPECTED_SENT) do
        if contains(sent, selector) then
            for index, line in ipairs(lines) do
                if line:find(selector, 1, true) and not line:find("respondsToSelector", 1, true) then
                    local window = {}
                    for i = index, math.min(index + 2, #lines) do
                        window[#window + 1] = lines[i]
                    end
                    if not table.concat(window, "\n"):find(STORE_UNAVAILABLE, 1, true) then
                        failures[#failures + 1] = string.format("%s is sent without %s", selector, STORE_UNAVAILABLE)
                    end
                    break
                end
            end
        end
    end

    if not body:find(DENIED, 1, true) then
        failures[#failures + 1] = "the reader no longer answers " .. DENIED
    end

    for _, failure in ipairs(failures) do
        print("FAIL " .. failure)
    end
    print(string.format("sensorkit-reader: %d of %d protocol methods sent, %d failures%s", #sent, #ALL_TEN, #failures,
        #failures == 0 and "" or "  <- SEE FAIL"))
    if #failures > 0 then
        os.exit(1)
    end
end
