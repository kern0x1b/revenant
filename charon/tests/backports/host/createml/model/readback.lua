-- readback.lua: reads a Core ML `.mlmodel` and prints the one line the model suite checks. It replaces
-- the two python scripts the suite ran through /usr/bin/python3 (coremltools 9.0), so the suite no
-- longer runs python. The fields, their order, their separators and their number formats are the ones
-- those scripts printed, and the suite's expectations are unchanged: they are the committed output of
-- coremltools, and this reader must print the same strings for the same file.
--
-- The decoder is the protobuf wire format over the field numbers in packages/c/createml/proto/
-- (Model.proto, NeuralNetwork.proto, FeatureTypes.proto). It reads the fields the line prints and
-- nothing else; a message the file carries that the line does not name is skipped, not parsed.
--     xmake l tests/backports/host/createml/model/readback.lua <file.mlmodel>
-- Output, one line:
--     specificationVersion|Type|inputs|outputs|shape|dataType|inputChannels|outputChannels|hasBias|weights|bias
-- with inputs and outputs comma-joined names, shape comma-joined integers, and weights and bias
-- comma-joined floats rounded to six places, as coremltools' `round(v, 6)` printed them.

-- The varint at `pos`, and the position after it.
local function varint(bytes, pos)
    local value, scale = 0, 1
    repeat
        local b = bytes:byte(pos)
        if not b then error("truncated varint at byte " .. pos) end
        pos = pos + 1
        value = value + (b % 128) * scale
        scale = scale * 128
    until b < 128
    return value, pos
end

-- `n` bytes at `pos`, and the position after them; a message that ends early is an error, not a short
-- field.
local function take(bytes, pos, n)
    if pos + n - 1 > #bytes then error("truncated field at byte " .. pos) end
    return bytes:sub(pos, pos + n - 1), pos + n
end

-- The entries of one message: each field's number, its wire type and its value. A varint is a number,
-- a length-delimited field is its bytes, and a fixed 32 or 64 is its bytes.
local function decode(bytes)
    local entries, pos = {}, 1
    while pos <= #bytes do
        local key
        key, pos = varint(bytes, pos)
        local number, wire = math.floor(key / 8), key % 8
        local value
        if wire == 0 then
            value, pos = varint(bytes, pos)
        elseif wire == 1 then
            value, pos = take(bytes, pos, 8)
        elseif wire == 2 then
            local length
            length, pos = varint(bytes, pos)
            value, pos = take(bytes, pos, length)
        elseif wire == 5 then
            value, pos = take(bytes, pos, 4)
        else
            error("wire type " .. wire .. " at byte " .. pos)
        end
        entries[#entries + 1] = { number = number, wire = wire, value = value }
    end
    return entries
end

-- The last value of a singular varint field, or `default` when the message does not carry it.
local function scalar(entries, number, default)
    local found = default
    for _, e in ipairs(entries) do
        if e.number == number and e.wire == 0 then found = e.value end
    end
    return found
end

-- The bytes of each length-delimited field with the number, in order: a repeated message, or a string.
local function submessages(entries, number)
    local out = {}
    for _, e in ipairs(entries) do
        if e.number == number and e.wire == 2 then out[#out + 1] = e.value end
    end
    return out
end

-- A repeated int64 field, packed or not, as numbers in order.
local function integers(entries, number)
    local out = {}
    for _, e in ipairs(entries) do
        if e.number == number then
            if e.wire == 0 then
                out[#out + 1] = e.value
            elseif e.wire == 2 then
                local pos = 1
                while pos <= #e.value do
                    local v
                    v, pos = varint(e.value, pos)
                    out[#out + 1] = v
                end
            end
        end
    end
    return out
end

-- An IEEE 754 single from four little-endian bytes.
local function float32(s)
    local b1, b2, b3, b4 = s:byte(1, 4)
    local bits = ((b4 * 256 + b3) * 256 + b2) * 256 + b1
    local sign = bits >= 2147483648 and -1 or 1
    local exponent = math.floor(bits / 8388608) % 256
    local mantissa = bits % 8388608
    local value
    if exponent == 0 then
        value = mantissa * 2 ^ -149
    else
        value = (1 + mantissa / 8388608) * 2 ^ (exponent - 127)
    end
    return sign * value
end

-- A repeated float field, packed or not, as numbers in order.
local function floats(entries, number)
    local out = {}
    for _, e in ipairs(entries) do
        if e.number == number then
            if e.wire == 5 then
                out[#out + 1] = float32(e.value)
            elseif e.wire == 2 then
                for pos = 1, #e.value, 4 do
                    out[#out + 1] = float32(e.value:sub(pos, pos + 3))
                end
            end
        end
    end
    return out
end

-- Python's str() of a float: the shortest form that reads back as the same value, with a point.
local function pyfloat(v)
    local s
    for digits = 1, 17 do
        s = string.format("%." .. digits .. "g", v)
        if tonumber(s) == v then break end
    end
    if not s:find("[%.eEn]") then s = s .. ".0" end
    return s
end

-- round(v, 6), then str().
local function rounded(v)
    local sign = v < 0 and -1 or 1
    return pyfloat(sign * math.floor(math.abs(v) * 1000000 + 0.5) / 1000000)
end

-- The names of a repeated FeatureDescription, joined with commas.
local function names(features)
    local out = {}
    for _, feature in ipairs(features) do
        out[#out + 1] = submessages(decode(feature), 1)[1] or ""
    end
    return table.concat(out, ",")
end

-- The fields of the Model's `Type` oneof, with the names Model.proto gives them: python's WhichOneof
-- answered with the name of the one that is set.
local MODEL_TYPE = {
    [200] = "pipelineClassifier", [201] = "pipelineRegressor", [202] = "pipeline",
    [300] = "glmRegressor", [301] = "supportVectorRegressor", [302] = "treeEnsembleRegressor",
    [303] = "neuralNetworkRegressor", [304] = "bayesianProbitRegressor",
    [400] = "glmClassifier", [401] = "supportVectorClassifier", [402] = "treeEnsembleClassifier",
    [403] = "neuralNetworkClassifier", [404] = "kNearestNeighborsClassifier",
    [500] = "neuralNetwork", [501] = "itemSimilarityRecommender", [502] = "mlProgram",
    [555] = "customModel", [556] = "linkedModel", [560] = "classConfidenceThresholding",
    [600] = "oneHotEncoder", [601] = "imputer", [602] = "featureVectorizer", [603] = "dictVectorizer",
    [604] = "scaler", [606] = "categoricalMapping", [607] = "normalizer",
    [609] = "arrayFeatureExtractor", [610] = "nonMaximumSuppression", [900] = "identity",
    [2000] = "textClassifier", [2001] = "wordTagger", [2002] = "visionFeaturePrint",
    [2003] = "soundAnalysisPreprocessing", [2004] = "gazetteer", [2005] = "wordEmbedding",
    [2006] = "audioFeaturePrint", [3000] = "serializedModel",
}

local function readModel(bytes)
    local model = decode(bytes)
    local description = decode(submessages(model, 2)[1] or "")
    local inputs = submessages(description, 1)
    local outputs = submessages(description, 10)

    -- python's WhichOneof answers None for an unset oneof.
    local typeName = "None"
    for number, name in pairs(MODEL_TYPE) do
        if #submessages(model, number) > 0 then typeName = name end
    end

    -- The first input's type (FeatureDescription field 3) is a FeatureType, and its multiArrayType
    -- (field 5) an ArrayFeatureType.
    local inputFeature = decode(inputs[1] or "")
    local inputType = decode(submessages(inputFeature, 3)[1] or "")
    local array = decode(submessages(inputType, 5)[1] or "")
    local shape = {}
    for _, d in ipairs(integers(array, 1)) do shape[#shape + 1] = string.format("%d", d) end

    local network = decode(submessages(model, 303)[1] or "")
    local layer = decode(submessages(network, 1)[1] or "")
    local inner = decode(submessages(layer, 140)[1] or "")
    local weights = decode(submessages(inner, 20)[1] or "")
    local bias = decode(submessages(inner, 21)[1] or "")

    local weightValues, biasValues = {}, {}
    for _, v in ipairs(floats(weights, 1)) do weightValues[#weightValues + 1] = rounded(v) end
    for _, v in ipairs(floats(bias, 1)) do biasValues[#biasValues + 1] = rounded(v) end

    return table.concat({
        string.format("%d", scalar(model, 1, 0)),
        typeName,
        names(inputs),
        names(outputs),
        table.concat(shape, ","),
        string.format("%d", scalar(array, 2, 0)),
        string.format("%d", scalar(inner, 1, 0)),
        string.format("%d", scalar(inner, 2, 0)),
        scalar(inner, 10, 0) ~= 0 and "True" or "False",
        table.concat(weightValues, ","),
        table.concat(biasValues, ","),
    }, "|")
end

function main(path)
    local bytes = io.readfile(path, { encoding = "binary" })
    print(readModel(bytes))
end
