import("core.base.json")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})
local make_models = import("make-models", {rootdir = os.scriptdir()})

local function read(file)
    return io.readfile(file, {encoding = "binary"})
end

local function is_null(value)
    return value == nil or value == json.null
end

local function keys_of(tbl)
    local keys = {}
    for key in pairs(tbl) do
        table.insert(keys, key)
    end
    byteorder.sort(keys)
    return keys
end

local function is_object(value)
    for key in pairs(value) do
        return type(key) == "string"
    end
    return false
end

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

local function line_of(text, key)
    for line in text:gmatch("[^\n]+") do
        if line:sub(1, #key + 3) == key .. " = " then
            return line
        end
    end
    return nil
end

local function entries_of(line)
    local got = {}
    for label, score in line:gmatch("'([^']*)':%s*(%-?[%d%.eE%+%-]+)") do
        got[label] = tonumber(score)
    end
    return got
end

local function values_of(line, key)
    local after = line:sub(#key + 4)
    return numbers((after:gsub("'[^']*':", " ")))
end

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

local function last_line(text)
    local last = ""
    for line in text:gmatch("[^\n]+") do
        last = line
    end
    return last
end

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

local function bound(limit, mode, theirs)
    if mode == "half_ulp" then
        return limit * math.abs(theirs) + 2 ^ -25
    end
    return limit * math.max(1.0, math.abs(theirs))
end

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

local CASES = {
    {"glm", "--set", "x", "2", "-1.5", "0"},
    {"glm_classifier", "--set", "x", "2", "0.5", "-0.5"},
    {"nn_classifier", "--set", "x", "3", "0.5", "-0.25", "1.0"},
    {"nn_layers", "--setr", "x", "1x1x4", "4", "0.5", "-1.5", "2.0", "0.25"},
    {"nn_layers_shape", "--setr", "x", "1x1x2", "2", "0.5", "-0.25"},
    {"pipeline", "--set", "x", "1", "2"},
    {"tree_classifier", "--set", "a", "1", "0.25", "--set", "b", "1", "1.0"}
}

function prepare(out, compiled)
    local root = path.directory(path.directory(os.scriptdir()))
    local core = path.join(root, "packages", "a", "apple-backports", "CoreML")
    os.mkdir(out)
    if not os.isfile(path.join(out, "models", "manifest.json")) then
        os.execv(os.programfile(), {"l", path.join(os.scriptdir(), "make-models.lua"), "--out", path.join(out, "models")})
    end
    local sources = {}
    for _, source in ipairs(compiled.sources) do
        table.insert(sources, path.join(source[1] == "core" and core or os.scriptdir(), source[2]))
    end
    if compiled.glob then
        table.join2(sources, os.files(path.join(core, compiled.glob)))
    end
    local binary = path.join(out, compiled.name)
    os.execv(os.getenv("CC") or "clang", table.join({"-std=c99", "-Wall", "-Wextra", "-Wno-unused-parameter", "-O1", "-fsanitize=address",
                                                     "-I", core, "-o", binary}, sources))
    return binary
end

function check(out, tolerance_text)
    local tolerance = tonumber(tolerance_text)
    local models = path.join(out, "models")
    local harness = path.join(out, "ml-predict")
    local manifest = json.decode(read(path.join(models, "manifest.json")))
    run_shaped(harness, models, out, manifest)

    local failures, compared, known = 0, 0, 0
    for _, name in ipairs(keys_of(manifest)) do
        local entry = manifest[name]
        local expected = entry.prediction
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

function main(out)
    if not out or out == "" then
        local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})
        out = workspace.run("coreml-predict")
    end
    out = path.absolute(out)
    print("interpreter check -> " .. out)
    local harness = prepare(out, {name = "ml-predict", sources = {{"tools", "predict-main.c"}}, glob = "CharonML*.c"})
    for _, case in ipairs(CASES) do
        local name = case[1]
        local actual = path.join(out, name .. ".actual")
        local answer = path.join(out, name .. ".answer")
        os.execv(harness, table.join({path.join(out, "models", name .. ".mlmodel")}, table.slice(case, 2)),
                 {try = true, stdout = answer, stderr = answer})
        io.writefile(actual, name .. "\n" .. (io.readfile(answer, {encoding = "binary"}) or ""), {encoding = "binary"})
        os.rm(answer)
    end
    check(out, os.getenv("TOLERANCE") or "1e-5")
end
