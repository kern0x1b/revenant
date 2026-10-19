local function read_text(path)
    local handle = assert(io.open(path, "rb"))
    local text = handle:read("a")
    handle:close()
    return (text:gsub("\r\n", "\n"):gsub("\r", "\n"))
end

local function py_repr(text)
    local quote = "'"
    if text:find("'", 1, true) and not text:find('"', 1, true) then
        quote = '"'
    end
    local out = text:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
    if quote == "'" then
        out = out:gsub("'", "\\'")
    end
    return quote .. out .. quote
end

local function py_list(items)
    local shown = {}
    for _, item in ipairs(items) do
        shown[#shown + 1] = py_repr(item)
    end
    return "[" .. table.concat(shown, ", ") .. "]"
end

local function starts_with(line, prefix)
    return line:sub(1, #prefix) == prefix
end

local function need(ok, why, detail)
    local tail = ""
    if not ok and detail ~= nil then
        tail = "  " .. detail
    end
    print((ok and "  ok   " or "  FAIL ") .. why .. tail)
    return ok and 0 or 1
end

local function only(lines, prefix)
    local out = {}
    for _, line in ipairs(lines) do
        if starts_with(line, prefix) then
            out[#out + 1] = line
        end
    end
    return out
end

local function any_has(lines, needle)
    for _, line in ipairs(lines) do
        if line:find(needle, 1, true) then
            return true
        end
    end
    return false
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

function main(...)
    local args = { ... }
    local lines = {}
    for _, line in ipairs(split_lines(read_text(args[1]))) do
        if line:find("%S") then
            lines[#lines + 1] = line
        end
    end

    local stored = only(lines, "setObjects: asked the release setValue|")
    local options_calls = only(lines, "setObjects:localOnly: asked the release setItems")
    local bad = 0
    bad = bad + need(any_has(lines, "setItems:options: asked the release setItems|2"),
        "the 10.0 member hands both items to the release's own -setItems:")
    bad = bad + need(any_has(lines, "setItems:options: recorded 1 2030-01-01"),
        "the two option keys are read and recorded: YES and the date the caller sent")
    bad = bad + need(#stored == 2, "-setObjects: stores through the release's own -setValue:forPasteboardType:",
        string.format("it asked for %d values, and it must ask for two", #stored))
    bad = bad + need(any_has(stored, "|charon.string.type.one|plain"),
        "-setObjects: stored the string under the FIRST entry of the string list", py_list(stored))
    bad = bad + need(any_has(stored, "|charon.url.type.one|https://example.invalid/x"),
        "-setObjects: stored the URL under the FIRST entry of the URL list", py_list(stored))
    bad = bad + need(not (any_has(stored, "charon.string.type.two") or any_has(stored, "charon.url.type.two")),
        "-setObjects: stored under no entry but the first", py_list(stored))
    bad = bad + need(any_has(lines, "setObjects:localOnly: asked the release setValue|charon.string.type.one|third"),
        "the options path stores the objects it was given")
    bad = bad + need(any_has(lines, "setObjects:localOnly: recorded 1 2031-02-02"),
        "the second member records its own two options")
    bad = bad + need(#options_calls == 0,
        "the options path never calls the release's -setItems:, so the board is not emptied", py_list(options_calls))
    bad = bad + need(#lines >= 6,
        string.format("the run printed %d lines, the fewest a verdict can rest on - fewer and nothing was read", #lines))
    if bad > 0 then
        os.exit(1)
    end
end
