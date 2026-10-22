local function logical_lines(text)
    local out, pending = {}, nil
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        local dollars = line:match("(%$*)$")
        if dollars and #dollars % 2 == 1 then
            local piece = line:sub(1, -2)
            if pending then
                piece = piece:gsub("^%s+", "")
            end
            pending = (pending or "") .. piece
        else
            if pending then
                line = line:gsub("^%s+", "")
            end
            table.insert(out, (pending or "") .. line)
            pending = nil
        end
    end
    return out
end

local function unescape(text)
    return (text:gsub("%$(.)", function (c)
        if c == "$" or c == " " or c == ":" then
            return c
        end
        return "$" .. c
    end))
end

local function words(text)
    local tokens, word = {}, nil
    local function flush()
        if word then
            table.insert(tokens, {kind = "word", value = word})
            word = nil
        end
    end
    local i, n = 1, #text
    while i <= n do
        local c = text:sub(i, i)
        if c == "$" and text:sub(i + 1, i + 1) == "{" then
            local close = text:find("}", i + 2, true)
            word = (word or "") .. text:sub(i, close)
            i = close + 1
        elseif c == "$" and i < n then
            word = (word or "") .. text:sub(i + 1, i + 1)
            i = i + 2
        elseif c == " " then
            flush()
            i = i + 1
        elseif c == ":" then
            flush()
            table.insert(tokens, {kind = ":"})
            i = i + 1
        elseif c == "|" then
            flush()
            if text:sub(i + 1, i + 1) == "|" then
                table.insert(tokens, {kind = "||"})
                i = i + 2
            else
                table.insert(tokens, {kind = "|"})
                i = i + 1
            end
        else
            word = (word or "") .. c
            i = i + 1
        end
    end
    flush()
    return tokens
end

local function parse(text)
    local edges, variables, edge = {}, {}, nil
    for _, line in ipairs(logical_lines(text)) do
        if line:startswith("build ") then
            edge = {outputs = {}, inputs = {}, vars = {}}
            table.insert(edges, edge)
            local tokens = words(line:sub(7))
            local colon = nil
            local explicit = true
            for index, token in ipairs(tokens) do
                if token.kind == ":" then
                    colon = index
                    break
                end
                if token.kind == "word" then
                    if explicit then
                        table.insert(edge.outputs, token.value)
                    end
                else
                    explicit = false
                end
            end
            assert(colon, "ninja: a build line without a colon: " .. line)
            edge.rule = tokens[colon + 1] and tokens[colon + 1].value
            local stop = false
            for index = colon + 2, #tokens do
                local token = tokens[index]
                if token.kind == "|" or token.kind == "||" then
                    stop = true
                elseif token.kind == "word" and not stop then
                    table.insert(edge.inputs, token.value)
                end
            end
        elseif edge and line:match("^%s+[%w_%-]+%s*=") then
            local key, value = line:match("^%s+([%w_%-]+)%s*=%s?(.*)$")
            edge.vars[key] = unescape(value)
        elseif line:match("^[%w_%-]+%s*=") then
            edge = nil
            local key, value = line:match("^([%w_%-]+)%s*=%s?(.*)$")
            variables[key] = unescape(value)
        elseif line:match("^%S") then
            edge = nil
        end
    end
    return edges, variables
end

local function expand(text, variables)
    return (text:gsub("%${([%w_%-]+)}", function (name)
        return variables[name] or ("${" .. name .. "}")
    end))
end

local function json_string(text)
    local escaped = text:gsub('[%c"\\]', function (c)
        if c == '"' then
            return '\\"'
        elseif c == "\\" then
            return "\\\\"
        elseif c == "\n" then
            return "\\n"
        elseif c == "\t" then
            return "\\t"
        end
        return string.format("\\u%04x", c:byte())
    end)
    return '"' .. escaped .. '"'
end

local function json_array(items, indent)
    if #items == 0 then
        return "[]"
    end
    local lines = {}
    for _, item in ipairs(items) do
        table.insert(lines, indent .. "  " .. item)
    end
    return "[\n" .. table.concat(lines, ",\n") .. "\n" .. indent .. "]"
end

local function selected(edges, interpreter)
    local picked = {}
    for _, edge in ipairs(edges) do
        local command = edge.vars.COMMAND
        if edge.rule == "CUSTOM_COMMAND" and command and command:find(interpreter, 1, true) then
            table.insert(picked, edge)
        end
    end
    return picked
end

local function script_of(command, interpreter)
    local rest = command:match(interpreter:gsub("%p", "%%%0") .. "%s+(%S+)")
    return rest and rest:gsub('"', "") or ""
end

local function digest(path)
    if os.isfile(path) then
        return hash.sha256(path)
    end
    return "missing"
end

local function plan(ninja, interpreter)
    local edges = parse(io.readfile(ninja))
    local picked = selected(edges, interpreter)
    local outputs = 0
    for _, edge in ipairs(picked) do
        outputs = outputs + #edge.outputs
        print("%s %d %s", script_of(edge.vars.COMMAND, interpreter), #edge.outputs, edge.outputs[1])
    end
    print("ninja edges: %d, custom commands running the interpreter: %d, outputs: %d", #edges, #picked, outputs)
    return picked
end

local function execute(build, picked, variables)
    local function resolve(name)
        local full = expand(name, variables)
        if path.is_absolute(full) then
            return full
        end
        return path.join(build, full)
    end
    local made, pending = {}, {}
    for _, edge in ipairs(picked) do
        table.insert(pending, edge)
    end
    while #pending > 0 do
        local remaining = {}
        for _, edge in ipairs(pending) do
            local ready = true
            for _, input in ipairs(edge.inputs) do
                local full = resolve(input)
                if not made[full] and not os.isfile(full) then
                    ready = false
                    break
                end
            end
            if ready then
                for _, output in ipairs(edge.outputs) do
                    os.mkdir(path.directory(resolve(output)))
                end
                os.vrunv("/bin/sh", {"-c", expand(edge.vars.COMMAND, variables)}, {curdir = build})
                for _, output in ipairs(edge.outputs) do
                    local full = resolve(output)
                    assert(os.isfile(full), "reference: the command did not make " .. full)
                    made[full] = true
                end
            else
                table.insert(remaining, edge)
            end
        end
        assert(#remaining < #pending, "reference: no command can run; its inputs are missing, first: " .. (function ()
            for _, input in ipairs(pending[1].inputs) do
                if not os.isfile(resolve(input)) then
                    return resolve(input)
                end
            end
            return "?"
        end)())
        pending = remaining
    end
    return made
end

local function run(build, real, placeholder, icu, stage, pyver, shim_log)
    local commit = io.readfile(path.join(os.scriptdir(), "..", "..", "packages", "w", "webkit", "xmake.lua")):match('local commit = "(%x+)"')
    assert(commit, "reference: no WebKit commit in the recipe")
    local text = io.readfile(path.join(build, "build.ninja"))
    local rewritten = text:gsub(placeholder:gsub("%p", "%%%0"), (real:gsub("%%", "%%%%")))
    local edges, variables = parse(rewritten)
    local picked = selected(edges, real)
    assert(#picked > 0, "reference: no custom command runs " .. real)
    execute(build, picked, variables)
    local rows = {}
    local count = 0
    for _, edge in ipairs(picked) do
        local inputs, outputs = {}, {}
        for _, input in ipairs(edge.inputs) do
            local full = expand(input, variables)
            full = path.is_absolute(full) and full or path.join(build, full)
            table.insert(inputs, string.format('{"path": %s, "sha256": %s}', json_string(full), json_string(digest(full))))
        end
        for _, output in ipairs(edge.outputs) do
            local full = expand(output, variables)
            full = path.is_absolute(full) and full or path.join(build, full)
            local relative = path.relative(full, build)
            table.insert(outputs, string.format('{"path": %s, "sha256": %s}', json_string(relative), json_string(digest(full))))
            local target = path.join(stage, relative)
            os.mkdir(path.directory(target))
            os.cp(full, target)
            count = count + 1
        end
        table.insert(rows, string.format('{"script": %s, "rule": %s, "command": %s, "inputs": %s, "outputs": %s}',
            json_string(script_of(edge.vars.COMMAND, real)), json_string(edge.rule), json_string(expand(edge.vars.COMMAND, variables)),
            json_array(inputs, "    "), json_array(outputs, "    ")))
    end
    for _, file in ipairs(os.files(path.join(icu, "*"))) do
        local target = path.join(stage, "icu", path.filename(file))
        os.mkdir(path.directory(target))
        os.cp(file, target)
    end
    local shim = shim_log and os.isfile(shim_log) and io.readfile(shim_log) or ""
    local manifest = table.concat({
        "{",
        '  "webkit_commit": ' .. json_string(commit:sub(1, 7)) .. ",",
        '  "python": ' .. json_string(pyver) .. ",",
        '  "interpreter": ' .. json_string(real) .. ",",
        '  "configure_interpreter_calls": ' .. json_string(shim) .. ",",
        '  "edges": ' .. json_array(rows, "  ") .. ",",
        '  "icu": ' .. json_string(icu)
    }, "\n") .. "\n}"
    io.writefile(path.join(stage, "manifest.json"), manifest .. "\n")
    print("reference: %d generator edges, %d outputs, manifest written to %s", #picked, count, path.join(stage, "manifest.json"))
end

function main(command, ...)
    local args = {...}
    if command == "plan" then
        plan(args[1], args[2])
    elseif command == "run" then
        run(args[1], args[2], args[3], args[4], args[5], args[6], args[7])
    else
        raise("usage: reference.lua plan <build.ninja> <interpreter> | run <build> <real interpreter> <placeholder> <icu dir> <stage> <python version> [shim log]")
    end
end
