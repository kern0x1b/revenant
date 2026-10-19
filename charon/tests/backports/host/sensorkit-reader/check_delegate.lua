-- check_delegate.lua SOURCE - which of SRSensorReaderDelegate's ten methods the port's reader sends.
--
--    xmake l ./check_delegate.lua <path to the port's SRSensorReader.m>
--
-- Prints one line per method, SENT or NEVER, then the two checks run.sh holds the port to, then a summary line. Exits 0 when the
-- reader sends exactly the expected set and every error callback carries SensorKit's own inaccessible-data error; 1 otherwise,
-- naming what it saw.
--
-- WHY A CHECK OVER THE SOURCE AND NOT A DIFFERENTIAL. There is no behavioural oracle for this class on this machine, and that is
-- measured rather than assumed: the host's own SensorKit.framework declares SRSensorReader and implements nothing
-- (respondsToSelector: is 0 for +authorizationStatus and +sharedReader), and the port's own CharonSensorKit.h cannot be compiled
-- against the host's newer SDK at all - clang answers "typedef redefinition with different types ('NSInteger' vs 'enum
-- SRAcousticSettingsSampleLifetime')" for the fifteen enumerations it redeclares, because the host's SensorKit declares them as
-- NS_ENUM. The port's reader is therefore built for armv7 and read back out of its object; this file reads the source, and run.sh
-- proves it can be wrong by planting three changes.
--
-- WHAT COUNTS AS SENT. This class sends its delegate messages in one shape and one shape only:
--
--     id<SRSensorReaderDelegate> delegate = self.delegate;
--     if ([delegate respondsToSelector:@selector(sensorReader:startRecordingFailedWithError:)]) {
--         [delegate sensorReader:self startRecordingFailedWithError:[SRSensorReader storeUnavailableError]];
--     }
--
-- so a method is SENT when some line carries its selector, carries the receiver `[delegate`, and is not the guard line itself. A
-- method the file merely guards against is NEVER, which is the honest reading: nothing in the port ever asks for it.
--
-- The send is matched as the regular expression the Python version built, written out by hand: `[delegate`, one or more blanks,
-- then the keywords in order, each keyword followed by its colon, with no `]` anywhere between the blanks and the closing `]`. For
-- a selector with more than one keyword the first keyword must start right after the blanks; with one keyword it may start later.

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

-- The text of a file as Python's text mode reads it: "\r\n" and a lone "\r" are line ends, and become "\n".
local function read_text(path)
    local handle = assert(io.open(path, "rb"))
    local text = handle:read("a")
    handle:close()
    return (text:gsub("\r\n", "\n"):gsub("\r", "\n"))
end

-- The lines of a text, as Python's split("\n") gives them: a text that ends in a newline ends in an empty line.
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
-- The four the port sends, in the order the failure callbacks are checked, and the ten the header declares, in its own order.
local EXPECTED_SENT = {
    "sensorReader:startRecordingFailedWithError:",
    "sensorReader:stopRecordingFailedWithError:",
    "sensorReader:fetchingRequest:failedWithError:",
    "sensorReader:fetchDevicesDidFailWithError:",
}
local STORE_UNAVAILABLE = "[SRSensorReader storeUnavailableError]"
local DENIED = "SRAuthorizationStatusDenied"

-- The keyword pieces of a selector, each with the colon it is spelled with in a send. The last one carries the colon only when
-- the selector ends in one.
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

-- Whether LINE holds a send of SELECTOR to the delegate: the regular expression \[delegate\s+T1[^\]]*T2...[^\]]*Tn[^\]]*\]
-- tried at every place "[delegate" stands.
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
                    -- with more than one keyword the first one starts right after the blanks
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

-- Every selector this source sends to its delegate, in first-seen order.
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

    -- Every failure callback carries SensorKit's own error rather than one of its own making.
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

    -- The authorization is denied, which is why didChangeAuthorizationStatus: can never fire.
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
