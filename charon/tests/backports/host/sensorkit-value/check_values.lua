-- check_values.lua SRC170 SRC150 OBJ170 OBJ150 - the five value-object accessors, in the source and in the compiled armv7 object.
--
--    xmake l ./check_values.lua <the port's SensorKit170.m> <the port's SensorKit150.m> <SensorKit170.o> <SensorKit150.o>
--
-- Prints the five, one line each, whether the source implements them the way the store works and whether the compiled object
-- carries the selector. Exits 0 only when all five are both, and 1 naming which.
--
-- WHY SOURCE AND OBJECT, and why nothing here is a differential. There is no behavioural oracle for these five on this machine:
-- the host's SensorKit marks SRKeyboardMetrics, SRSpeechMetrics and SRFaceMetrics API_UNAVAILABLE(macos), so a typed call cannot
-- name them, and the port's CharonSensorKit.h cannot be compiled against the host's newer SDK at all (clang: "typedef redefinition
-- with different types ('NSInteger' vs 'enum SRAcousticSettingsSampleLifetime')"). What the host DOES answer was measured once,
-- separately, by host-answers.m in this directory, and its output is what the port's answers have to be: zero for both counts over
-- all ten sentiment categories, and nil for both speech properties. This file holds the port to implementing exactly that - a count
-- out of the store and a property out of the store, which is zero and nil when nothing is stored - and to the compiled object
-- carrying the selectors, which is what the linker binds an @selector() against.
--
-- A source check alone would pass on a method the compiler never emitted; an object check alone would pass on a method that
-- returns a constant. Both are asked for because they fail differently.
--
-- The source is read as bytes, and the patterns are the ones the Python regular expressions spelled, written out by hand: a
-- position after a literal, then the blanks, then the next literal.

local PROPERTIES = { "faceAnchor", "speechRecognition", "soundClassification" }
local COUNTS = { "wordCountForSentimentCategory:", "emojiCountForSentimentCategory:" }

-- What the port has to be doing, as the source has to spell it. The key of a value property is the property's own name
-- (CharonValueStore's own rule), and a count's key carries its category, because a count per category is ten numbers and one
-- key per method would hold one of them.
local COUNT_SHAPE = "longLongValue"

local function read(path)
    local handle = assert(io.open(path, "rb"))
    local text = handle:read("a")
    handle:close()
    return text
end

-- The set of selector names the object's __objc_methname section holds, one otool line per name: an address of six or more hex
-- digits, two spaces, the name.
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

-- Whether the source declares NAME as a store-backed value property: CHARON_VALUE_PROPERTY(id, NAME), with the blanks
-- a regular expression would allow. A name that is the start of a longer one does not count.
local function declares_value_property(body, name)
    local from = 1
    while true do
        local _, e = body:find("CHARON_VALUE_PROPERTY(", from, true)
        if not e then
            return false
        end
        if body:find("^%s*id%s*,%s*" .. name .. "%s*%)", e + 1) then
            return true
        end
        from = e + 1
    end
end

-- The body of the count method NAME, as -(NSInteger)NAME[^\n]*\n\{(.*?)\n\} finds it: the header's line, then a line that is
-- an open brace alone at the start, then the body up to the first close brace at the start of a line. "" when there is none.
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

-- The body of CharonKeyboardSentimentKey: static NSString *CharonKeyboardSentimentKey([^)]*)\s*\{(.*?)\n\}. "" when there is none.
local function key_helper_body(body)
    local head = "static NSString *CharonKeyboardSentimentKey("
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

    -- The key helper a count reads through. It exists in the port's own file, and the harness checks the three things that make
    -- it right rather than the three words of its name: that the CATEGORY is in it, that the selector is in it, and that both
    -- reach the string. A count that returned 7, or one whose key forgot the category so all ten categories answered the same
    -- number, is caught here - and both of those plants SURVIVED the first version of this file, which is why they are checked
    -- and not assumed.
    local helper_body = key_helper_body(body150)
    local key_ok = helper_body:find("stringWithFormat", 1, true) ~= nil
        and helper_body:find("(long)category", 1, true) ~= nil
        and helper_body:find("selector", 1, true) ~= nil
    print(string.format("%-26s source=%s", "CharonKeyboardSentimentKey",
        key_ok and "selector and category both in the key" or "MISSING OR INCOMPLETE"))
    if not key_ok then
        failures[#failures + 1] = "CharonKeyboardSentimentKey does not build a key from both the selector and the category, so every category would answer the same number"
    end

    for _, name in ipairs(COUNTS) do
        local body = count_body(body150, name)
        local reads_store = body:find("charon_valueForKey:CharonKeyboardSentimentKey(", 1, true) ~= nil
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
