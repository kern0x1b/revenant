local PROPERTIES = { "faceAnchor", "speechRecognition", "soundClassification" }
local COUNTS = { "wordCountForSentimentCategory:", "emojiCountForSentimentCategory:" }

local COUNT_SHAPE = "longLongValue"

local function read(path)
    local handle = assert(io.open(path, "rb"))
    local text = handle:read("a")
    handle:close()
    return text
end

local function selectors(obj)
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

local function declares_value_property(body, name)
    local from = 1
    while true do
        local _, e = body:find("REVENANT_VALUE_PROPERTY(", from, true)
        if not e then
            return false
        end
        if body:find("^%s*id%s*,%s*" .. name .. "%s*%)", e + 1) then
            return true
        end
        from = e + 1
    end
end

local function count_body(body, name)
    local head = "-(NSInteger)" .. name
    local from = 1
    while true do
        local _, e = body:find(head, from, true)
        if not e then
            return ""
        end
        local newline = body:find("\n", e + 1, true)
        if newline and body:sub(newline + 1, newline + 1) == "{" then
            local close = body:find("\n}", newline + 2, true)
            if close then
                return body:sub(newline + 2, close - 1)
            end
        end
        from = e + 1
    end
end

local function key_helper_body(body)
    local head = "static NSString *RevenantKeyboardSentimentKey("
    local from = 1
    while true do
        local _, e = body:find(head, from, true)
        if not e then
            return ""
        end
        local close = body:find(")", e + 1, true)
        if close then
            local _, brace = body:find("^%s*{", close + 1)
            local end_of_body = brace and body:find("\n}", brace + 1, true)
            if end_of_body then
                return body:sub(brace + 1, end_of_body - 1)
            end
        end
        from = e + 1
    end
end

function main(...)
    local args = { ... }
    if #args ~= 4 then
        print("check_values.lua: pass SensorKit170.m SensorKit150.m and their two armv7 objects")
        os.exit(1)
    end
    local src170, src150, obj170, obj150 = args[1], args[2], args[3], args[4]
    local body170, body150 = read(src170), read(src150)
    local in170, in150 = selectors(obj170), selectors(obj150)

    local failures, ok_lines = {}, {}

    for _, name in ipairs(PROPERTIES) do
        local implemented = declares_value_property(body170, name)
        local carried = in170[name] ~= nil
        local line = string.format("%-26s source=%s object=%s", name,
            implemented and "store-backed" or "MISSING",
            carried and "selector present" or "SELECTOR ABSENT")
        print(line)
        if implemented and carried then
            ok_lines[#ok_lines + 1] = line
        end
        if not implemented then
            failures[#failures + 1] = string.format("%s is not a store-backed value property in %s", name, src170)
        end
        if not carried then
            failures[#failures + 1] = string.format("%s is not in the compiled object %s", name, obj170)
        end
    end

    local helper_body = key_helper_body(body150)
    local key_ok = helper_body:find("stringWithFormat", 1, true) ~= nil
        and helper_body:find("(long)category", 1, true) ~= nil
        and helper_body:find("selector", 1, true) ~= nil
    print(string.format("%-26s source=%s", "RevenantKeyboardSentimentKey",
        key_ok and "selector and category both in the key" or "MISSING OR INCOMPLETE"))
    if not key_ok then
        failures[#failures + 1] = "RevenantKeyboardSentimentKey does not build a key from both the selector and the category, so every category would answer the same number"
    end

    for _, name in ipairs(COUNTS) do
        local body = count_body(body150, name)
        local reads_store = body:find("revenant_valueForKey:RevenantKeyboardSentimentKey(", 1, true) ~= nil
            and body:find('@"' .. name .. '"', 1, true) ~= nil
        local carries_type = body:find(COUNT_SHAPE, 1, true) ~= nil
        local implemented = reads_store and carries_type
        local carried = in150[name] ~= nil
        local line = string.format("%-26s source=%s object=%s", name,
            implemented and "store-backed count" or "MISSING",
            carried and "selector present" or "SELECTOR ABSENT")
        print(line)
        if implemented and carried then
            ok_lines[#ok_lines + 1] = line
        end
        if not reads_store then
            failures[#failures + 1] = string.format("%s does not read its count out of the store under its own key with the category in it", name)
        end
        if not carries_type then
            failures[#failures + 1] = string.format("%s does not read its count through longLongValue, so a count of nothing would not be zero", name)
        end
        if not carried then
            failures[#failures + 1] = string.format("%s is not in the compiled object %s", name, obj150)
        end
    end

    for _, failure in ipairs(failures) do
        print("FAIL " .. failure)
    end
    print(string.format("sensorkit-value: %d of %d accessors in the source and in the object, %d failures%s",
        #ok_lines, #PROPERTIES + #COUNTS, #failures, #failures == 0 and "" or "  <- SEE FAIL"))
    if #failures > 0 then
        os.exit(1)
    end
end
