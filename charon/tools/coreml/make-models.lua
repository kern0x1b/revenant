import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})
local proto = import("proto", {rootdir = os.scriptdir()})

local FLOAT32 = 65568
local DOUBLE = 65600
local INT32 = 131104

local SPEC_11_2, SPEC_12_0, SPEC_12_2, SPEC_13_0 = 3, 4, 5, 6
local SPEC_1 = 1

local function f32(value)
    return (string.unpack("<f", string.pack("<f", value)))
end

local function array(shape, data_type)
    return {shape = shape, dataType = data_type or FLOAT32}
end

local function vector(name, shape, data_type)
    return {name = name, type = {multiArrayType = array(shape, data_type)}}
end

local function scalar_double(name)
    return {name = name, type = {doubleType = {}}}
end

local function label(name)
    return {name = name, type = {stringType = {}}}
end

local function probabilities(name)
    return {name = name, type = {dictionaryType = {stringKeyType = {}}}}
end

local function image(name, width, height)
    return {name = name, type = {imageType = {width = width, height = height, colorSpace = 20}}}
end

local function description(inputs, outputs, predicted, probabilities_name)
    local out = {input = inputs, output = outputs}
    if predicted ~= nil then
        out.predictedFeatureName = predicted
        out.predictedProbabilitiesName = probabilities_name
    end
    return out
end

local function class_labels(spec, classifier, labels, name)
    name = name or "classLabel"
    classifier.stringClassLabels = {vector = labels}
    spec.description.predictedFeatureName = name
    spec.description.predictedProbabilitiesName = name .. "Probability"
    table.insert(spec.description.output, label(name))
    table.insert(spec.description.output, probabilities(name .. "Probability"))
end

local function sawtooth_kernel()
    local values = {}
    for width = 0, 2 do
        for height = 0, 2 do
            for output = 0, 3 do
                for input = 0, 2 do
                    local index = output * 27 + input * 9 + height * 3 + width
                    table.insert(values, f32(f32(f32(index) / 97.0) - 0.5))
                end
            end
        end
    end
    return values
end

local function build_nn_classifier()
    local spec = {specificationVersion = SPEC_12_2}
    spec.description = description({vector("x", {3})}, {vector("p", {2})})
    local classifier = {
        layers = {
            {name = "fc1", input = {"x"}, output = {"h"}, innerProduct = {
                inputChannels = 3, outputChannels = 4, hasBias = true,
                weights = {floatValue = {1.0, -2.0, 0.5, 0.25, 0.75, -1.5, -0.5, 1.0, 2.0, 3.0, 0.0, -1.0}},
                bias = {floatValue = {0.1, -0.2, 0.3, 0.0}},
            }},
            {name = "relu", input = {"h"}, output = {"hr"}, activation = {ReLU = {}}},
            {name = "fc2", input = {"hr"}, output = {"z"}, innerProduct = {
                inputChannels = 4, outputChannels = 2, hasBias = true,
                weights = {floatValue = {2.0, -1.0, 0.5, 0.5, -1.5, 1.0, 0.25, 0.75}},
                bias = {floatValue = {0.05, -0.05}},
            }},
            {name = "sm", input = {"z"}, output = {"p"}, softmax = {}},
        },
        updateParams = {},
    }
    spec.neuralNetworkClassifier = classifier
    class_labels(spec, classifier, {"no", "yes"})
    return spec
end

local function build_nn_image()
    local spec = {specificationVersion = SPEC_12_2}
    spec.description = description({vector("img", {3, 8, 8})}, {vector("p", {4})})
    local classifier = {
        layers = {
            {name = "conv", input = {"img"}, output = {"c"}, convolution = {
                outputChannels = 4, kernelChannels = 3, nGroups = 1, kernelSize = {3, 3}, stride = {1, 1},
                dilationFactor = {1, 1}, valid = {paddingAmounts = {borderAmounts = {{}, {}}}},
                hasBias = true, weights = {floatValue = sawtooth_kernel()},
                bias = {floatValue = {0.0, 0.0, 0.0, 0.0}},
            }},
            {name = "relu", input = {"c"}, output = {"cr"}, activation = {ReLU = {}}},
            {name = "pool", input = {"cr"}, output = {"p"}, pooling = {
                kernelSize = {6, 6}, stride = {6, 6}, valid = {paddingAmounts = {borderAmounts = {{}, {}}}},
                avgPoolExcludePadding = true, globalPooling = true,
            }},
        },
        preprocessing = {{featureName = "img", scaler = {
            channelScale = 1.0 / 255.0, redBias = -1.0, greenBias = -1.0, blueBias = -1.0,
        }}},
        updateParams = {},
    }
    spec.neuralNetworkClassifier = classifier
    class_labels(spec, classifier, {"a", "b", "c", "d"})
    return spec
end

local function build_tree_classifier()
    local spec = {specificationVersion = SPEC_11_2}
    spec.description = description({vector("a", {1}), vector("b", {1})}, {}, "classLabel", "classLabelProbability")
    table.insert(spec.description.output, label("classLabel"))
    table.insert(spec.description.output, probabilities("classLabelProbability"))
    local nodes = {}
    for tree_index, split in ipairs({{0, 0.5, 130, 140}, {1, 2.5, 150, 160}, {0, -1.0, 170, 180}}) do
        local feature, threshold, low, high = split[1], split[2], split[3], split[4]
        local tree = tree_index - 1
        table.insert(nodes, {
            treeId = tree, nodeId = tree * 4, nodeBehavior = 1, branchFeatureIndex = feature,
            branchFeatureValue = threshold, trueChildNodeId = low, falseChildNodeId = high,
        })
        for _, leaf in ipairs({{low, {0.9, 0.1}}, {high, {0.2, 0.8}}}) do
            local info = {}
            for class_index, value in ipairs(leaf[2]) do
                table.insert(info, {evaluationIndex = class_index - 1, evaluationValue = value})
            end
            table.insert(nodes, {treeId = tree, nodeId = leaf[1], nodeBehavior = 6, evaluationInfo = info})
        end
    end
    spec.treeEnsembleClassifier = {
        treeEnsemble = {nodes = nodes, numPredictionDimensions = 2, basePredictionValue = {0.0, 0.0}},
        postEvaluationTransform = 1,
        stringClassLabels = {vector = {"low", "high"}},
    }
    return spec
end

local function build_glm()
    local spec = {specificationVersion = SPEC_11_2}
    spec.description = description({vector("x", {2}, DOUBLE)}, {scalar_double("y")})
    spec.description.predictedFeatureName = "y"
    spec.glmRegressor = {
        weights = {{value = {1.5, -2.5}}},
        offset = {-0.5},
        postEvaluationTransform = 1,
    }
    return spec
end

local function build_pipeline()
    local scaler = {
        specificationVersion = SPEC_11_2,
        description = description({vector("x", {1}, DOUBLE)}, {vector("scaled", {1}, DOUBLE)}),
        scaler = {scaleValue = {0.25}, shiftValue = {-1.5}},
    }
    local inner = {
        specificationVersion = SPEC_1,
        description = description({vector("scaled", {1}, DOUBLE)}, {vector("probs", {2}, DOUBLE)}),
        neuralNetwork = {layers = {
            {name = "fc", input = {"scaled"}, output = {"y"}, innerProduct = {
                inputChannels = 1, outputChannels = 2, hasBias = true,
                weights = {floatValue = {2.0, -1.0}}, bias = {floatValue = {0.0, 0.1}},
            }},
            {name = "sm", input = {"y"}, output = {"probs"}, softmax = {}},
        }},
    }
    return {
        specificationVersion = SPEC_12_2,
        description = description({vector("x", {1}, DOUBLE)}, {vector("probs", {2}, DOUBLE)}),
        pipeline = {models = {scaler, inner}},
    }
end

local function build_nn_layers()
    local spec = {specificationVersion = SPEC_12_2}
    spec.description = description({vector("x", {1, 1, 4})}, {vector("out", {1, 1, 2})})
    spec.neuralNetwork = {
        layers = {
            {name = "fc", input = {"x"}, output = {"d"}, innerProduct = {
                inputChannels = 4, outputChannels = 2, hasBias = true,
                weights = {floatValue = {0.5, -1.0, 2.0, -0.5, 0.25, 0.75, -0.5, 2.0}},
                bias = {floatValue = {0.25, -0.25}},
            }},
            {name = "scale", input = {"d"}, output = {"sc"}, scale = {
                shapeScale = {1, 1, 2}, scale = {floatValue = {2.0, 0.5}}, hasBias = true,
                shapeBias = {1, 1, 2}, bias = {floatValue = {0.125, -0.5}},
            }},
            {name = "bias", input = {"sc"}, output = {"bi"}, bias = {
                shape = {1, 1, 2}, bias = {floatValue = {0.5, -0.25}},
            }},
            {name = "l2", input = {"bi"}, output = {"out"}, l2normalize = {epsilon = 1e-6}},
        },
        arrayInputShapeMapping = 1,
    }
    return spec
end

local function build_nn_layers_shape()
    local spec = {specificationVersion = SPEC_12_2}
    spec.description = description({vector("x", {1, 1, 2})}, {vector("out", {1, 1, 1})})
    spec.neuralNetwork = {
        layers = {
            {name = "up", input = {"x"}, output = {"uu"}, upsample = {scalingFactor = {1, 2}}},
            {name = "mul", input = {"uu", "uu"}, output = {"mu"}, multiply = {alpha = 1.0}},
            {name = "clip", input = {"mu"}, output = {"cl"}, clip = {minVal = 0.1, maxVal = 0.9}},
            {name = "tile", input = {"cl"}, output = {"tl"}, tile = {reps = {1, 1, 2}}},
            {name = "sum", input = {"tl"}, output = {"rd"}, reduce = {}},
            {name = "avg", input = {"rd"}, output = {"out"}, reduce = {mode = 1}},
        },
        arrayInputShapeMapping = 1,
    }
    return spec
end

local function build_nn_embedding()
    local spec = {specificationVersion = SPEC_12_2}
    spec.description = description({vector("index", {1, 1, 1}, INT32)}, {vector("vector", {1, 1, 2}, FLOAT32)})
    spec.neuralNetwork = {layers = {
        {name = "emb", input = {"index"}, output = {"vector"}, embedding = {
            inputDim = 3, outputChannels = 2, hasBias = true,
            weights = {floatValue = {1.0, -1.0, 0.5, 0.25, -0.5, 2.0}},
            bias = {floatValue = {0.1, 0.2}},
        }},
    }}
    return spec
end

local function build_glm_classifier()
    local spec = {specificationVersion = SPEC_11_2}
    spec.description = description({vector("x", {2}, DOUBLE)}, {})
    table.insert(spec.description.output, label("classLabel"))
    table.insert(spec.description.output, probabilities("classLabelProbability"))
    spec.description.predictedFeatureName = "classLabel"
    spec.description.predictedProbabilitiesName = "classLabelProbability"
    spec.glmClassifier = {
        weights = {{value = {1.0, -0.5}}, {value = {-0.25, 0.75}}},
        offset = {0.1, -0.1},
        stringClassLabels = {vector = {"first", "second", "third"}},
    }
    return spec
end

local function build_vision_image()
    local spec = {specificationVersion = SPEC_12_2}
    spec.description = description({image("image", 32, 32)}, {image("out", 32, 32)})
    spec.neuralNetwork = {
        layers = {
            {name = "conv", input = {"image"}, output = {"out"}, convolution = {
                outputChannels = 1, kernelChannels = 3, nGroups = 1, kernelSize = {1, 1}, stride = {1, 1},
                dilationFactor = {1, 1},
                valid = {paddingAmounts = {borderAmounts = {{}, {}}}},
                hasBias = true,
                weights = {floatValue = {f32(1.0 / 255.0), 0.0, 0.0}},
                bias = {floatValue = {0.0}},
            }},
        },
        preprocessing = {{featureName = "image", scaler = {
            channelScale = 1.0 / 255.0, redBias = -1.0, greenBias = -1.0, blueBias = -1.0,
        }}},
    }
    return spec
end

local function build_nn_layers_image()
    local weights = {}
    for at = 0, 4 * 3 * 3 * 3 - 1 do
        table.insert(weights, (at * 11 % 97) / 97.0 - 0.5)
    end
    return {
        specificationVersion = SPEC_12_2,
        description = description({vector("x", {3, 8, 8})}, {vector("out", {4, 1, 1})}),
        neuralNetwork = {
            layers = {
                {name = "conv", input = {"x"}, output = {"c"}, convolution = {
                    kernelChannels = 3, outputChannels = 4, nGroups = 1, kernelSize = {3, 3}, stride = {1, 1},
                    dilationFactor = {1, 1}, hasBias = true,
                    weights = {floatValue = weights},
                    bias = {floatValue = {0.1, -0.1, 0.2, -0.2}},
                }},
                {name = "relu", input = {"c"}, output = {"cr"}, activation = {ReLU = {}}},
                {name = "pad", input = {"cr"}, output = {"pd"}, padding = {
                    constant = {value = 0.0},
                    paddingAmounts = {borderAmounts = {{startEdgeSize = 1, endEdgeSize = 1},
                                                       {startEdgeSize = 1, endEdgeSize = 1}}},
                }},
                {name = "pool", input = {"pd"}, output = {"gp"}, pooling = {
                    type = 1, globalPooling = true, avgPoolExcludePadding = true,
                }},
                {name = "bn", input = {"gp"}, output = {"out"}, batchnorm = {
                    epsilon = 1e-5, instanceNormalization = true,
                    gamma = {floatValue = {1.0, 2.0, 0.5, 1.5}},
                    beta = {floatValue = {0.0, 0.25, -0.25, 0.1}},
                    mean = {floatValue = {0.0, 0.0, 0.0, 0.0}},
                    variance = {floatValue = {1.0, 1.0, 1.0, 1.0}},
                }},
            },
            preprocessing = {{featureName = "x", scaler = {channelScale = 2.0}}},
            arrayInputShapeMapping = 1,
        },
    }
end

local function build_nn_recurrent()
    return {
        specificationVersion = SPEC_12_2,
        description = description({vector("seq", {1, 1, 6}), vector("state", {1, 1, 2})},
                                  {vector("out", {1, 1, 6}), vector("outstate", {1, 1, 2})}),
        neuralNetwork = {
            layers = {
                {name = "rnn", input = {"seq", "state"}, output = {"out", "outstate"}, simpleRecurrent = {
                    inputVectorSize = 2, outputVectorSize = 2, hasBiasVector = true, sequenceOutput = true,
                    activation = {tanh = {}},
                    weightMatrix = {floatValue = {1.0, -0.5, 0.25, 0.5}},
                    recursionMatrix = {floatValue = {0.5, 0.25, -0.5, 1.0}},
                    biasVector = {floatValue = {0.0, 0.1}},
                }},
            },
        },
    }
end

local UNMEASURED = {
    nn_layers_image = build_nn_layers_image,
    nn_recurrent = build_nn_recurrent,
}

local BUILDERS = {
    glm = build_glm,
    glm_classifier = build_glm_classifier,
    nn_classifier = build_nn_classifier,
    nn_embedding = build_nn_embedding,
    nn_image = build_nn_image,
    nn_layers = build_nn_layers,
    nn_layers_shape = build_nn_layers_shape,
    pipeline = build_pipeline,
    tree_classifier = build_tree_classifier,
    vision_image = build_vision_image,
}

local function write_lines(file, lines)
    io.writefile(file, table.concat(lines, "\n") .. "\n", {encoding = "binary"})
end

local SAMPLES = {
    glm = {{"x", {2}, {-1.5, 0.0}}},
    glm_classifier = {{"x", {2}, {0.5, -0.5}}},
    nn_classifier = {{"x", {3}, {0.5, -0.25, 1.0}}},
    nn_embedding = {{"index", {1, 1, 1}, {2}}},
    nn_image = {{"img", {3, 8, 8}, (function()
        local values = {}
        for index = 0, 3 * 8 * 8 - 1 do
            table.insert(values, f32(f32(index) / 255.0))
        end
        return values
    end)()}},
    nn_layers = {{"x", {1, 1, 4}, {0.5, -1.5, 2.0, 0.25}}},
    nn_layers_shape = {{"x", {1, 1, 2}, {0.5, -0.25}}},
    pipeline = {{"x", {1}, {2.0}}},
    tree_classifier = {{"a", {1}, {0.25}}, {"b", {1}, {1.0}}},
}

local TOLERANCES = {
    nn_embedding = {2 ^ -11, "Core ML on this host answers the embedding in float16 (0.60009765625 for 0.6, which is the "
        .. "float16 nearest to 0.6, measured by predict-host); the port answers the exact sum, so each answer may differ "
        .. "from the host's by half a float16 ulp at its magnitude and no more", "half_ulp"},
}

local DIVERGENCES = {}

local OBJECT = "\0object"
local NULL = {}

local function object(entries)
    entries[OBJECT] = true
    return entries
end

local function json_string(text)
    return '"' .. text:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

local function json_text(value, depth)
    depth = depth or 0
    if value == NULL or value == nil then
        return "null"
    elseif type(value) == "boolean" then
        return value and "true" or "false"
    elseif type(value) == "number" then
        if math.type(value) == "integer" then
            return string.format("%d", value)
        end
        return proto.float_text(value)
    elseif type(value) == "string" then
        return json_string(value)
    end
    local pad = string.rep(" ", depth + 1)
    local close = string.rep(" ", depth)
    if value[OBJECT] then
        local keys = {}
        for key in pairs(value) do
            if key ~= OBJECT then
                table.insert(keys, key)
            end
        end
        byteorder.sort(keys)
        if #keys == 0 then
            return "{}"
        end
        local lines = {}
        for _, key in ipairs(keys) do
            table.insert(lines, pad .. json_string(key) .. ": " .. json_text(value[key], depth + 1))
        end
        return "{\n" .. table.concat(lines, ",\n") .. "\n" .. close .. "}"
    end
    if #value == 0 then
        return "[]"
    end
    local lines = {}
    for _, item in ipairs(value) do
        table.insert(lines, pad .. json_text(item, depth + 1))
    end
    return "[\n" .. table.concat(lines, ",\n") .. "\n" .. close .. "]"
end

local function nested(values, shape, axis, offset)
    if axis > #shape then
        return values[offset]
    end
    local list = {}
    local stride = 1
    for later = axis + 1, #shape do
        stride = stride * shape[later]
    end
    for index = 1, shape[axis] do
        list[index] = nested(values, shape, axis + 1, offset + (index - 1) * stride)
    end
    return list
end

local function read_answer(file)
    local prediction = object({})
    for line in io.lines(file) do
        local name, kind, rest = line:match("^output (%S+) (%S+) ?(.*)$")
        if name == nil then
            raise("the probe printed a line this reader does not know: %s", line)
        end
        if kind == "array" then
            local extents, values = rest:match("^(%S+) ?(.*)$")
            local shape = {}
            for extent in extents:gmatch("[^x]+") do
                table.insert(shape, tonumber(extent))
            end
            local flat = {}
            for number in values:gmatch("%S+") do
                table.insert(flat, tonumber(number) + 0.0)
            end
            prediction[name] = nested(flat, shape, 1, 1)
        elseif kind == "double" then
            prediction[name] = tonumber(rest) + 0.0
        elseif kind == "int64" then
            prediction[name] = math.tointeger(tonumber(rest))
        elseif kind == "string" then
            prediction[name] = rest
        elseif kind == "dictionary" then
            local entries = object({})
            local words = {}
            for word in rest:gmatch("%S+") do
                table.insert(words, word)
            end
            for index = 1, #words, 2 do
                entries[words[index]] = tonumber(words[index + 1]) + 0.0
            end
            prediction[name] = entries
        else
            raise("the probe answered %s of kind %s, which this reader does not know", name, kind)
        end
    end
    return prediction
end

local function build_probe(scratch)
    local probe = path.join(scratch, "predict-host")
    local source = path.join(os.scriptdir(), "predict-host.m")
    os.execv("xcrun", {"clang", "-fobjc-arc", "-Wall", "-framework", "Foundation", "-framework", "CoreML",
                       "-o", probe, source}, {try = true, stdout = path.join(scratch, "probe-build.log"),
                                             stderr = path.join(scratch, "probe-build.log")})
    if not os.isfile(probe) then
        raise("predict-host did not build: see %s", path.join(scratch, "probe-build.log"))
    end
    return probe
end

local function probe_model(probe, name, container, scratch, refusable)
    local tmp = path.join(scratch, "tmp")
    os.mkdir(tmp)
    local answer = path.join(scratch, name .. ".answer")
    local errors = path.join(scratch, name .. ".stderr")
    local samples = SAMPLES[name]
    local inputs = "-"
    if samples ~= nil then
        inputs = path.join(scratch, name .. ".inputs")
        local lines = {}
        for _, sample in ipairs(samples) do
            local extents = {}
            for _, extent in ipairs(sample[2]) do
                table.insert(extents, tostring(extent))
            end
            local line = "input " .. sample[1] .. " " .. table.concat(extents, "x")
            for _, value in ipairs(sample[3]) do
                line = line .. " " .. string.format("%.17g", value)
            end
            table.insert(lines, line)
        end
        io.writefile(inputs, table.concat(lines, "\n") .. "\n")
    end
    local status = os.execv(probe, {container, inputs}, {try = true, stdout = answer, stderr = errors,
                                                           envs = {TMPDIR = tmp}})
    if status ~= 0 then
        if refusable then
            return nil, io.readfile(errors)
        end
        raise("predict-host on %s: %s", name, io.readfile(errors))
    end
    if samples == nil then
        return nil
    end
    return read_answer(answer)
end

local function bytes_of(file)
    return io.readfile(file, {encoding = "binary"})
end

function main(...)
    local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})
    local out = workspace.run("make-models", "models")
    local check, unmeasured = false, false
    local arguments = {...}
    local index = 1
    while index <= #arguments do
        local argument = arguments[index]
        if argument == "--out" and index < #arguments then
            out = path.absolute(arguments[index + 1])
            index = index + 2
        elseif argument == "--unmeasured" and index < #arguments then
            out = path.absolute(arguments[index + 1])
            unmeasured = true
            index = index + 2
        elseif argument == "--check" then
            check = true
            index = index + 1
        else
            raise("usage: xmake l tools/coreml/make-models.lua [--out <directory>] [--check] [--unmeasured <directory>]")
        end
    end

    local root = path.absolute(path.join(os.scriptdir(), "..", ".."))
    local schema = proto.load(path.join(root, "packages", "a", "apple-backports", "CoreML", "CharonMLSchema.inc"))
    local runs = workspace.run("make-models", "work")
    local target = check and path.join(runs, "check") or out
    os.tryrm(target)
    os.mkdir(target)
    os.mkdir(runs)
    local probe = build_probe(runs)

    local builders = unmeasured and UNMEASURED or BUILDERS
    local names = {}
    for name in pairs(builders) do
        table.insert(names, name)
    end
    byteorder.sort(names)

    local manifest = object({})
    for _, name in ipairs(names) do
        local built = builders[name]()
        local bytes = proto.encode(schema, "Model", built)
        local container = path.join(target, name .. ".mlmodel")
        io.writefile(container, bytes, {encoding = "binary"})
        local written = proto.decode(schema, "Model", bytes)
        write_lines(path.join(target, name .. ".ref"), proto.dump(schema, "Model", written))
        local prediction, refusal = probe_model(probe, name, container, runs, unmeasured)
        if refusal then
            local reason = refusal:match("validator error: ([^\n]*)") or refusal:gsub("\n", " ")
            print(string.format("%-15s %6d bytes  refused by this host's Core ML: %s", name, #bytes, reason))
        end
        local tolerance = TOLERANCES[name]
        manifest[name] = object({
            path = path.relative(path.join(out, name .. ".mlmodel"), path.directory(out)),
            bytes = #bytes,
            specification = written.specificationVersion,
            tolerance = tolerance and {tolerance[1], tolerance[2], tolerance[3] or NULL} or {1e-5, NULL, NULL},
            divergence = DIVERGENCES[name] or NULL,
            prediction = prediction or NULL,
        })
        if not refusal then
            print(string.format("%-15s %6d bytes  spec %d  %s", name, #bytes, written.specificationVersion,
                                prediction and "prediction ok" or "compiled and loaded, no host input"))
        end
    end
    if unmeasured then
        return
    end
    io.writefile(path.join(target, "manifest.json"), json_text(manifest) .. "\n", {encoding = "binary"})

    if check then
        for _, name in ipairs(names) do
            for _, file in ipairs({name .. ".mlmodel", name .. ".ref"}) do
                if bytes_of(path.join(target, file)) ~= bytes_of(path.join(out, file)) then
                    raise("%s is not the file written here", path.join(out, file))
                end
            end
        end
        if bytes_of(path.join(target, "manifest.json")) ~= bytes_of(path.join(out, "manifest.json")) then
            raise("%s is not the manifest written here", path.join(out, "manifest.json"))
        end
    end
end

function samples_of(name)
    return SAMPLES[name]
end
