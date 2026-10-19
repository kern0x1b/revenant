-- classify-gaps.lua: why a row of the 26.2 surface is a gap, as classes the rows themselves support.
--
--     xmake l classify-gaps.lua gaps14.tsv [-o classified.tsv]
--
-- The gaps list is one column, `Owner#name`, and every row in it is a name the 26.2 surface carries and this tree
-- declares nothing for. The rows are not one kind of thing, and a single "missing" count says nothing about why: some
-- name no lookup can ever satisfy, some is a member the compiler writes for a conformance, some is machinery a header
-- declares and no application writes, and some is a member of a type this tree does not declare at all. The classes
-- are therefore ordered, so that every row lands in exactly one, and the count is a partition.
--
--     1 declaration-form  the row names no name at all - `init`, `subscript` - so declaring a name cannot close it
--     2 witness           a member the compiler synthesises for a conformance: an associatedtype witness,
--                         an Equatable/Hashable member, a protocol's collection member
--     3 machinery         a name a header declares for the runtime's own use, underscore-prefixed
--     4 nested            a member of a type nested in another, which the tree's owner is missing
--     5 top-level         a member of a type the tree does not declare, and nothing else about it

local text = import("lib.text", {rootdir = path.join(os.scriptdir(), "..", ".."), anonymous = true})

-- A name the compiler writes out for a conformance rather than a declaration. `init` and `subscript` are not in this
-- set: they are declaration forms, and they are the first class instead.
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

-- the one class this row belongs to, in the order the classes are meant to be read
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

-- the rows of a gaps list: blank lines and comments are skipped, and a line with no `#` is an error
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
