local function reads(dump, model, out, err)
    return os.execv(dump, {model}, {try = true, stdout = out or os.nuldev(), stderr = err or os.nuldev()}) == 0
end

local function indented(text)
    return (text:gsub("[^\n]*\n", function (line) return "    " .. line end))
end

local function malformed(out)
    local data = io.readfile(path.join(out, "models", "glm.mlmodel"), {encoding = "binary"})
    local shapes = {
        {"truncated", data:sub(1, #data // 2)},
        {"garbage", string.rep("\255", 64)},
        {"short-length", "\10\127\1\2\3"},
        {"field-past-end", "\18\64\2\1"}
    }
    for _, shape in ipairs(shapes) do
        io.writefile(path.join(out, shape[1] .. ".mlmodel"), shape[2], {encoding = "binary"})
    end
    return shapes
end

function main(out)
    if not out or out == "" then
        local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})
        out = workspace.run("coreml-reader")
    end
    out = path.absolute(out)
    print("reader check -> " .. out)
    if not os.isfile(path.join(out, "models", "manifest.json")) then
        print("writing the containers...")
    end
    local dump = import("check-predict", {rootdir = os.scriptdir(), anonymous = true}).prepare(out, {name = "ml-dump",
        sources = {{"tools", "ml-dump.c"}, {"core", "RevenantMLProto.c"}, {"core", "RevenantMLSchema.c"}}})
    local failures = 0
    local models = os.files(path.join(out, "models", "*.mlmodel"))
    local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})
    byteorder.sort(models)
    for _, model in ipairs(models) do
        local name = path.basename(model)
        local actual, err = path.join(out, name .. ".actual"), path.join(out, name .. ".err")
        if not reads(dump, model, actual, err) then
            print(name .. ": FAIL - the reader refused a container the writer made")
            io.write(indented(io.readfile(err) or ""))
            failures = failures + 1
        else
            local diff = path.join(out, name .. ".diff")
            local same = os.execv("diff", {"-u", path.join(out, "models", name .. ".ref"), actual}, {try = true, stdout = diff}) == 0
            if same then
                print(name .. ": OK - the tree read is identical to the reference dump's")
            else
                print(name .. ": FAIL - the tree read differs from the reference dump's")
                local lines = {}
                for line in io.lines(diff) do
                    if #lines < 20 then
                        table.insert(lines, line .. "\n")
                    end
                end
                io.write(indented(table.concat(lines)))
                failures = failures + 1
            end
        end
    end
    for _, shape in ipairs(malformed(out)) do
        if reads(dump, path.join(out, shape[1] .. ".mlmodel")) then
            print(shape[1] .. ": FAIL - a malformed container was read as a model")
            failures = failures + 1
        else
            print(shape[1] .. ": OK - refused, as a malformed container must be")
        end
    end
    if failures == 0 then
        print("reader check: OK (0 failures)")
        return
    end
    print(string.format("reader check: FAIL (%d failures)", failures))
    os.exit(1)
end
