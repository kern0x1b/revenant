import("core.base.json")

local NOT_ANSWERED = { [""] = true, ["nil"] = true, ["(nil)"] = true, ["null"] = true }

local function byte_less(a, b)
    for i = 1, math.min(#a, #b) do
        local x, y = a:byte(i), b:byte(i)
        if x ~= y then
            return x < y
        end
    end
    return #a < #b
end

local function strip(text)
    return (text:gsub("^[ \t\n\r\f\v]+", ""):gsub("[ \t\n\r\f\v]+$", ""))
end

local function has_entries(t)
    for _ in pairs(t) do
        return true
    end
    return false
end

function main(...)
    local args = { ... }
    local path = args[1]
    local handle = assert(io.open(path, "rb"))
    local records = json.decode(handle:read("a"))
    handle:close()
    local is_object = type(records) == "table" and records[1] == nil and has_entries(records)
    if not is_object then
        print(path .. ": no records at all")
        os.exit(1)
    end

    local count, refused = 0, {}
    for name, value in pairs(records) do
        count = count + 1
        if type(value) == "string" and NOT_ANSWERED[strip(value)] then
            refused[#refused + 1] = name
        end
    end
    if #refused > 0 then
        table.sort(refused, byte_less)
        local shown = {}
        for i = 1, math.min(6, #refused) do
            shown[#shown + 1] = refused[i]
        end
        print(string.format("%s: %d case(s) did not answer: %s", path, #refused, table.concat(shown, ", ")))
        os.exit(1)
    end
    print("records: " .. count)
end
