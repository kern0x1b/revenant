local limits = import("air2es_limits", {rootdir = os.scriptdir()})
local json = import("core.base.json")

local BYTES = {float = 4, i32 = 4, half = 2, i16 = 2, i8 = 1}
local SPECIAL = {revenant_flip = true, revenant_target = true, revenant_instance = true}

local function shape(glsl)
    if glsl == "float" then
        return "float", 1
    end
    if glsl == "int" then
        return "int", 1
    end
    local vector = glsl:match("^vec([234])$")
    if vector then
        return "float", tonumber(vector)
    end
    local integers = glsl:match("^ivec([234])$")
    if integers then
        return "int", tonumber(integers)
    end
    return nil, nil
end

local function compatible(glsl, scalar, components, attribute, columns)
    if columns then
        return not attribute and scalar == "float" and glsl == string.format("mat%d", columns) and components == columns
    end
    local kind, count = shape(glsl)
    if not kind or count ~= components then
        return false
    end
    if kind == "float" then
        if attribute then
            return scalar == "float" or scalar == "i8"
        end
        return scalar == "float" or scalar == "half"
    end
    return scalar == "i8" or scalar == "i16" or scalar == "i32"
end

local function declarations(source)
    local found = {}
    for line in (source .. "\n"):gmatch("(.-)\n") do
        local qualifier, glsl, name = line:match("^(%a+)%s+(%S+)%s+([%a_][%w_]*);$")
        if qualifier then
            table.insert(found, {qualifier = qualifier, glsl = glsl, name = name})
        end
    end
    return found
end

local function isInteger(value)
    return type(value) == "number" and value == math.floor(value)
end

local function isComponents(value)
    return isInteger(value) and value >= 1 and value <= 4
end

local function listOf(reflection, key, fail)
    local list = reflection[key]
    if type(list) ~= "table" then
        fail("reflection has no " .. key .. " array")
        return {}
    end
    return list
end

local function reflectionProblems(stage, source, reflection)
    local problems = {}
    local function fail(text)
        table.insert(problems, text)
    end
    local declared = {}
    for _, item in ipairs(declarations(source)) do
        declared[item.name] = item
    end
    local sizes = {}
    local seen = {}
    local uniforms = listOf(reflection, "uniforms", fail)
    for _, entry in ipairs(uniforms) do
        if type(entry.name) ~= "string" or not isInteger(entry.buffer) or not isInteger(entry.offset) or
           not isInteger(entry.instanceStride) or not BYTES[entry.scalar] or not isComponents(entry.components) or
           (entry.columns ~= nil and (not isComponents(entry.columns) or entry.columns < 2 or entry.columns ~= entry.components)) then
            fail("a uniform entry with a missing or malformed field")
        else
            local item = declared[entry.name]
            if not item or item.qualifier ~= "uniform" then
                fail("uniform " .. entry.name .. " is reflected but not declared in the source")
            elseif not compatible(item.glsl, entry.scalar, entry.components, false, entry.columns) then
                fail("uniform " .. entry.name .. " is declared " .. item.glsl .. " but reflected as " ..
                     entry.scalar .. " x" .. entry.components .. (entry.columns and (" columns " .. entry.columns) or ""))
            end
            seen[entry.name] = true
        end
    end
    local textureByIndex, textureNamed = {}, {}
    if stage == "vertex" then
        if type(reflection.usesVertexId) ~= "boolean" then
            fail("usesVertexId is not a boolean")
        elseif reflection.usesVertexId ~= (declared.a_vertex_id ~= nil) then
            fail("usesVertexId disagrees with the source's use of a_vertex_id")
        end
        local attributes = listOf(reflection, "attributes", fail)
        local named = {}
        for _, entry in ipairs(attributes) do
            if type(entry.name) ~= "string" or not isInteger(entry.buffer) or not isInteger(entry.offset) or
               not isInteger(entry.stride) or not isComponents(entry.components) or
               (entry.scalar ~= "float" and entry.scalar ~= "i8") then
                fail("an attribute entry with a missing or malformed field")
            else
                local item = declared[entry.name]
                if not item or item.qualifier ~= "attribute" then
                    fail("attribute " .. entry.name .. " is reflected but not declared in the source")
                elseif not compatible(item.glsl, entry.scalar, entry.components, true) then
                    fail("attribute " .. entry.name .. " is declared " .. item.glsl .. " but reflected as " ..
                         entry.scalar .. " x" .. entry.components)
                end
                if entry.stride < entry.offset + entry.components * BYTES[entry.scalar] then
                    fail("attribute " .. entry.name .. " reads past its stride")
                end
                named[entry.name] = true
            end
        end
        for _, item in ipairs(declarations(source)) do
            if item.qualifier == "attribute" and item.name ~= "a_vertex_id" and not named[item.name] then
                fail("attribute " .. item.name .. " is declared but missing from reflection")
            end
        end
        listOf(reflection, "inputs", fail)
        if not source:find("gl_Position =", 1, true) then
            fail("a vertex function that writes no gl_Position")
        end
    else
        for _, entry in ipairs(listOf(reflection, "textures", fail)) do
            if type(entry.name) ~= "string" or not isInteger(entry.index) or entry.depth ~= false or entry.compare ~= false then
                fail("a texture entry with a missing or malformed field")
            else
                local item = declared[entry.name]
                local expected = entry.cube == true and "samplerCube" or "sampler2D"
                if not item or item.glsl ~= expected then
                    fail("texture " .. entry.name .. " is reflected but not declared as " .. expected)
                end
                textureByIndex[entry.index] = entry.name
                textureNamed[entry.name] = true
            end
        end
        for _, item in ipairs(declarations(source)) do
            if (item.glsl == "sampler2D" or item.glsl == "samplerCube") and not textureNamed[item.name] then
                fail("sampler " .. item.name .. " is declared but missing from reflection")
            end
        end
        for _, entry in ipairs(listOf(reflection, "sizes", fail)) do
            local item = type(entry.name) == "string" and declared[entry.name]
            local output = entry.output == true and type(reflection.outputTexture) == "table" and entry.texture == reflection.outputTexture.index
            if not item or item.glsl ~= "vec2" or not isInteger(entry.texture) or not (output or textureByIndex[entry.texture]) then
                fail("a size entry that names no declared vec2 or an unknown texture")
            else
                sizes[entry.name] = true
            end
        end
        local outputs = listOf(reflection, "outputs", fail)
        if stage == "kernel" then
            if type(reflection.outputTexture) ~= "table" then
                fail("a kernel with no outputTexture")
            end
        elseif #outputs == 0 then
            fail("a fragment function with no outputs")
        end
        for _, output in ipairs(outputs) do
            if not isInteger(output) then
                fail("an output index that is not an integer")
            end
        end
        if not source:find("gl_FragColor =", 1, true) then
            fail("a fragment function that writes no gl_FragColor")
        end
        listOf(reflection, "fetches", fail)
    end
    for _, item in ipairs(declarations(source)) do
        local special = SPECIAL[item.name] or sizes[item.name] or item.glsl == "sampler2D" or item.glsl == "samplerCube" or item.qualifier ~= "uniform"
        if not special and not seen[item.name] then
            fail("uniform " .. item.name .. " is declared but missing from reflection")
        end
    end
    return problems
end

local function decodeFile(file)
    if not os.isfile(file) then
        raise("missing file: " .. file)
    end
    local value, failure
    try {
        function ()
            value = json.decode(io.readfile(file))
        end,
        catch {
            function (errors)
                failure = tostring(errors)
            end
        }
    }
    if failure or type(value) ~= "table" then
        raise("not a JSON object: " .. file .. (failure and (": " .. failure) or ""))
    end
    return value
end

local function run(program, arguments)
    local failure
    try {
        function ()
            os.execv(program, arguments)
        end,
        catch {
            function (errors)
                failure = tostring(errors)
            end
        }
    }
    return failure
end

function main(folder, glslang)
    assert(folder and os.isdir(folder), "usage: air2es_check.lua FOLDER [GLSLANG]")
    glslang = glslang or "glslangValidator"
    local manifest = decodeFile(path.join(folder, "library.json"))
    local functions = manifest.functions
    assert(type(functions) == "table", "library.json has no functions array")
    local structural, validated, total = 0, 0, #functions
    local names = {}
    for _, entry in ipairs(functions) do
        local problems = {}
        local label = tostring(entry.name) .. " (" .. tostring(entry.stage) .. ")"
        local valid = type(entry.name) == "string" and not names[entry.name] and
            (entry.stage == "vertex" or entry.stage == "fragment" or entry.stage == "kernel")
        if not valid then
            table.insert(problems, "a function entry with a bad or repeated name or stage")
        else
            names[entry.name] = true
        end
        local source, reflectionFile
        for _, key in ipairs({"source", "reflection"}) do
            local file = entry[key]
            if type(file) ~= "string" or file:find("/", 1, true) or not os.isfile(path.join(folder, file)) then
                table.insert(problems, key .. " is not a file in the folder")
            elseif key == "source" then
                source = io.readfile(path.join(folder, file))
            else
                reflectionFile = path.join(folder, file)
            end
        end
        if source and reflectionFile then
            local reflection = decodeFile(reflectionFile)
            if not source:find("#version 100", 1, true) then
                table.insert(problems, "the source is not GLSL ES 1.00")
            end
            for _, text in ipairs(reflectionProblems(entry.stage, source, reflection)) do
                table.insert(problems, text)
            end
            local reason = limits.check(source)
            if reason then
                table.insert(problems, reason)
            end
        end
        if #problems == 0 then
            structural = structural + 1
            local file = path.join(folder, entry.source)
            local failure = run(glslang, {"-S", entry.stage == "vertex" and "vert" or "frag", file})
            if failure then
                print("FAIL " .. label .. ": " .. glslang .. " did not validate the source: " .. failure)
            else
                validated = validated + 1
                print("PASS " .. label)
            end
        else
            print("FAIL " .. label .. ": " .. table.concat(problems, "; "))
        end
    end
    print(string.format("air2es_check: %d of %d functions pass the structure, reflection and Appendix A checks", structural, total))
    print(string.format("air2es_check: %d of %d functions translated and validated", validated, total))
    if validated ~= total then
        raise("air2es_check: " .. (total - validated) .. " function(s) failed")
    end
end
