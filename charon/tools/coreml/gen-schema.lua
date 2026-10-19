-- gen-schema.lua: the CoreML model specification as the C schema table CharonMLSchema.c reads.
--   xmake l tools/coreml/gen-schema.lua <coremltools directory> <out> [--check]
--
-- Apple's model format is open: coremltools (BSD-3-Clause, Apple Inc.) ships the protobuf specification the
-- .mlmodel container is written in, as one generated module per .proto file under coremltools/proto/. Every one
-- of those modules registers its own file descriptor with `AddSerializedFile(b'...')`, so the specification is
-- read here from the descriptors themselves - field number, wire type, name, and the type of a message or enum
-- field - rather than transcribed by hand. Nothing in the emitted table is invented; it is what protoc was given.
--
-- --check writes nothing and fails if the checked-in table differs, so a change of coremltools is a diff the
-- reviewer reads rather than a silent regeneration.

-- Lua's `<` on strings follows the locale; byteorder sorts by bytes, as Python's sorted() did.
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

-- The protobuf enum of FieldDescriptorProto.Type, by value.
local TYPE_NAMES = {
    [1] = "TYPE_DOUBLE", [2] = "TYPE_FLOAT", [3] = "TYPE_INT64", [4] = "TYPE_UINT64", [5] = "TYPE_INT32",
    [6] = "TYPE_FIXED64", [7] = "TYPE_FIXED32", [8] = "TYPE_BOOL", [9] = "TYPE_STRING", [10] = "TYPE_GROUP",
    [11] = "TYPE_MESSAGE", [12] = "TYPE_BYTES", [13] = "TYPE_UINT32", [14] = "TYPE_ENUM",
    [15] = "TYPE_SFIXED32", [16] = "TYPE_SFIXED64", [17] = "TYPE_SINT32", [18] = "TYPE_SINT64",
}

-- charon_ml_kind_*, in the order CharonMLSchema.h declares them, with the protobuf type each names and the wire
-- type a value of it is written with. 0 is CHARON_ML_KIND_NONE, which names a field that is neither a number nor
-- a submessage: a repeated field of strings, bytes or messages is one entry per element, a packed repeated
-- number is one run.
local KIND = {
    TYPE_DOUBLE = {1, 1}, TYPE_FLOAT = {2, 5}, TYPE_INT64 = {3, 0}, TYPE_UINT64 = {4, 0},
    TYPE_INT32 = {5, 0}, TYPE_FIXED64 = {6, 1}, TYPE_FIXED32 = {7, 5}, TYPE_BOOL = {8, 0},
    TYPE_STRING = {9, 2}, TYPE_BYTES = {10, 2}, TYPE_MESSAGE = {11, 2}, TYPE_GROUP = {11, 3},
    TYPE_UINT32 = {12, 0}, TYPE_ENUM = {13, 0}, TYPE_SFIXED32 = {14, 5},
    TYPE_SFIXED64 = {15, 1}, TYPE_SINT32 = {16, 0}, TYPE_SINT64 = {17, 0},
}

-- A field of one of these kinds carries a number of the wire type the reader reads directly; a string, bytes,
-- message or group does not (an enum is a varint of its case's number).
local NUMERIC = {[1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true,
                 [12] = true, [14] = true, [15] = true, [16] = true, [17] = true}

local LABEL_REPEATED = 3

-- The varint at pos, and the position after it.
local function read_varint(data, pos)
    local result, shift = 0, 0
    while true do
        local byte = data:byte(pos)
        if byte == nil then
            raise("truncated varint in a serialized descriptor")
        end
        pos = pos + 1
        result = result | ((byte & 0x7f) << shift)
        shift = shift + 7
        if byte < 0x80 then
            break
        end
    end
    return result, pos
end

-- The fields of one serialized message, in order: {number, value}, a varint as an integer and a
-- length-delimited field as its bytes. The fixed-width wire types are skipped; the descriptor has none.
local function read_fields(data)
    local out = {}
    local pos = 1
    while pos <= #data do
        local tag
        tag, pos = read_varint(data, pos)
        local number, wire = tag >> 3, tag & 7
        if wire == 0 then
            local value
            value, pos = read_varint(data, pos)
            table.insert(out, {number = number, value = value})
        elseif wire == 2 then
            local length
            length, pos = read_varint(data, pos)
            table.insert(out, {number = number, value = data:sub(pos, pos + length - 1)})
            pos = pos + length
        elseif wire == 1 then
            pos = pos + 8
        elseif wire == 5 then
            pos = pos + 4
        else
            raise("unsupported wire type %d in a serialized descriptor", wire)
        end
    end
    return out
end

-- proto2 semantics for a singular field: the last one written wins, and an absent one is the default.
local function last(fields, number, default)
    local value = default
    for _, field in ipairs(fields) do
        if field.number == number then
            value = field.value
        end
    end
    return value
end

local function present(fields, number)
    for _, field in ipairs(fields) do
        if field.number == number then
            return true
        end
    end
    return false
end

local function read_field(data)
    local parts = read_fields(data)
    local label = last(parts, 4, 1)
    local type_name = TYPE_NAMES[last(parts, 5, 1)]
    if type_name == nil then
        raise("a field of an unknown protobuf type")
    end
    local kind, wire = KIND[type_name][1], KIND[type_name][2]
    local repeated = label == LABEL_REPEATED
    local oneof = -1
    if present(parts, 9) then
        oneof = last(parts, 9, -1)
    end
    -- protobuf3 packs a repeated field of a packable number type: every numeric one, but no string, no bytes,
    -- no message and no group. A packed field is one length-delimited run, so the wire type the reader matches
    -- is the run's, and the element's own width is in `element`.
    local packed = repeated and NUMERIC[kind] or false
    return {
        name = last(parts, 1, ""),
        number = last(parts, 3, 0),
        wire = packed and 2 or wire,
        kind = kind,
        element = packed and kind or 0,
        type = (last(parts, 6, ""):gsub("^%.+", "")),
        repeated = repeated,
        oneof = oneof,
    }
end

-- messages[name] = the fields, keyed by the name relative to CoreML.Specification, nested ones dotted.
local function walk(data, prefix, messages)
    local parts = read_fields(data)
    local name = last(parts, 1, "")
    local fields = {}
    for _, part in ipairs(parts) do
        if part.number == 2 then
            table.insert(fields, read_field(part.value))
        end
    end
    messages[prefix .. name] = fields
    for _, part in ipairs(parts) do
        if part.number == 3 then
            walk(part.value, prefix .. name .. ".", messages)
        end
    end
end

-- The bytes of a Python bytes literal, with the escapes protoc writes: \xHH, \ooo, and the one-letter ones.
local function decode_literal(body)
    local simple = {n = "\n", r = "\r", t = "\t", a = "\a", b = "\b", f = "\f", v = "\v",
                    ["\\"] = "\\", ["'"] = "'", ['"'] = '"', ["\n"] = ""}
    local out = {}
    local i = 1
    while i <= #body do
        local c = body:sub(i, i)
        if c ~= "\\" then
            table.insert(out, c)
            i = i + 1
        else
            local e = body:sub(i + 1, i + 1)
            if e == "x" then
                table.insert(out, string.char(tonumber(body:sub(i + 2, i + 3), 16)))
                i = i + 4
            elseif e:match("[0-7]") then
                local digits = body:match("^[0-7][0-7]?[0-7]?", i + 1)
                table.insert(out, string.char(tonumber(digits, 8) & 0xff))
                i = i + 1 + #digits
            elseif simple[e] ~= nil then
                table.insert(out, simple[e])
                i = i + 2
            else
                -- an unknown escape is the backslash and its character, as Python keeps them
                table.insert(out, "\\" .. e)
                i = i + 2
            end
        end
    end
    return table.concat(out)
end

local function c_string(text)
    local out = {}
    for index = 1, #text do
        local b = text:byte(index)
        if b >= 32 and b < 127 and b ~= 34 and b ~= 92 then
            table.insert(out, string.char(b))
        else
            table.insert(out, string.format("\\%03o", b))
        end
    end
    return '"' .. table.concat(out) .. '"'
end

local function emit(messages, source)
    local lines = {
        "/* Generated by tools/coreml/gen-schema.lua from the protobuf specification Apple ships in",
        "   coremltools. Do not edit by hand: run the generator and read the diff.",
        "   Source: " .. source .. " */",
        "",
        "const charon_ml_field charon_ml_fields[] = {",
    }
    local names = {}
    for name in pairs(messages) do
        table.insert(names, name)
    end
    byteorder.sort(names)
    local layout, index = {}, 0
    -- Every message of the specification is in the table, including the ones with no fields: a message that
    -- declares none is still a message an empty submessage of that type is, and a reader that had no row for
    -- it would refuse the container that carries one.
    for _, name in ipairs(names) do
        local fields = messages[name]
        table.insert(layout, {name = name, first = index, count = #fields})
        for _, field in ipairs(fields) do
            local flags = {}
            if field.repeated then
                table.insert(flags, "CHARON_ML_REPEATED")
            end
            if field.oneof >= 0 then
                table.insert(flags, string.format("CHARON_ML_ONEOF(%d)", field.oneof))
            end
            table.insert(lines, string.format("    {%s, %d, %d, %d, %d, %s, %s},", c_string(field.name),
                field.number, field.wire, field.kind, field.element, c_string(field.type),
                #flags > 0 and table.concat(flags, " | ") or "0"))
            index = index + 1
        end
    end
    table.insert(lines, "};")
    table.insert(lines, "")
    table.insert(lines, "const charon_ml_message charon_ml_messages[] = {")
    for _, message in ipairs(layout) do
        table.insert(lines, string.format("    {%s, %d, %d},", c_string(message.name), message.first, message.count))
    end
    table.insert(lines, "};")
    table.insert(lines, "")
    table.insert(lines, string.format("const unsigned charon_ml_message_count = %d;", #layout))
    table.insert(lines, string.format("const unsigned charon_ml_field_count = %d;", index))
    return table.concat(lines, "\n") .. "\n", index + #layout
end

function main(coremltools, out, mode)
    local directory = path.join(coremltools, "proto")
    local files = os.files(path.join(directory, "*_pb2.py"))
    byteorder.sort(files)
    local messages = {}
    local descriptors = 0
    for _, file in ipairs(files) do
        local text = io.readfile(file)
        local start = text:find("AddSerializedFile(b'", 1, true)
        -- NamedParameters_pb2.py carries no file of its own: it only re-exports messages the model files
        -- already define, so it adds no descriptor to read.
        if start ~= nil then
            local open = start + #"AddSerializedFile("
            local close = text:find("')\n", open + 2, true)
            if close == nil then
                raise("%s: the serialized descriptor does not end where expected", file)
            end
            local proto = decode_literal(text:sub(open + 2, close - 1))
            descriptors = descriptors + 1
            for _, part in ipairs(read_fields(proto)) do
                if part.number == 4 then
                    walk(part.value, "", messages)
                end
            end
        end
    end
    local count = 0
    for _ in pairs(messages) do
        count = count + 1
    end
    local version = io.readfile(path.join(coremltools, "version.py")):match('__version__ = "([^"]*)"')
    local source = string.format("coremltools %s, its %d .proto descriptors, %d messages", version or "?",
        descriptors, count)
    local text, rows = emit(messages, source)

    if mode == "--check" then
        if io.readfile(out) ~= text then
            raise("differs: %s is not what this coremltools describes", out)
        end
        print("matches: " .. out)
        return
    end
    io.writefile(out, text)
    print(string.format("wrote %s: %d messages, %d fields", out, count, rows))
end
