import("core.base.json")

local registry_extensions = {"SPV_AMD_gpu_shader_half_float", "SPV_AMD_gpu_shader_int16", "SPV_KHR_non_semantic_info",
                             "SPV_EXT_relaxed_printf_string_address_space"}

local extinst_specs = {{prefix = "", file = "extinst.glsl.std.450.grammar.json"},
                       {prefix = "", file = "extinst.opencl.std.100.grammar.json"},
                       {prefix = "CLDEBUG100_", file = "extinst.opencl.debuginfo.100.grammar.json"},
                       {prefix = "SHDEBUG100_", file = "extinst.nonsemantic.shader.debuginfo.100.grammar.json"},
                       {prefix = "", file = "extinst.spv-amd-shader-explicit-vertex-parameter.grammar.json"},
                       {prefix = "", file = "extinst.spv-amd-shader-trinary-minmax.grammar.json"},
                       {prefix = "", file = "extinst.spv-amd-gcn-shader.grammar.json"},
                       {prefix = "", file = "extinst.spv-amd-shader-ballot.grammar.json"},
                       {prefix = "", file = "extinst.debuginfo.grammar.json"},
                       {prefix = "", file = "extinst.nonsemantic.clspvreflection.grammar.json"},
                       {prefix = "", file = "extinst.nonsemantic.vkspreflection.grammar.json"},
                       {prefix = "TOSA_", file = "extinst.tosa.001000.1.grammar.json"}}

local language_headers = {{name = "DebugInfo", file = "extinst.debuginfo.grammar.json"},
                          {name = "OpenCLDebugInfo100", file = "extinst.opencl.debuginfo.100.grammar.json"},
                          {name = "NonSemanticShaderDebugInfo100", file = "extinst.nonsemantic.shader.debuginfo.100.grammar.json"}}

local optional_variant_kinds = {"ImageOperands", "AccessQualifier", "MemoryAccess", "PackedVectorFormat",
                                "CooperativeMatrixOperands", "MatrixMultiplyAccumulateOperands",
                                "RawAccessChainOperands", "FPEncoding", "TensorOperands", "Capability"}

local function field(object, key)
    local value = object[key]
    if value == json.null then
        return nil
    end
    return value
end

local function list(object, key)
    return field(object, key) or {}
end

local function integer_text(value)
    assert(type(value) == "number" and value == math.floor(value), "not an integer: " .. tostring(value))
    return string.format("%.0f", value)
end

local function text(value)
    if type(value) == "string" then
        return value
    elseif type(value) == "number" then
        return integer_text(value)
    elseif type(value) == "boolean" then
        return value and "True" or "False"
    end
    raise("cannot print a %s", type(value))
end

local function less_bytes(a, b)
    local length = math.min(#a, #b)
    for i = 1, length do
        local x, y = a:byte(i), b:byte(i)
        if x ~= y then
            return x < y
        end
    end
    return #a < #b
end

local function stable_sort(items, less)
    local count = #items
    if count < 2 then
        return items
    end
    local source, target = {}, {}
    for i = 1, count do
        source[i] = items[i]
    end
    local width = 1
    while width < count do
        local low = 1
        while low <= count do
            local middle = math.min(low + width, count + 1)
            local high = math.min(low + 2 * width, count + 1)
            local i, j, k = low, middle, low
            while i < middle and j < high do
                if less(source[j], source[i]) then
                    target[k] = source[j]
                    j = j + 1
                else
                    target[k] = source[i]
                    i = i + 1
                end
                k = k + 1
            end
            while i < middle do
                target[k] = source[i]
                i = i + 1
                k = k + 1
            end
            while j < high do
                target[k] = source[j]
                j = j + 1
                k = k + 1
            end
            low = high
        end
        source, target = target, source
        width = width * 2
    end
    return source
end

local function sorted_by(items, key, less)
    local keyed = {}
    for i, item in ipairs(items) do
        keyed[i] = {key = key(item), item = item}
    end
    keyed = stable_sort(keyed, function (a, b) return less(a.key, b.key) end)
    local result = {}
    for i, entry in ipairs(keyed) do
        result[i] = entry.item
    end
    return result
end

local function less_number(a, b)
    return a < b
end

local function ordered_map()
    return {keys = {}, values = {}}
end

local function ordered_set(map, key, value)
    if map.values[key] == nil then
        table.insert(map.keys, key)
    end
    map.values[key] = value
end

local function utf8_codepoints(s)
    local codepoints = {}
    local i, length = 1, #s
    while i <= length do
        local byte = s:byte(i)
        local count, codepoint
        if byte < 0x80 then
            count, codepoint = 1, byte
        elseif byte >= 0xf0 then
            count, codepoint = 4, byte - 0xf0
        elseif byte >= 0xe0 then
            count, codepoint = 3, byte - 0xe0
        elseif byte >= 0xc0 then
            count, codepoint = 2, byte - 0xc0
        else
            raise("invalid UTF-8 in %q", s)
        end
        for j = i + 1, i + count - 1 do
            local continuation = s:byte(j)
            if not continuation or continuation < 0x80 or continuation >= 0xc0 then
                raise("invalid UTF-8 in %q", s)
            end
            codepoint = codepoint * 64 + (continuation - 0x80)
        end
        table.insert(codepoints, {codepoint = codepoint, bytes = s:sub(i, i + count - 1)})
        i = i + count
    end
    return codepoints
end

local short_escapes = {[0x22] = "\\\"", [0x5c] = "\\\\", [0x0a] = "\\n", [0x0d] = "\\r", [0x09] = "\\t",
                       [0x08] = "\\b", [0x0c] = "\\f"}

local function json_string_body(s)
    local parts = {}
    for _, character in ipairs(utf8_codepoints(s)) do
        local codepoint = character.codepoint
        if short_escapes[codepoint] then
            table.insert(parts, short_escapes[codepoint])
        elseif codepoint < 0x20 then
            table.insert(parts, string.format("\\u%04x", codepoint))
        elseif codepoint < 0x7f + 1 then
            table.insert(parts, character.bytes)
        elseif codepoint < 0x10000 then
            table.insert(parts, string.format("\\u%04x", codepoint))
        else
            local offset = codepoint - 0x10000
            table.insert(parts, string.format("\\u%04x\\u%04x", 0xd800 + math.floor(offset / 0x400), 0xdc00 + offset % 0x400))
        end
    end
    local body = '"' .. table.concat(parts) .. '"'
    return (body:gsub('^"+', ""):gsub('"+$', ""))
end

local function c_string(s)
    return '"' .. json_string_body(s) .. '\\0"'
end

local function safe_identifier(s)
    local parts = {"k"}
    for _, character in ipairs(utf8_codepoints(s)) do
        if character.bytes:match("^[a-zA-Z0-9]$") then
            table.insert(parts, character.bytes)
        else
            table.insert(parts, "_")
        end
    end
    return table.concat(parts)
end

local function index_range(first, count)
    return {first = first, count = count}
end

local function range_text(range)
    return "IR(" .. range.first .. ", " .. range.count .. ")"
end

local function range_key(range)
    return range.first .. " " .. range.count
end

local function new_context()
    return {total = 0, buffer = {}, strings = {}, by_range = {}, range_buffer = {}, ranges = {}}
end

local function add_string(context, s)
    local found = context.strings[s]
    if found then
        return found
    end
    local space = #utf8_codepoints(s) + 1
    local range = index_range(context.total, space)
    context.strings[s] = range
    context.by_range[range_key(range)] = s
    context.total = context.total + space
    table.insert(context.buffer, s)
    return range
end

local function get_string(context, range)
    local s = context.by_range[range_key(range)]
    if s == nil then
        raise("unregistered index range %s", range_text(range))
    end
    return s
end

local function add_string_list(context, kind, words)
    local entry = context.ranges[kind]
    if not entry then
        entry = {}
        context.ranges[kind] = entry
        context.range_buffer[kind] = {}
    end
    local key = #words .. "\0" .. table.concat(words, "\0")
    if entry[key] then
        return entry[key]
    end
    local new_ranges = {}
    for _, word in ipairs(words) do
        table.insert(new_ranges, add_string(context, word))
    end
    local buffer = context.range_buffer[kind]
    local range = index_range(#buffer, #new_ranges)
    for _, item in ipairs(new_ranges) do
        table.insert(buffer, item)
    end
    entry[key] = range
    return range
end

local function min_version(version)
    if version == nil then
        return "SPV_SPIRV_VERSION_WORD(1, 0)"
    end
    if version == "None" then
        return "0xffffffffu"
    end
    return "SPV_SPIRV_VERSION_WORD(" .. version:gsub("%.", ",") .. ")"
end

local function max_version(version)
    if version == nil then
        return "0xffffffffu"
    end
    return "SPV_SPIRV_VERSION_WORD(" .. version:gsub("%.", ",") .. ")"
end

local kind_renames = {IdResultType = "TypeId", IdResult = "ResultId", IdMemorySemantics = "MemorySemanticsId",
                      MemorySemantics = "MemorySemanticsId", IdScope = "ScopeId", Scope = "ScopeId", IdRef = "Id",
                      ImageOperands = "Image", Dim = "Dimensionality", ImageFormat = "SamplerImageFormat",
                      KernelEnqueueFlags = "KernelEnqFlags", LiteralExtInstInteger = "ExtensionInstructionNumber",
                      LiteralSpecConstantOpInteger = "SpecConstantOpNumber",
                      LiteralContextDependentNumber = "TypedLiteralNumber", PairLiteralIntegerIdRef = "LiteralIntegerId",
                      PairIdRefLiteralInteger = "IdLiteralInteger", PairIdRefIdRef = "Id"}

local function ctype(kind, quantifier)
    if kind == "" then
        raise("operand JSON object missing a 'kind' field")
    end
    kind = kind_renames[kind] or kind
    if kind == "FPRoundingMode" then
        kind = "FpRoundingMode"
    elseif kind == "FPFastMathMode" then
        kind = "FpFastMathMode"
    end
    if quantifier == "?" then
        kind = "Optional" .. kind
    elseif quantifier == "*" then
        kind = "Variable" .. kind
    end
    return "SPV_OPERAND_TYPE_" .. kind:gsub("([a-z])([A-Z])", "%1_%2"):upper()
end

local function operand_kind(object)
    return ctype(field(object, "kind") or "", field(object, "quantifier") or "")
end

local function operand_value(enumerant)
    local value = field(enumerant, "value")
    if type(value) == "number" then
        return value
    elseif type(value) == "string" then
        local parsed
        if value:startswith("0x") then
            parsed = tonumber(value:sub(3), 16)
        else
            parsed = tonumber(value, 10)
        end
        if parsed == nil then
            raise("invalid operand value %s", value)
        end
        return parsed
    end
    raise("operand needs a value integer or string")
end

local function enumerant_name(enumerant)
    local name = field(enumerant, "enumerant")
    if name == nil then
        raise("operand needs an enumerant string")
    end
    return name
end

local function join(parts, separator)
    return table.concat(parts, separator)
end

local function append(target, items)
    for _, item in ipairs(items) do
        table.insert(target, item)
    end
end

local function emits_table(kind)
    local category = field(kind, "category")
    return category == "ValueEnum" or category == "BitEnum"
end

local function new_grammar(extensions, operand_kinds, printing_classes)
    local grammar = {context = new_context(), header = {}, body = {}}
    grammar.extensions = extensions
    grammar.operand_kinds = sorted_by(operand_kinds, operand_kind, less_bytes)
    local identifiers = {}
    for _, class in ipairs(printing_classes) do
        table.insert(identifiers, safe_identifier(class))
    end
    grammar.printing_classes = stable_sort(identifiers, less_bytes)
    if #grammar.operand_kinds == 0 then
        raise("operand_kinds should be a non-empty list")
    end
    if #grammar.extensions == 0 then
        raise("extensions should be a non-empty list")
    end

    table.insert(grammar.header, "enum class PrintingClass : uint32_t {")
    for _, class in ipairs(grammar.printing_classes) do
        table.insert(grammar.header, "  " .. class .. ",")
    end
    table.insert(grammar.header, "};\n")

    table.insert(grammar.header, "enum Extension : uint32_t {")
    for _, extension in ipairs(grammar.extensions) do
        table.insert(grammar.header, "  " .. safe_identifier(extension) .. ",")
    end
    table.insert(grammar.header, "};\n")

    local body = grammar.body
    table.insert(body, "// Returns the name of an extension, as an index into kStrings")
    table.insert(body, "IndexRange ExtensionToIndexRange(Extension extension) {\n  switch(extension) {")
    for _, extension in ipairs(grammar.extensions) do
        table.insert(body, "    case Extension::k" .. extension .. ": return " .. range_text(add_string(grammar.context, extension)) .. ";")
    end
    table.insert(body, "    default: break;")
    table.insert(body, "  }\n  return {};\n}\n")

    table.insert(body, "// Extension names and values, ordered by name\n// The fields in order are:\n//   name, indexing into kStrings\n//   enum value")
    table.insert(body, "static const std::array<NameValue," .. #grammar.extensions .. "> kExtensionNames{{")
    for _, extension in ipairs(grammar.extensions) do
        table.insert(body, "    {" .. range_text(add_string(grammar.context, extension)) .. ", static_cast<uint32_t>(" .. safe_identifier(extension) .. ")},")
    end
    table.insert(body, "}};\n")
    return grammar
end

local function compute_operand_tables(grammar)
    local context, body = grammar.context, grammar.body
    local by_value = {}
    local by_value_by_kind = ordered_map()
    local index_by_kind_and_value = {}
    local index = 0
    for _, kind in ipairs(grammar.operand_kinds) do
        local kind_key = operand_kind(kind)
        if emits_table(kind) then
            local descriptions = {}
            local enumerants = sorted_by(list(kind, "enumerants"), operand_value, less_number)
            for _, enumerant in ipairs(enumerants) do
                local suboperands = {}
                for _, parameter in ipairs(list(enumerant, "parameters")) do
                    table.insert(suboperands, operand_kind(parameter))
                end
                local value = operand_value(enumerant)
                local name = enumerant_name(enumerant)
                local operands = add_string_list(context, "operand", suboperands)
                local name_range = add_string(context, name)
                local aliases = add_string_list(context, "alias", list(enumerant, "aliases"))
                local capabilities = add_string_list(context, "capability", list(enumerant, "capabilities"))
                local extensions = add_string_list(context, "extension", list(enumerant, "extensions"))
                local fields = {integer_text(value), range_text(operands), range_text(name_range) .. "/* " .. name .. " */",
                                range_text(aliases), range_text(capabilities), range_text(extensions),
                                min_version(field(enumerant, "version")), max_version(field(enumerant, "lastVersion"))}
                table.insert(descriptions, "{" .. join(fields, ",") .. "}, // " .. kind_key)
                index_by_kind_and_value[kind_key .. "\0" .. integer_text(value)] = index
                index = index + 1
            end
            ordered_set(by_value_by_kind, kind_key, index_range(#by_value, #descriptions))
            append(by_value, descriptions)
        end
    end

    table.insert(body, "// Operand descriptions, ordered by (operand kind, operand enum value).\n// The fields in order are:\n//   enum value\n//   operands, an IndexRange into kOperandSpans\n//   name, a character-counting IndexRange into kStrings\n//   aliases, an IndexRange into kAliasSpans\n//   capabilities, an IndexRange into kCapabilitySpans\n//   extensions, as an IndexRange into kExtensionSpans\n//   version, first version of SPIR-V that has it\n//   lastVersion, last version of SPIR-V that has it")
    table.insert(body, "static const std::array<OperandDesc, " .. #by_value .. "> kOperandsByValue{{")
    for _, line in ipairs(by_value) do
        table.insert(body, "  " .. line)
    end
    table.insert(body, "}};\n")

    table.insert(body, "// Maps an operand kind to possible operands for that kind.\n// The result is an IndexRange into kOperandsByValue, and the operands\n// are sorted by value within that span.\n// An optional variant of a kind maps to the details for the corresponding\n// concrete operand kind.")
    table.insert(body, "IndexRange OperandByValueRangeForKind(spv_operand_type_t type) {\n  switch(type) {")
    for _, kind_key in ipairs(by_value_by_kind.keys) do
        table.insert(body, "    case " .. kind_key .. ": return " .. range_text(by_value_by_kind.values[kind_key]) .. ";")
    end
    for _, kind in ipairs(optional_variant_kinds) do
        local concrete = ctype(kind, "")
        local range = by_value_by_kind.values[concrete]
        if range == nil then
            raise("error: unknown operand type %s, from JSON grammar operand '%s': consider updating spv_operand_type_t in spirv-tools/libspirv.h", concrete, kind)
        end
        table.insert(body, "    case " .. ctype(kind, "?") .. ": return " .. range_text(range) .. ";")
    end
    table.insert(body, "    default: break;")
    table.insert(body, "  }\n  return IR(0,0);\n}\n")

    local names = {}
    local name_range_for_kind = ordered_map()
    for _, kind in ipairs(grammar.operand_kinds) do
        local kind_key = operand_kind(kind)
        if emits_table(kind) then
            local tuples = {}
            for _, enumerant in ipairs(list(kind, "enumerants")) do
                local value = operand_value(enumerant)
                table.insert(tuples, {name = enumerant_name(enumerant), value = value, kind = kind_key})
                for _, alias in ipairs(list(enumerant, "aliases")) do
                    table.insert(tuples, {name = alias, value = value, kind = kind_key})
                end
            end
            tuples = sorted_by(tuples, function (tuple) return tuple.name end, less_bytes)
            local start = #names
            for _, tuple in ipairs(tuples) do
                table.insert(names, {range = add_string(context, tuple.name), value = tuple.value, kind = tuple.kind})
            end
            ordered_set(name_range_for_kind, kind_key, index_range(start, #tuples))
        end
    end

    table.insert(body, "// Operand names and index into kOperandsByValue, ordered by (operand kind, name)\n// The fields in order are:\n//   name, either the primary name or an alias, indexing into kStrings\n//   index into the kOperandsByValue array")
    table.insert(body, "static const std::array<NameIndex, " .. #names .. "> kOperandNames{{")
    for i, entry in ipairs(names) do
        local position = index_by_kind_and_value[entry.kind .. "\0" .. integer_text(entry.value)]
        table.insert(body, "  {" .. range_text(entry.range) .. ", " .. position .. "}, // " .. (i - 1) .. " " .. get_string(context, entry.range) .. " in " .. entry.kind)
    end
    table.insert(body, "}};\n")

    table.insert(body, "IndexRange OperandNameRangeForKind(spv_operand_type_t type) {\n  switch(type) {")
    for _, kind_key in ipairs(name_range_for_kind.keys) do
        table.insert(body, "    case " .. kind_key .. ": return " .. range_text(name_range_for_kind.values[kind_key]) .. ";")
    end
    for _, kind in ipairs(optional_variant_kinds) do
        local range = name_range_for_kind.values[ctype(kind, "")]
        if range == nil then
            raise("no operand names for %s", ctype(kind, ""))
        end
        table.insert(body, "    case " .. ctype(kind, "?") .. ": return " .. range_text(range) .. ";")
    end
    table.insert(body, "    default: break;")
    table.insert(body, "  }\n  return IR(0,0);\n}\n")
end

local function opcode_of(instruction)
    return field(instruction, "opcode")
end

local function compute_instruction_tables(grammar, instructions)
    local context, body = grammar.context, grammar.body
    local lines = {}
    local index_by_opcode = {}
    for _, instruction in ipairs(sorted_by(instructions, opcode_of, less_number)) do
        local opname = field(instruction, "opname")
        local kinds = {}
        for _, operand in ipairs(list(instruction, "operands")) do
            table.insert(kinds, operand_kind(operand))
        end
        if opname == "OpExtInst" and kinds[#kinds] == "SPV_OPERAND_TYPE_VARIABLE_ID" then
            table.remove(kinds)
        end
        local has_result, has_type = false, false
        for _, kind in ipairs(kinds) do
            if kind == "SPV_OPERAND_TYPE_RESULT_ID" then
                has_result = true
            elseif kind == "SPV_OPERAND_TYPE_TYPE_ID" then
                has_type = true
            end
        end
        local aliases = {}
        for _, alias in ipairs(list(instruction, "aliases")) do
            table.insert(aliases, alias:sub(3))
        end
        local operands = add_string_list(context, "operand", kinds)
        local name_range = add_string(context, opname:sub(3))
        local alias_range = add_string_list(context, "alias", aliases)
        local capabilities = add_string_list(context, "capability", list(instruction, "capabilities"))
        local extensions = add_string_list(context, "extension", list(instruction, "extensions"))
        local parts = {"spv::Op::" .. opname, has_result and "true" or "false", has_type and "true" or "false",
                       range_text(operands), range_text(name_range), range_text(alias_range), range_text(capabilities),
                       range_text(extensions), min_version(field(instruction, "version")),
                       max_version(field(instruction, "lastVersion")),
                       "PrintingClass::" .. safe_identifier(field(instruction, "class") or "@exclude")}
        index_by_opcode[integer_text(opcode_of(instruction))] = #lines
        table.insert(lines, "{" .. join(parts, ", ") .. "},")
    end

    table.insert(body, "// Instruction descriptions, ordered by opcode.\n// The fields in order are:\n//   opcode\n//   a boolean indicating if the instruction produces a result ID\n//   a boolean indicating if the instruction result ID has a type\n//   operands, an IndexRange into kOperandSpans\n//   opcode name (without the 'Op' prefix), a character-counting IndexRange into kStrings\n//   aliases, an IndexRange into kAliasSpans\n//   capabilities, an IndexRange into kCapabilitySpans\n//   extensions, as an IndexRange into kExtensionSpans\n//   version, first version of SPIR-V that has it\n//   lastVersion, last version of SPIR-V that has it")
    table.insert(body, "static const std::array<InstructionDesc, " .. #lines .. "> kInstructionDesc{{")
    for _, line in ipairs(lines) do
        table.insert(body, "  " .. line)
    end
    table.insert(body, "}};\n")

    local pairs_by_name = {}
    for _, instruction in ipairs(instructions) do
        table.insert(pairs_by_name, {name = field(instruction, "opname"):sub(3), opcode = opcode_of(instruction)})
        for _, alias in ipairs(list(instruction, "aliases")) do
            table.insert(pairs_by_name, {name = alias:sub(3), opcode = opcode_of(instruction)})
        end
    end
    pairs_by_name = stable_sort(pairs_by_name, function (a, b)
        if a.name ~= b.name then
            return less_bytes(a.name, b.name)
        end
        return a.opcode < b.opcode
    end)
    local name_lines = {}
    for i, entry in ipairs(pairs_by_name) do
        local range = add_string(context, entry.name)
        local position = index_by_opcode[integer_text(entry.opcode)]
        table.insert(name_lines, "{" .. range_text(range) .. ", " .. position .. "}, // " .. (i - 1) .. " " .. entry.name)
    end
    table.insert(body, "// Opcode strings (without the 'Op' prefix) and opcode values, ordered by name.\n// The fields in order are:\n//   name, either the primary name or an alias, indexing into kStrings\n//   index into kInstructionDesc")
    table.insert(body, "static const std::array<NameIndex, " .. #name_lines .. "> kInstructionNames{{")
    for _, line in ipairs(name_lines) do
        table.insert(body, "  " .. line)
    end
    table.insert(body, "}};\n")
end

local function compute_extended_instructions(grammar, extinsts)
    local context, body = grammar.context, grammar.body
    local by_value = {}
    local by_value_by_kind = ordered_map()
    local index_by_kind_and_opcode = {}
    local index = 0
    for _, extinst in ipairs(extinsts) do
        local lines = {}
        for _, instruction in ipairs(sorted_by(list(extinst.grammar, "instructions"), opcode_of, less_number)) do
            local operands = {}
            for _, operand in ipairs(list(instruction, "operands")) do
                table.insert(operands, operand_kind(operand))
            end
            local opname = field(instruction, "opname")
            local operand_range = add_string_list(context, "operand", operands)
            local name_range = add_string(context, opname)
            local capabilities = add_string_list(context, "capability", list(instruction, "capabilities"))
            local parts = {integer_text(opcode_of(instruction)), range_text(operand_range), range_text(name_range),
                           range_text(capabilities)}
            table.insert(lines, "    {" .. join(parts, ",") .. "}, // " .. opname .. " in " .. extinst.name)
            index_by_kind_and_opcode[extinst.enum_name .. "\0" .. integer_text(opcode_of(instruction))] = index
            index = index + 1
        end
        ordered_set(by_value_by_kind, extinst.enum_name, index_range(#by_value, #lines))
        append(by_value, lines)
    end

    table.insert(body, "// Extended instruction descriptions, ordered by (extinst enum, opcode value).\n// The fields in order are:\n//   enum value\n//   operands, an IndexRange into kOperandSpans\n//   name, a character-counting IndexRange into kStrings\n//   capabilities, an IndexRange into kCapabilitySpans")
    table.insert(body, "static const std::array<ExtInstDesc, " .. #by_value .. "> kExtInstByValue{{")
    append(body, by_value)
    table.insert(body, "}};\n")

    table.insert(body, "IndexRange ExtInstByValueRangeForKind(spv_ext_inst_type_t type) {\n  switch(type) {")
    for _, name in ipairs(by_value_by_kind.keys) do
        table.insert(body, "    case " .. name .. ": return " .. range_text(by_value_by_kind.values[name]) .. ";")
    end
    table.insert(body, "    default: break;")
    table.insert(body, "  }\n  return IR(0,0);\n}\n")

    local by_name = {}
    local by_name_by_kind = ordered_map()
    for _, extinst in ipairs(extinsts) do
        local lines = {}
        local instructions = sorted_by(list(extinst.grammar, "instructions"), function (instruction) return field(instruction, "opname") end, less_bytes)
        for _, instruction in ipairs(instructions) do
            local opname = field(instruction, "opname")
            local position = index_by_kind_and_opcode[extinst.enum_name .. "\0" .. integer_text(opcode_of(instruction))]
            table.insert(lines, "    {" .. range_text(add_string(context, opname)) .. ", " .. position .. "}, // " .. opname .. " in " .. extinst.name)
        end
        ordered_set(by_name_by_kind, extinst.enum_name, index_range(#by_name, #lines))
        append(by_name, lines)
    end
    table.insert(body, "// Extended instruction opcode names sorted by extended instruction kind, then opcode name.\n// The fields in order are:\n//   name\n//   index into kExtInstByValue")
    table.insert(body, "static const std::array<NameIndex, " .. #by_name .. "> kExtInstNames{{")
    append(body, by_name)
    table.insert(body, "}};\n")

    table.insert(body, "IndexRange ExtInstNameRangeForKind(spv_ext_inst_type_t type) {\n  switch(type) {")
    for _, name in ipairs(by_name_by_kind.keys) do
        table.insert(body, "    case " .. name .. ": return " .. range_text(by_name_by_kind.values[name]) .. ";")
    end
    table.insert(body, "    default: break;")
    table.insert(body, "  }\n  return IR(0,0);\n}\n")
end

local function range_buffer(context, kind)
    local buffer = context.range_buffer[kind]
    if buffer == nil then
        raise("no %s ranges were recorded", kind)
    end
    return buffer
end

local function compute_leaf_tables(grammar)
    local context, body = grammar.context, grammar.body
    table.insert(body, "// Array of characters, referenced by IndexRanges elsewhere.")
    table.insert(body, "// Each IndexRange denotes a string.")
    table.insert(body, "static const char kStrings[] =")
    for _, s in ipairs(context.buffer) do
        table.insert(body, "  " .. c_string(s) .. " // " .. range_text(context.strings[s]))
    end
    table.insert(body, ";\n")

    table.insert(body, "// Array of IndexRanges, where each represents a string by referencing\n// the kStrings table.\n// This array contains all sequences of alias strings used in the grammar.\n// This table is referenced by an IndexRange elsewhere, i.e. by the 'aliases'\n// field of an instruction or operand description.")
    table.insert(body, "static const IndexRange kAliasSpans[] = {")
    for i, range in ipairs(range_buffer(context, "alias")) do
        table.insert(body, "  " .. range_text(range) .. ", // " .. (i - 1) .. " " .. get_string(context, range))
    end
    table.insert(body, "};\n")

    table.insert(body, "// Array of capabilities, referenced by IndexRanges elsewhere.")
    table.insert(body, "// Contains all sequences of capabilities used in the grammar.")
    table.insert(body, "static const spv::Capability kCapabilitySpans[] = {")
    for i, range in ipairs(range_buffer(context, "capability")) do
        table.insert(body, "  spv::Capability::" .. get_string(context, range) .. ", // " .. (i - 1))
    end
    table.insert(body, "};\n")

    table.insert(body, "// Array of extensions, referenced by IndexRanges elsewhere.")
    table.insert(body, "// Contains all sequences of extensions used in the grammar.")
    table.insert(body, "static const spvtools::Extension kExtensionSpans[] = {")
    for i, range in ipairs(range_buffer(context, "extension")) do
        table.insert(body, "  spvtools::Extension::k" .. get_string(context, range) .. ", // " .. (i - 1))
    end
    table.insert(body, "};\n")

    table.insert(body, "// Array of operand types, referenced by IndexRanges elsewhere.")
    table.insert(body, "// Contains all sequences of operand types used in the grammar.")
    table.insert(body, "static const spv_operand_type_t kOperandSpans[] = {")
    for i, range in ipairs(range_buffer(context, "operand")) do
        table.insert(body, "  " .. get_string(context, range) .. ", // " .. (i - 1))
    end
    table.insert(body, "};\n")
end

local function load_json(file)
    local data = io.readfile(file)
    if data == nil then
        raise("cannot read %s", file)
    end
    local object, errors = json.decode(data)
    if object == nil then
        raise("cannot decode %s: %s", file, errors or "")
    end
    return object
end

local function prefix_operand_kinds(prefix, grammar)
    local renamed = {}
    for _, kind in ipairs(list(grammar, "operand_kinds")) do
        local new_name = prefix .. kind.kind
        renamed[kind.kind] = new_name
        kind.kind = new_name
    end
    for _, instruction in ipairs(list(grammar, "instructions")) do
        for _, operand in ipairs(list(instruction, "operands")) do
            local replacement = renamed[operand.kind]
            if replacement ~= nil then
                operand.kind = replacement
            end
        end
    end
end

local function load_extinst(grammar_dir, spec)
    local file = path.join(grammar_dir, spec.file)
    local name = file:match(".*extinst%.(.*)%.grammar.json")
    if name == nil then
        raise("Invalid grammar file name: %s", file)
    end
    name = name:gsub("%-", "_"):gsub("%.", "_")
    local enum_name = ("SPV_EXT_INST_TYPE_" .. name):upper()
    if enum_name == "SPV_EXT_INST_TYPE_OPENCL_STD_100" then
        enum_name = "SPV_EXT_INST_TYPE_OPENCL_STD"
    end
    local grammar = load_json(file)
    if #spec.prefix > 0 then
        prefix_operand_kinds(spec.prefix, grammar)
    end
    return {prefix = spec.prefix, file = file, name = name, enum_name = enum_name, grammar = grammar}
end

local function extension_list(instructions, operand_kinds)
    local extensions = {}
    local present = {}
    local function add(extension)
        table.insert(extensions, extension)
        present[extension] = true
    end
    local carriers = {}
    append(carriers, instructions)
    for _, kind in ipairs(operand_kinds) do
        append(carriers, list(kind, "enumerants"))
    end
    for _, carrier in ipairs(carriers) do
        for _, extension in ipairs(list(carrier, "extensions")) do
            add(extension)
        end
    end
    for _, extension in ipairs(registry_extensions) do
        if present[extension] then
            raise("Extension %s is already in a grammar file", extension)
        end
    end
    for _, extension in ipairs(registry_extensions) do
        add(extension)
    end
    add("SPV_VALIDATOR_ignore_type_decl_unique")
    local unique = {}
    local seen = {}
    for _, extension in ipairs(extensions) do
        if not seen[extension] then
            seen[extension] = true
            table.insert(unique, extension)
        end
    end
    return stable_sort(unique, less_bytes)
end

function core_tables(grammar_dir)
    local extinsts = {}
    for _, spec in ipairs(extinst_specs) do
        table.insert(extinsts, load_extinst(grammar_dir, spec))
    end
    extinsts = sorted_by(extinsts, function (extinst) return extinst.name end, less_bytes)
    local core = load_json(path.join(grammar_dir, "spirv.core.grammar.json"))
    local printing_classes = {}
    for _, class in ipairs(list(core, "instruction_printing_class")) do
        table.insert(printing_classes, field(class, "tag"))
    end
    local instructions = {}
    local operand_kinds = {}
    append(instructions, list(core, "instructions"))
    append(operand_kinds, list(core, "operand_kinds"))
    for _, extinst in ipairs(extinsts) do
        append(instructions, list(extinst.grammar, "instructions"))
        append(operand_kinds, list(extinst.grammar, "operand_kinds"))
    end
    local grammar = new_grammar(extension_list(instructions, operand_kinds), operand_kinds, printing_classes)
    compute_operand_tables(grammar)
    compute_instruction_tables(grammar, list(core, "instructions"))
    compute_extended_instructions(grammar, extinsts)
    compute_leaf_tables(grammar)
    return join(grammar.body, "\n"), join(grammar.header, "\n")
end

local function truthy(value)
    if value == nil or value == false then
        return false
    elseif type(value) == "number" then
        return value ~= 0
    elseif type(value) == "string" then
        return #value > 0
    elseif type(value) == "table" then
        return #value > 0
    end
    return true
end

local function enum_value(prefix, name, value)
    local use_name = name:match("^[A-Z]") and name or ("_" .. name)
    return "    " .. prefix .. use_name .. " = " .. text(value) .. ","
end

local function enum_end(prefix, enum)
    return "    " .. prefix .. enum .. "Max = 0x7ffffff\n};\n"
end

local function const_definition(prefix, var, value)
    return "enum { " .. prefix .. var .. " = " .. text(value) .. ", " .. prefix .. var .. "_BitWidthPadding = 0x7fffffff };"
end

function language_header(grammar_file, name)
    local grammar = load_json(grammar_file)
    local function required(key)
        if grammar[key] == nil then
            raise("%s has no %s", grammar_file, key)
        end
        return field(grammar, key)
    end
    local copyright = required("copyright")
    local instructions = required("instructions")
    local operand_kinds = required("operand_kinds")
    local version = required("version")
    local revision = required("revision")
    local parts = {}
    if truthy(copyright) then
        for _, line in ipairs(copyright) do
            table.insert(parts, "// " .. line)
        end
    end
    table.insert(parts, "")
    local guard = "SPIRV_EXTINST_" .. name .. "_H_"
    table.insert(parts, "#ifndef " .. guard)
    table.insert(parts, "#define " .. guard)
    table.insert(parts, "")
    table.insert(parts, '#ifdef __cplusplus\nextern "C" {\n#endif\n')
    if truthy(version) then
        table.insert(parts, const_definition(name, "Version", version))
    end
    if revision ~= nil then
        table.insert(parts, const_definition(name, "Revision", revision))
    end
    table.insert(parts, "")
    if truthy(instructions) then
        table.insert(parts, "enum " .. name .. "Instructions {")
        for _, instruction in ipairs(instructions) do
            table.insert(parts, enum_value(name, instruction.opname, instruction.opcode))
        end
        table.insert(parts, enum_end(name, "Instructions"))
        table.insert(parts, "")
    end
    if truthy(operand_kinds) then
        for _, kind in ipairs(operand_kinds) do
            if kind.enumerants == nil then
                raise("%s: operand kind %s has no enumerants", grammar_file, kind.kind)
            end
            table.insert(parts, "enum " .. name .. kind.kind .. " {")
            for _, enumerant in ipairs(kind.enumerants) do
                table.insert(parts, enum_value(name, enumerant.enumerant, enumerant.value))
            end
            table.insert(parts, enum_end(name, kind.kind))
        end
        table.insert(parts, "")
    end
    table.insert(parts, "#ifdef __cplusplus\n}\n#endif\n")
    table.insert(parts, "#endif // " .. guard)
    return join(parts, "\n")
end

local function decode_entities(value)
    return (value:gsub("&(#?[%w]+);", function (entity)
        local codepoint
        if entity:startswith("#x") or entity:startswith("#X") then
            codepoint = tonumber(entity:sub(3), 16)
        elseif entity:startswith("#") then
            codepoint = tonumber(entity:sub(2), 10)
        else
            local named = {lt = "<", gt = ">", amp = "&", quot = '"', apos = "'"}
            if named[entity] == nil then
                raise("unknown XML entity &%s;", entity)
            end
            return named[entity]
        end
        if codepoint == nil then
            raise("invalid XML character reference &%s;", entity)
        end
        if codepoint < 0x80 then
            return string.char(codepoint)
        elseif codepoint < 0x800 then
            return string.char(0xc0 + math.floor(codepoint / 0x40), 0x80 + codepoint % 0x40)
        elseif codepoint < 0x10000 then
            return string.char(0xe0 + math.floor(codepoint / 0x1000), 0x80 + math.floor(codepoint / 0x40) % 0x40, 0x80 + codepoint % 0x40)
        end
        return string.char(0xf0 + math.floor(codepoint / 0x40000), 0x80 + math.floor(codepoint / 0x1000) % 0x40,
                           0x80 + math.floor(codepoint / 0x40) % 0x40, 0x80 + codepoint % 0x40)
    end))
end

local function parse_tag(xml, position)
    local name, after = xml:match("^<([%w_:%.%-]+)()", position)
    if name == nil then
        return nil
    end
    local attributes = {}
    local i = after
    while true do
        i = xml:match("^%s*()", i)
        if xml:sub(i, i + 1) == "/>" then
            return {name = name, attributes = attributes, empty = true, finish = i + 2}
        elseif xml:sub(i, i) == ">" then
            return {name = name, attributes = attributes, empty = false, finish = i + 1}
        end
        local key, quote, value_start = xml:match("^([%w_:%.%-]+)%s*=%s*(['\"])()", i)
        if key == nil then
            raise("malformed XML tag at byte %d", position)
        end
        local closing = xml:find(quote, value_start, true)
        if closing == nil then
            raise("unterminated XML attribute at byte %d", value_start)
        end
        local raw = xml:sub(value_start, closing - 1):gsub("[\t\n]", " ")
        attributes[key] = decode_entities(raw)
        i = closing + 1
    end
end

function generators_table(xml_file)
    local xml = io.readfile(xml_file)
    if xml == nil then
        raise("cannot read %s", xml_file)
    end
    xml = xml:gsub("\r\n?", "\n"):gsub("<!%-%-.-%-%->", "")
    local lines = {}
    local depth = 0
    local in_vendor = false
    local position = 1
    while true do
        local start = xml:find("<", position, true)
        if start == nil then
            break
        end
        local next_char = xml:sub(start + 1, start + 1)
        if next_char == "/" then
            local name, finish = xml:match("^</([%w_:%.%-]+)%s*>()", start)
            if name == nil then
                raise("malformed XML end tag at byte %d", start)
            end
            depth = depth - 1
            if in_vendor and name == "ids" and depth == in_vendor then
                in_vendor = false
            end
            position = finish
        elseif xml:sub(start, start + 8) == "<![CDATA[" then
            local finish = xml:find("]]>", start, true)
            if finish == nil then
                raise("unterminated CDATA section at byte %d", start)
            end
            position = finish + 3
        elseif next_char == "?" or next_char == "!" then
            local finish = xml:find(">", start, true)
            if finish == nil then
                raise("unterminated XML declaration at byte %d", start)
            end
            position = finish + 1
        else
            local tag = parse_tag(xml, start)
            if tag.name == "ids" and not in_vendor then
                if tag.attributes.type == nil then
                    raise("an ids element has no type")
                end
                if tag.attributes.type == "vendor" and not tag.empty then
                    in_vendor = depth
                end
            elseif tag.name == "id" and in_vendor then
                local value = tag.attributes.value
                local vendor = tag.attributes.vendor
                if value == nil or vendor == nil then
                    raise("an id element lacks value or vendor")
                end
                local tool = tag.attributes.tool or ""
                local vendor_tool = tag.attributes.tool and (vendor .. " " .. tool) or vendor
                table.insert(lines, "{" .. value .. ', "' .. vendor .. '", "' .. tool .. '", "' .. vendor_tool .. '"},')
            end
            if not tag.empty then
                depth = depth + 1
            end
            position = tag.finish
        end
    end
    return join(lines, "\n")
end

local function git_output(directory, argv)
    local output
    local ok = try {
        function ()
            output = os.iorunv("git", argv, {curdir = directory})
            return true
        end
    }
    if ok then
        return output
    end
end

local function describe(directory)
    if git_output(directory, {"rev-parse", "--show-toplevel"}) ~= nil then
        local output = git_output(directory, {"describe", "--tags", "--match=v*", "--long"})
        if output == nil then
            output = git_output(directory, {"rev-parse", "HEAD"})
        end
        if output ~= nil then
            return (output:gsub("%s+$", ""))
        end
    end
    local epoch = os.getenv("SOURCE_DATE_EPOCH")
    local timestamp = epoch and math.floor(tonumber(epoch)) or os.time()
    return "unknown hash, " .. os.date("!%Y-%m-%dT%H:%M:%S", timestamp) .. "+00:00"
end

function build_version(changes_file)
    changes_file = path.absolute(changes_file)
    local changes = io.readfile(changes_file)
    if changes == nil then
        raise("cannot read %s", changes_file)
    end
    changes = changes:gsub("\r\n?", "\n")
    local version
    for line in (changes .. "\n"):gmatch("(.-)\n") do
        version = line:match("^(v%d+%.%d+%-dev) %d%d%d%d%-%d%d%-%d%d%s*$") or line:match("^(v%d+%.%d+) %d%d%d%d%-%d%d%-%d%d%s*$")
        if version then
            break
        end
    end
    if version == nil then
        raise("Could not deduce latest release version from %s.", changes_file)
    end
    local description = os.getenv("FORCED_BUILD_VERSION_DESCRIPTION") or describe(path.directory(changes_file))
    return '"' .. version .. '", "SPIRV-Tools ' .. version .. " " .. description .. '"\n'
end

local function write(file, content)
    if os.isfile(file) and io.readfile(file) == content then
        return
    end
    io.writefile(file, content)
end

function main(opt)
    local grammar_dir = path.join(opt.headers, "unified1")
    os.mkdir(opt.outputdir)
    local body, header = core_tables(grammar_dir)
    write(path.join(opt.outputdir, "core_tables_body.inc"), body)
    write(path.join(opt.outputdir, "core_tables_header.inc"), header)
    for _, entry in ipairs(language_headers) do
        write(path.join(opt.outputdir, entry.name .. ".h"), language_header(path.join(grammar_dir, entry.file), entry.name))
    end
    write(path.join(opt.outputdir, "generators.inc"), generators_table(path.join(opt.headers, "spir-v.xml")))
    write(path.join(opt.outputdir, "build-version.inc"), build_version(path.join(opt.tools, "CHANGES")))
end
