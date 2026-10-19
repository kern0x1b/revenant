-- proto.lua: the protobuf of a Core ML container, written and read from the committed schema table.
--
--   local proto = import("proto", {rootdir = os.scriptdir()})
--   local schema = proto.load(path.join(root, "packages", "a", "apple-backports", "CoreML", "CharonMLSchema.inc"))
--   local bytes = proto.encode(schema, "Model", value)     -- value: a Lua table keyed by field name
--   local value = proto.decode(schema, "Model", bytes)     -- only the fields the bytes carry
--   local lines = proto.dump(schema, "Model", value)       -- the reflection print of the tree
--
-- A value is a Lua table. A field is named by its name in the specification; a message field is a table, and a
-- repeated field is an array. A message that is present is a table even when it is empty (SetInParent in the
-- protobuf library), so `ReLU = {}` writes the empty ReLU. A proto3 scalar is written only when it is not zero,
-- which is what the protobuf library does, and a oneof member is written whenever it is set.
--
-- The encoder writes the fields in field-number order, as the protobuf library does, and a repeated numeric field
-- packed, as proto3 does. The dump is the reflection print: the same lines, in the same order and spelling, as the
-- print the Python writer of these containers made. A float is printed the way Python prints a float, the shortest
-- text that reads back as the same double, so a float32 is printed as the double it is.

local KIND = {
    DOUBLE = 1, FLOAT = 2, INT64 = 3, UINT64 = 4, INT32 = 5, FIXED64 = 6, FIXED32 = 7, BOOL = 8, STRING = 9,
    BYTES = 10, MESSAGE = 11, UINT32 = 12, ENUM = 13, SFIXED32 = 14, SFIXED64 = 15, SINT32 = 16, SINT64 = 17,
}
local KIND_NAME = {}
for name, number in pairs(KIND) do
    KIND_NAME[number] = name
end

local WIRE_VARINT, WIRE_64, WIRE_STRING, WIRE_32 = 0, 1, 2, 5
local PREFIX = "CoreML.Specification."

-- The schema table of CharonMLSchema.inc, read into one structure: every message by its name, with its fields in
-- field-number order and by name.
function load(file)
    local schema = {messages = {}}
    local rows, messages = {}, {}
    local in_fields, in_messages = false, false
    for line in io.lines(file) do
        if line:find("^const charon_ml_field charon_ml_fields%[%]") then
            in_fields = true
        elseif line:find("^const charon_ml_message charon_ml_messages%[%]") then
            in_fields, in_messages = false, true
        elseif in_fields or in_messages then
            local name, number, wire, kind, element, type_name, flags =
                line:match('^%s*{"([^"]*)", (%-?%d+), (%d+), (%d+), (%d+), "([^"]*)", ([^}]*)},?%s*$')
            if name then
                table.insert(rows, {name = name, number = tonumber(number), wire = tonumber(wire),
                                    kind = tonumber(kind), element = tonumber(element), type = type_name,
                                    flags = flags})
            else
                local message, first, count = line:match('^%s*{"([^"]*)", (%d+), (%d+)},?%s*$')
                if message then
                    table.insert(messages, {name = message, first = tonumber(first), count = tonumber(count)})
                end
            end
        end
    end
    for _, message in ipairs(messages) do
        local entry = {name = message.name, fields = {}, by_name = {}, by_number = {}}
        for index = message.first + 1, message.first + message.count do
            local row = rows[index]
            local oneof = row.flags:match("^CHARON_ML_ONEOF%((%d+)%)$")
            local field = {
                name = row.name, number = row.number, wire = row.wire, kind = row.kind, element = row.element,
                type = row.type ~= "" and row.type:gsub("^" .. PREFIX, "") or nil,
                repeated = row.flags == "CHARON_ML_REPEATED",
                oneof = oneof ~= nil,
            }
            table.insert(entry.fields, field)
            entry.by_name[field.name] = field
            entry.by_number[field.number] = field
        end
        -- An insertion sort on the field numbers, which are integers: the order does not depend on the locale, and
        -- the light guard keeps the sorts of the tools on byteorder or on a plain loop like this one.
        for index = 2, #entry.fields do
            local field = entry.fields[index]
            local at = index - 1
            while at >= 1 and entry.fields[at].number > field.number do
                entry.fields[at + 1] = entry.fields[at]
                at = at - 1
            end
            entry.fields[at + 1] = field
        end
        schema.messages[message.name] = entry
    end
    return schema
end

local function message_of(schema, name)
    local message = schema.messages[name]
    if message == nil then
        raise("no message %s in the schema", name)
    end
    return message
end

-- A 64-bit two's complement integer, as an unsigned varint: a negative int32 takes ten bytes, as protobuf writes it.
local function varint(out, value)
    repeat
        local byte = value & 0x7f
        value = value >> 7
        if value ~= 0 then
            byte = byte | 0x80
        end
        table.insert(out, string.char(byte))
    until value == 0
end

local function zigzag(value)
    return (value << 1) ~ (value >> 63)
end

local function integer_of(name, value)
    local whole = math.tointeger(value)
    if whole == nil then
        raise("%s is %s, which is not a whole number", name, tostring(value))
    end
    return whole
end

-- The bytes of one scalar value, with no tag.
local function scalar_bytes(out, kind, value, field)
    if kind == KIND.DOUBLE then
        table.insert(out, string.pack("<d", value))
    elseif kind == KIND.FLOAT then
        table.insert(out, string.pack("<f", value))
    elseif kind == KIND.FIXED64 then
        table.insert(out, string.pack("<I8", integer_of(field.name, value)))
    elseif kind == KIND.SFIXED64 then
        table.insert(out, string.pack("<i8", integer_of(field.name, value)))
    elseif kind == KIND.FIXED32 then
        table.insert(out, string.pack("<I4", integer_of(field.name, value)))
    elseif kind == KIND.SFIXED32 then
        table.insert(out, string.pack("<i4", integer_of(field.name, value)))
    elseif kind == KIND.BOOL then
        varint(out, value and 1 or 0)
    elseif kind == KIND.SINT32 or kind == KIND.SINT64 then
        varint(out, zigzag(integer_of(field.name, value)))
    elseif kind == KIND.STRING or kind == KIND.BYTES then
        varint(out, #value)
        table.insert(out, value)
    else
        varint(out, integer_of(field.name, value))
    end
end

local function wire_of(kind)
    if kind == KIND.DOUBLE or kind == KIND.FIXED64 or kind == KIND.SFIXED64 then
        return WIRE_64
    elseif kind == KIND.FLOAT or kind == KIND.FIXED32 or kind == KIND.SFIXED32 then
        return WIRE_32
    elseif kind == KIND.STRING or kind == KIND.BYTES or kind == KIND.MESSAGE then
        return WIRE_STRING
    end
    return WIRE_VARINT
end

local function is_zero(value)
    return value == 0 or value == "" or value == false
end

local encode_message

-- The bytes of one field, tag included, or nothing when the field is absent or is a proto3 zero.
local function field_bytes(schema, field, value, out)
    if value == nil then
        return
    end
    local tag = field.number << 3
    if field.repeated then
        if field.kind == KIND.MESSAGE then
            for _, item in ipairs(value) do
                local body = encode_message(schema, field.type, item)
                varint(out, tag | WIRE_STRING)
                varint(out, #body)
                table.insert(out, body)
            end
        elseif field.element ~= 0 and #value > 0 then
            -- packed: one run of the element's wire format under one tag
            local run = {}
            for _, item in ipairs(value) do
                scalar_bytes(run, field.element, item, field)
            end
            local body = table.concat(run)
            varint(out, tag | WIRE_STRING)
            varint(out, #body)
            table.insert(out, body)
        else
            for _, item in ipairs(value) do
                varint(out, tag | wire_of(field.kind))
                scalar_bytes(out, field.kind, item, field)
            end
        end
    elseif field.kind == KIND.MESSAGE then
        local body = encode_message(schema, field.type, value)
        varint(out, tag | WIRE_STRING)
        varint(out, #body)
        table.insert(out, body)
    else
        if is_zero(value) and not field.oneof then
            return
        end
        varint(out, tag | wire_of(field.kind))
        scalar_bytes(out, field.kind, value, field)
    end
end

function encode_message(schema, name, value)
    local message = message_of(schema, name)
    for key in pairs(value) do
        if message.by_name[key] == nil then
            raise("%s has no field %s in the specification", name, tostring(key))
        end
    end
    local out = {}
    for _, field in ipairs(message.fields) do
        field_bytes(schema, field, value[field.name], out)
    end
    return table.concat(out)
end

-- The bytes of the message `name` holding `value`.
function encode(schema, name, value)
    return encode_message(schema, name, value)
end

-- One value of a scalar kind read from the bytes at `at`; returns the value and the index after it.
local function read_scalar(bytes, at, kind)
    if kind == KIND.DOUBLE then
        return string.unpack("<d", bytes, at)
    elseif kind == KIND.FLOAT then
        return string.unpack("<f", bytes, at)
    elseif kind == KIND.FIXED64 then
        return string.unpack("<I8", bytes, at)
    elseif kind == KIND.SFIXED64 then
        return string.unpack("<i8", bytes, at)
    elseif kind == KIND.FIXED32 then
        return string.unpack("<I4", bytes, at)
    elseif kind == KIND.SFIXED32 then
        return string.unpack("<i4", bytes, at)
    end
    local value, shift = 0, 0
    repeat
        local byte = bytes:byte(at)
        at = at + 1
        value = value | ((byte & 0x7f) << shift)
        shift = shift + 7
    until byte < 0x80
    if kind == KIND.BOOL then
        return value ~= 0, at
    elseif kind == KIND.SINT32 or kind == KIND.SINT64 then
        return (value >> 1) ~ -(value & 1), at
    end
    return value, at
end

local function read_varint(bytes, at)
    return read_scalar(bytes, at, KIND.UINT64)
end

local decode_message

-- Stores one decoded value of a field in the table of its message.
local function store(value, field, item)
    if field.repeated then
        value[field.name] = value[field.name] or {}
        table.insert(value[field.name], item)
    else
        value[field.name] = item
    end
end

function decode_message(schema, name, bytes)
    local message = message_of(schema, name)
    local value = {}
    local at = 1
    while at <= #bytes do
        local tag
        tag, at = read_varint(bytes, at)
        local number, wire = tag >> 3, tag & 7
        local field = message.by_number[number]
        if field == nil then
            raise("%s carries field %d, which the specification does not declare", name, number)
        end
        if wire == WIRE_STRING then
            local length
            length, at = read_varint(bytes, at)
            local body = bytes:sub(at, at + length - 1)
            at = at + length
            if field.kind == KIND.MESSAGE then
                store(value, field, decode_message(schema, field.type, body))
            elseif field.kind == KIND.STRING or field.kind == KIND.BYTES then
                store(value, field, body)
            elseif field.repeated and field.element ~= 0 then
                -- packed: the run is read element by element until it is used up
                local items, inside = value[field.name] or {}, 1
                while inside <= #body do
                    local item
                    item, inside = read_scalar(body, inside, field.element)
                    table.insert(items, item)
                end
                value[field.name] = items
            else
                -- a packed run of a kind this reader does not expect is a length-delimited value it refuses
                raise("%s.%s arrives as a length-delimited run of kind %d, which is not packed", name, field.name,
                      field.kind)
            end
        else
            local item
            item, at = read_scalar(bytes, at, field.kind)
            store(value, field, item)
        end
    end
    return value
end

-- The table of the message `name` that these bytes carry; a field the specification does not declare is refused.
function decode(schema, name, bytes)
    return decode_message(schema, name, bytes)
end

-- The shortest decimal text that reads back as this double, spelled the way Python's repr spells a float.
function float_text(x)
    if x ~= x or x == math.huge or x == -math.huge then
        raise("a non-finite value %s is not written", tostring(x))
    end
    if x == 0 then
        return (1 / x < 0) and "-0.0" or "0.0"
    end
    local text
    for precision = 0, 16 do
        text = string.format("%." .. precision .. "e", x)
        if tonumber(text) == x then
            break
        end
    end
    local mantissa, power = text:match("^%-?(%d%.?%d*)e([-+]%d+)$")
    local all = mantissa:gsub("%.", ""):gsub("0+$", "")
    local e = tonumber(power)
    local sign = x < 0 and "-" or ""
    local body
    if e >= -4 and e < 16 then
        if e >= 0 then
            local whole = all:sub(1, e + 1)
            whole = whole .. string.rep("0", e + 1 - #whole)
            local fraction = all:sub(e + 2)
            body = whole .. "." .. (fraction == "" and "0" or fraction)
        else
            body = "0." .. string.rep("0", -e - 1) .. all
        end
    else
        local mantissa = all:sub(1, 1)
        if #all > 1 then
            mantissa = mantissa .. "." .. all:sub(2)
        end
        body = mantissa .. "e" .. (e < 0 and "-" or "+") .. string.format("%02d", math.abs(e))
    end
    return sign .. body
end

-- How a value is printed in the reflection text: a string in Python's repr, a bytes field as its length, a float
-- as Python's float, a bool as True or False, an integer as itself.
local function spelled(kind, value)
    if kind == KIND.STRING then
        return "'" .. value:gsub("\\", "\\\\"):gsub("'", "\\'") .. "'"
    elseif kind == KIND.BYTES then
        return "<" .. #value .. " bytes>"
    elseif kind == KIND.DOUBLE or kind == KIND.FLOAT then
        return float_text(value)
    elseif kind == KIND.BOOL then
        return value and "True" or "False"
    end
    return string.format("%d", value)
end

local function walk(schema, name, value, indent, lines)
    local message = message_of(schema, name)
    local pad = string.rep("  ", indent)
    for _, field in ipairs(message.fields) do
        local item = value[field.name]
        if item ~= nil then
            if field.repeated then
                if field.kind == KIND.MESSAGE then
                    for index, element in ipairs(item) do
                        table.insert(lines, string.format("%s%s[%d] {", pad, field.name, index - 1))
                        walk(schema, field.type, element, indent + 1, lines)
                        table.insert(lines, pad .. "}")
                    end
                else
                    local flat = {}
                    for _, element in ipairs(item) do
                        table.insert(flat, spelled(field.kind, element))
                    end
                    table.insert(lines, string.format("%s%s = [%s]", pad, field.name, table.concat(flat, ", ")))
                end
            elseif field.kind == KIND.MESSAGE then
                table.insert(lines, pad .. field.name .. " {")
                walk(schema, field.type, item, indent + 1, lines)
                table.insert(lines, pad .. "}")
            else
                table.insert(lines, string.format("%s%s = %s", pad, field.name, spelled(field.kind, item)))
            end
        end
    end
end

-- The reflection print of the message `name` holding `value`, one line per entry, as a list of lines.
function dump(schema, name, value)
    local lines = {}
    walk(schema, name, value, 0, lines)
    return lines
end

