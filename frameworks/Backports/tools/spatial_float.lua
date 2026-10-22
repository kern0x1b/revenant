local TWINS = {"SpatialFoundation", "SpatialGeometry", "SpatialMatrix", "SpatialProtocol", "SpatialTransform"}
local SHARED = "SpatialScalarIndependent"

local CONFORMANCE = {
    ["Primitive3D, Primitive3DProtocol, Translatable3DProtocol, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable"] =
        "Primitive3DProtocolFloat, Translatable3DProtocolFloat, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable",
    ["Primitive3D, Rotatable3D, Primitive3DProtocol, AdditiveArithmetic, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable"] =
        "Primitive3DProtocolFloat, AdditiveArithmetic, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable",
    ["Primitive3D, Translatable3D, Primitive3DProtocol, ClampableWithinRectProtocol, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable"] =
        "Primitive3DProtocolFloat, Translatable3DProtocolFloat, ClampableWithinRectProtocolFloat, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable",
    ["Primitive3D, Translatable3D, Volumetric, Primitive3DProtocol, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable"] =
        "Primitive3DProtocolFloat, Translatable3DProtocolFloat, VolumetricProtocolFloat, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable",
    ["Primitive3D, Volumetric, Primitive3DProtocol, AdditiveArithmetic, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable"] =
        "Primitive3DProtocolFloat, AdditiveArithmetic, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable",
    ["Rotatable3D, Rotatable3DProtocol, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable"] =
        "Rotatable3DProtocolFloat, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable",
    ["Rotatable3D, Translatable3D, Rotatable3DProtocol, Translatable3DProtocol, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable"] =
        "Rotatable3DProtocolFloat, Translatable3DProtocolFloat, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable",
    ["Transform3DProtocol, Shearable3D, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable"] =
        "Transform3DProtocolFloat, Hashable, Codable, CustomStringConvertible, CustomReflectable, Sendable",
}

local EXPLICIT = {defaultTolerance = "defaultToleranceFloat"}

local function lines(text)
    local out = {}
    for line in text:gmatch("([^\n]*)\n") do
        out[#out + 1] = line
    end
    return out
end

local function renamer(names)
    return function (token)
        if token == "Double" then
            return "Float"
        elseif token == "simd_quatd" then
            return "simd_quatf"
        elseif token:sub(1, 5) == "simd_" then
            return (token:gsub("double", "float"))
        elseif EXPLICIT[token] then
            return EXPLICIT[token]
        elseif names[token] then
            return token .. "Float"
        end
        return token
    end
end

local function identifiers(text, rename)
    local darwin = text:gsub("Darwin%.([%a_][%w_]*)", "Darwin.%1f")
    return (darwin:gsub("[%a_][%w_]*", rename))
end

local function code(text, rename)
    local out = {}
    local outside = true
    local rest = text
    while true do
        local before, after = rest:match('^(.-)"(.*)$')
        if not before then
            out[#out + 1] = outside and identifiers(rest, rename) or rest
            break
        end
        out[#out + 1] = outside and identifiers(before, rename) or before
        out[#out + 1] = '"'
        rest = after
        outside = not outside
    end
    return table.concat(out)
end

local function derive_line(line, rename, unparameterised)
    local head, kind, rest = line:match("^(public (%a+) [^:]-: )(.*)$")
    if kind ~= "struct" and kind ~= "enum" and kind ~= "protocol" then
        return code(line, rename)
    end
    local list, tail = rest:match("^(.-)( {.*)$")
    assert(list, "spatial: a conformance list without its body: " .. line)
    local float_list = CONFORMANCE[list]
    if float_list then
        return code(head, rename) .. float_list .. code(tail, rename)
    end
    for item in (list .. ","):gmatch("%s*([^,]-)%s*,") do
        assert(not unparameterised[item], "spatial: no Float conformance list for " .. list)
    end
    return code(head, rename) .. code(list, rename) .. code(tail, rename)
end

function generate(folder, output)
    local names, unparameterised = {}, {}
    local sources = {}
    for _, name in ipairs(TWINS) do
        local text = io.readfile(path.join(folder, name .. ".swift"), {encoding = "binary"})
        sources[#sources + 1] = {name = name, text = text}
        for kind, declared in text:gmatch("public (%a+) ([%w_]+)") do
            if kind == "struct" or kind == "enum" or kind == "protocol" then
                names[declared] = true
            end
        end
    end
    local shared = io.readfile(path.join(folder, SHARED .. ".swift"), {encoding = "binary"})
    for kind, declared in shared:gmatch("public (%a+) ([%w_]+)") do
        if kind == "protocol" and not names[declared] then
            unparameterised[declared] = true
        end
    end
    local rename = renamer(names)
    local files = {}
    for _, source in ipairs(sources) do
        local out = {}
        for _, line in ipairs(lines(source.text)) do
            out[#out + 1] = derive_line(line, rename, unparameterised)
        end
        local file = path.join(output, source.name .. "Float.swift")
        io.writefile(file, table.concat(out, "\n") .. "\n", {encoding = "binary"})
        files[#files + 1] = file
    end
    return files
end
