-- check-predict.lua: the CoreML interpreter, measured against the host's own Core ML.
--
--   xmake l tools/coreml/check-predict.lua <run directory> <tolerance>
--
-- check-predict.sh builds the interpreter (ml-predict) and runs it on the flat inputs. This runs it on the inputs that
-- are not one flat vector, through the same harness, and then compares every answer with the manifest that
-- make-models.lua wrote from the host's own Core ML (predict-host).
--
-- The inputs of those models are read from make-models.lua's own samples, so the check and the recording cannot
-- disagree about what was fed.

import("core.base.json")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})
local make_models = import("make-models", {rootdir = os.scriptdir()})

local function read(file)
    return io.readfile(file, {encoding = "binary"})
end

local function is_null(value)
    return value == nil or value == json.null
end

-- The keys of a table, sorted by byte as Python's sorted() sorts them.
local function keys_of(tbl)
    local keys = {}
    for key in pairs(tbl) do
        table.insert(keys, key)
    end
    byteorder.sort(keys)
    return keys
end

-- A decoded JSON object has string keys. An array has none, and an empty one counts as an array.
local function is_object(value)
    for key in pairs(value) do
        return type(key) == "string"
    end
    return false
end

-- The numbers of a text, in order, as re.findall(r"-?\d+\.?\d*(?:e[-+]?\d+)?") finds them.
local function numbers(text)
    local found, at = {}, 1
    while true do
        local first, last = text:find("%-?%d+%.?%d*", at)
        if first == nil then
            return found
        end
        local exponent = text:match("^e[-+]?%d+", last + 1) or ""
        table.insert(found, tonumber(text:sub(first, last) .. exponent))
        at = last + 1 + #exponent
    end
end

-- Every number of a JSON value, in order.
local function flatten(value, out)
    out = out or {}
    if type(value) == "table" then
        for _, item in ipairs(value) do
            flatten(item, out)
        end
    elseif type(value) == "number" then
        table.insert(out, value)
    end
    return out
end

-- The answer line that begins "key = ", or nil.
local function line_of(text, key)
    for line in text:gmatch("[^\n]+") do
        if line:sub(1, #key + 3) == key .. " = " then
            return line
        end
    end
    return nil
end

-- A dictionary answer's entries: each label and its score, as the line writes them.
local function entries_of(line)
    local got = {}
    for label, score in line:gmatch("'([^']*)':%s*(%-?[%d%.eE%+%-]+)") do
        got[label] = tonumber(score)
    end
    return got
end

-- The numbers an answer line gives after its "=", with any dictionary labels left out.
local function values_of(line, key)
    local after = line:sub(#key + 4)
    return numbers((after:gsub("'[^']*':", " ")))
end

-- What a manifest answer is: a string, a dictionary of labels to scores, or a list of numbers.
local function wanted_of(value)
    if type(value) == "string" then
        return {kind = "string", value = value}
    elseif type(value) == "table" and is_object(value) then
        local labels = keys_of(value)
        local scores = {}
        for at, label in ipairs(labels) do
            scores[at] = value[label]
        end
        return {kind = "dict", labels = labels, scores = scores}
    end
    return {kind = "list", value = flatten(value)}
end

-- The last line of a text, which is where the interpreter says why it refused a model.
local function last_line(text)
    local last = ""
    for line in text:gmatch("[^\n]+") do
        last = line
    end
    return last
end

-- The inputs that are not one flat vector: an embedding's index and a channels-first array. Each is run through the
-- harness the way a shape is given, and its answer is written beside the others, as <name>.actual.
local function run_shaped(harness, models, out, manifest)
    for _, name in ipairs({"nn_embedding", "nn_image"}) do
        local entry = manifest[name]
        local samples = make_models.samples_of(name)
        if entry ~= nil and not is_null(entry.prediction) and samples ~= nil then
            local text = name .. "\n"
            for _, sample in ipairs(samples) do
                local field, shape, values = sample[1], sample[2], sample[3]
                local args = {path.join(models, name .. ".mlmodel"), "--setr", field,
                              table.concat(shape, "x"), tostring(#values)}
                for _, value in ipairs(values) do
                    table.insert(args, string.format("%.9g", value))
                end
                local answer = path.join(out, name .. ".sample")
                os.execv(harness, args, {try = true, stdout = answer, stderr = answer})
                text = text .. read(answer)
                os.rm(answer)
            end
            io.writefile(path.join(out, name .. ".actual"), text, {encoding = "binary"})
        end
    end
end

-- How far an answer may be from the host's. The default is limit relative to the host's value, with an absolute floor of
-- limit at magnitude 1. "half_ulp" is half an ulp of float16 at the value's own magnitude: 2^-11 of it, and for zero half
-- the smallest float16 subnormal, 2^-25.
local function bound(limit, mode, theirs)
    if mode == "half_ulp" then
        return limit * math.abs(theirs) + 2 ^ -25
    end
    return limit * math.max(1.0, math.abs(theirs))
end

-- Compares one manifest answer with the interpreter's, within limit. Prints each difference; returns whether they agree.
local function check_answer(name, key, want, text, limit, mode)
    if not text:find(key, 1, true) then
        print(string.format("%-15s FAIL - no answer named '%s'", name, key))
        return false
    end
    if want.kind == "string" then
        if not text:find("'" .. want.value .. "'", 1, true) then
            print(string.format("%-15s FAIL - '%s' should be '%s'", name, key, want.value))
            return false
        end
        return true
    end
    local line = line_of(text, key)
    if line == nil then
        print(string.format("%-15s FAIL - no answer line for '%s'", name, key))
        return false
    end
    if want.kind == "dict" then
        -- a dictionary is a mapping: its keys are compared as a set, and each score under the same key
        local got = entries_of(line)
        local count = 0
        for _ in pairs(got) do
            count = count + 1
        end
        local same = count == #want.labels
        for _, label in ipairs(want.labels) do
            if got[label] == nil then
                same = false
            end
        end
        if not same then
            print(string.format("%-15s FAIL - '%s' has the keys %s, Core ML gave %s", name, key,
                                table.concat(keys_of(got), ", "), table.concat(want.labels, ", ")))
            return false
        end
        local ok = true
        for at, label in ipairs(want.labels) do
            local theirs = want.scores[at]
            if math.abs(got[label] - theirs) > bound(limit, mode, theirs) then
                print(string.format("%-15s FAIL - %s['%s'] is %.9g, Core ML gave %.9g",
                                    name, key, label, got[label], theirs))
                ok = false
            end
        end
        return ok
    end
    local mine = values_of(line, key)
    if #mine ~= #want.value then
        print(string.format("%-15s FAIL - '%s' has %d values, Core ML gave %d", name, key, #mine, #want.value))
        return false
    end
    local ok = true
    for at, theirs in ipairs(want.value) do
        if math.abs(mine[at] - theirs) > bound(limit, mode, theirs) then
            print(string.format("%-15s FAIL - %s[%d] is %.9g, Core ML gave %.9g", name, key, at - 1, mine[at], theirs))
            ok = false
        end
    end
    return ok
end

-- Whether an answer differs from the host's beyond the tolerance. A dictionary's missing label counts as zero.
local function differs_from(text, key, want, tolerance, mode)
    if want.kind == "string" then
        return false
    end
    local line = line_of(text, key)
    if want.kind == "dict" then
        local got = line and entries_of(line) or {}
        for at, label in ipairs(want.labels) do
            local theirs = want.scores[at]
            if math.abs((got[label] or 0.0) - theirs) > bound(tolerance, mode, theirs) then
                return true
            end
        end
        return false
    end
    if line ~= nil then
        local mine = values_of(line, key)
        for at = 1, math.min(#mine, #want.value) do
            local theirs = want.value[at]
            if math.abs(mine[at] - theirs) > bound(tolerance, mode, theirs) then
                return true
            end
        end
    end
    return false
end

function main(out, tolerance_text)
    local tolerance = tonumber(tolerance_text)
    local models = path.join(out, "models")
    local harness = path.join(out, "ml-predict")
    local manifest = json.decode(read(path.join(models, "manifest.json")))
    run_shaped(harness, models, out, manifest)

    local failures, compared, known = 0, 0, 0
    for _, name in ipairs(keys_of(manifest)) do
        local entry = manifest[name]
        local expected = entry.prediction
        -- a model may state its own bound and the mode it is read in; the default is the global one, relative with an
        -- absolute floor of one
        local model_tolerance, mode = tolerance, nil
        if entry.tolerance ~= nil and not is_null(entry.tolerance) then
            model_tolerance = entry.tolerance[1]
            mode = not is_null(entry.tolerance[3]) and entry.tolerance[3] or nil
        end
        local divergence = not is_null(entry.divergence) and entry.divergence or nil
        local limit = math.max(tolerance, model_tolerance)

        if is_null(expected) then
            print(string.format("%-15s SKIP - no host input recorded for this kind of model", name))
        else
            local actual = path.join(out, name .. ".actual")
            if not os.isfile(actual) then
                print(string.format("%-15s FAIL - the interpreter was not run", name))
                failures = failures + 1
            else
                local text = read(actual)
                if text:find("ml-predict:", 1, true) then
                    print(string.format("%-15s FAIL - the interpreter refused the model: %s", name, last_line(text)))
                    failures = failures + 1
                else
                    local keys = keys_of(expected)
                    local wanted = {}
                    for _, key in ipairs(keys) do
                        wanted[key] = wanted_of(expected[key])
                    end

                    if divergence then
                        -- a model whose difference from the host is recorded: the check says what the difference is,
                        -- and fails if the two agree, so a stale explanation is caught
                        local differs = false
                        for _, key in ipairs(keys) do
                            if differs_from(text, key, wanted[key], tolerance) then
                                differs = true
                            end
                        end
                        if differs then
                            print(string.format("%-15s KNOWN DIVERGENCE - the port's answers differ from the host's, "
                                                .. "and the difference is written down", name))
                            print(string.format("%-15s                 %s", "", divergence))
                            known = known + 1
                        else
                            print(string.format("%-15s FAIL - the divergence is recorded but the port and the host now "
                                                .. "agree, so whatever caused it is gone", name))
                            failures = failures + 1
                        end
                    else
                        local ok = true
                        for _, key in ipairs(keys) do
                            if not check_answer(name, key, wanted[key], text, limit, mode) then
                                ok = false
                            end
                        end
                        if not ok then
                            failures = failures + 1
                        else
                            print(string.format("%-15s OK - %d answers within %g of Core ML on this host%s",
                                                name, #keys, limit, mode == "half_ulp" and " (half a float16 ulp)" or ""))
                            compared = compared + 1
                        end
                    end
                end
            end
        end
    end

    print(string.format("compared %d models, %d with a recorded divergence", compared, known))
    if failures > 0 then
        raise("interpreter check: FAIL (%d failures)", failures)
    end
    if compared == 0 then
        raise("interpreter check: FAIL (no model was compared: a check that compares nothing proves nothing)")
    end
    print(string.format("interpreter check: OK (%d failures, %d models compared, %d with a recorded divergence)",
                        failures, compared, known))
end
