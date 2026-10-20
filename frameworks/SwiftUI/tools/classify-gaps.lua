local text = import("lib.text", {rootdir = os.scriptdir(), anonymous = true})

local WITNESSES = {}
for _, name in ipairs({
    "Body", "hash", "hashValue", "hashValue(into:)", "Element", "ArrayLiteralElement", "RawValue",
    "Iterator", "SubSequence", "Substring", "Index", "Indices", "startIndex", "endIndex", "index",
    "index(after:)", "index(before:)", "index(_:offsetBy:)", "indices", "all", "rawValue", "count",
    "first", "last", "isEmpty", "description", "debugDescription", "CustomStringConvertible",
    "CustomDebugStringConvertible", "Sendable", "ExpressibleByStringLiteral", "StringInterpolation",
    "StringLiteralType", "UTF8View", "UnicodeScalarView", "StringView",
}) do
    WITNESSES[name] = true
end
local FORMS = {init = true, subscript = true}

local CLASSES = {"declaration-form", "witness", "machinery", "nested", "top-level"}

local function classify(row)
    local owner, _, name = text.partition(row, "#")
    if FORMS[name] then
        return "declaration-form"
    end
    if WITNESSES[name] then
        return "witness"
    end
    if text.startswith(name, "_") then
        return "machinery"
    end
    if string.find(owner, ".", 1, true) then
        return "nested"
    end
    return "top-level"
end

local function read(file)
    local rows = {}
    local content = io.readfile(file)
    local lines = text.split(content, "\n")
    if lines[#lines] == "" then
        lines[#lines] = nil
    end
    for number, line in ipairs(lines) do
        if text.strip(line) ~= "" and not text.startswith(line, "#") then
            if not string.find(line, "#", 1, true) then
                io.stderr:write(string.format("%s: line %d is not Owner#name: %q\n", file, number, line))
                os.exit(1)
            end
            rows[#rows + 1] = line
        end
    end
    return rows
end

function main(...)
    local args = {...}
    local usage = #args ~= 1 and not (#args == 3 and args[2] == "-o")
    if usage then
        io.stderr:write("usage: classify-gaps.lua gaps.tsv [-o classified.tsv]\n")
        os.exit(2)
    end
    local rows = read(args[1])
    local buckets = {}
    for _, name in ipairs(CLASSES) do
        buckets[name] = {}
    end
    for _, row in ipairs(rows) do
        local bucket = buckets[classify(row)]
        bucket[#bucket + 1] = row
    end
    local total = 0
    for _, name in ipairs(CLASSES) do
        local bucket = buckets[name]
        total = total + #bucket
        print(text.ljust(name, 18) .. string.format(" %4d  gap rows", #bucket))
        for i = 1, math.min(3, #bucket) do
            print("    " .. bucket[i])
        end
    end
    print(text.ljust("total", 18) .. string.format(" %4d  gap rows   over %d gap rows, in %d classes",
        total, #rows, #CLASSES))
    if total ~= #rows then
        io.stderr:write("# the classes do not cover every row\n")
        os.exit(1)
    end
    if #args == 3 then
        local out = {}
        out[#out + 1] = string.format("# every row of %s, one class each, in the order the classes are meant to be read",
            path.filename(args[1]))
        out[#out + 1] = "# row\tclass"
        for _, row in ipairs(rows) do
            out[#out + 1] = row .. "\t" .. classify(row)
        end
        io.writefile(args[3], table.concat(out, "\n") .. "\n")
        print("wrote " .. args[3])
    end
end
