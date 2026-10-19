function charon()
    return path.directory(path.directory(path.directory(path.absolute(os.scriptdir()))))
end

function workspace()
    return import("workspace", {rootdir = path.join(charon(), "modules"), anonymous = true})
end

function stamp()
    return os.date("%Y%m%d-%H%M%S")
end

function lines(text)
    local all = {}
    for line in string.gmatch(text or "", "([^\n]*)\n") do
        table.insert(all, line)
    end
    local rest = string.match(text or "", "([^\n]+)$")
    if rest then
        table.insert(all, rest)
    end
    return all
end

function env(name)
    local value = os.getenv(name)
    if value and value ~= "" then
        return value
    end
end

function read(file)
    return os.isfile(file) and io.readfile(file) or ""
end

function text(all)
    return #all > 0 and table.concat(all, "\n") .. "\n" or ""
end

function matching(source, patterns)
    local kept = {}
    for _, line in ipairs(lines(source)) do
        for _, pattern in ipairs(patterns) do
            if string.find(line, pattern) then
                table.insert(kept, line)
                break
            end
        end
    end
    return kept
end

function except(source, patterns)
    local kept = {}
    for _, line in ipairs(lines(source)) do
        local dropped = false
        for _, pattern in ipairs(patterns) do
            if string.find(line, pattern) then
                dropped = true
                break
            end
        end
        if not dropped then
            table.insert(kept, line)
        end
    end
    return kept
end

function range(source, first, last)
    local kept = {}
    local inside = false
    for _, line in ipairs(lines(source)) do
        if inside then
            table.insert(kept, line)
            inside = not string.find(line, last)
        elseif string.find(line, first) then
            table.insert(kept, line)
            inside = true
        end
    end
    return kept
end

local function edits(a, b)
    local first = 1
    while first <= #a and first <= #b and a[first] == b[first] do
        first = first + 1
    end
    local last_a, last_b = #a, #b
    while last_a >= first and last_b >= first and a[last_a] == b[last_b] do
        last_a = last_a - 1
        last_b = last_b - 1
    end
    local rows, columns = last_a - first + 1, last_b - first + 1
    local width = columns + 2
    local common = {}
    for i = rows + 1, 1, -1 do
        for j = columns + 1, 1, -1 do
            local value = 0
            if i <= rows and j <= columns then
                if a[first + i - 1] == b[first + j - 1] then
                    value = common[(i + 1) * width + j + 1] + 1
                else
                    value = math.max(common[(i + 1) * width + j], common[i * width + j + 1])
                end
            end
            common[i * width + j] = value
        end
    end
    local script = {}
    for k = 1, first - 1 do
        table.insert(script, {kind = " ", line = a[k], a = k, b = k})
    end
    local i, j = 1, 1
    while i <= rows or j <= columns do
        if i <= rows and j <= columns and a[first + i - 1] == b[first + j - 1] then
            table.insert(script, {kind = " ", line = a[first + i - 1], a = first + i - 1, b = first + j - 1})
            i, j = i + 1, j + 1
        elseif i <= rows and (j > columns or common[(i + 1) * width + j] >= common[i * width + j + 1]) then
            table.insert(script, {kind = "-", line = a[first + i - 1], a = first + i - 1})
            i = i + 1
        else
            table.insert(script, {kind = "+", line = b[first + j - 1], b = first + j - 1})
            j = j + 1
        end
    end
    for k = 1, #a - last_a do
        table.insert(script, {kind = " ", line = a[last_a + k], a = last_a + k, b = last_b + k})
    end
    return script
end

local function hunk(script, from, to)
    local out = {}
    local start_a, start_b, count_a, count_b
    local before_a, before_b = 0, 0
    for k = 1, from - 1 do
        before_a = script[k].a or before_a
        before_b = script[k].b or before_b
    end
    for k = from, to do
        local step = script[k]
        if step.a then
            start_a = start_a or step.a
            count_a = (count_a or 0) + 1
        end
        if step.b then
            start_b = start_b or step.b
            count_b = (count_b or 0) + 1
        end
        table.insert(out, step.kind .. step.line)
    end
    local function span(start, size, before)
        if not size then
            return string.format("%d,0", before)
        end
        return size == 1 and tostring(start) or string.format("%d,%d", start, size)
    end
    table.insert(out, 1, string.format("@@ -%s +%s @@", span(start_a, count_a, before_a), span(start_b, count_b, before_b)))
    return out
end

function unified(a, b, name_a, name_b)
    local script = edits(lines(a), lines(b))
    local changed = {}
    for k, step in ipairs(script) do
        if step.kind ~= " " then
            table.insert(changed, k)
        end
    end
    if #changed == 0 then
        return ""
    end
    local out = {"--- " .. name_a, "+++ " .. name_b}
    local k = 1
    while k <= #changed do
        local from = math.max(1, changed[k] - 3)
        local stop = changed[k]
        while k < #changed and changed[k + 1] - stop <= 7 do
            k = k + 1
            stop = changed[k]
        end
        table.join2(out, hunk(script, from, math.min(#script, stop + 3)))
        k = k + 1
    end
    return text(out)
end

function tail(file, count)
    local all = lines(read(file))
    return table.concat(all, "\n", math.max(1, #all - count + 1), #all)
end

function count(text, pattern)
    local found = 0
    for _, line in ipairs(lines(text)) do
        if string.find(line, pattern) then
            found = found + 1
        end
    end
    return found
end

function plain(text)
    return (string.gsub(text, "\27%[[%d;]*m", ""))
end

function copy(from, names, to)
    os.mkdir(to)
    for _, name in ipairs(names) do
        os.cp(path.join(from, name), path.join(to, name))
    end
end

function spawn(opt)
    local file = io.open(opt.log, "w")
    local status = os.execv(os.programfile(), opt.argv, {curdir = opt.curdir, envs = opt.envs, stdout = file,
                                                         stderr = file, try = true})
    file:close()
    return status
end

function required(opt)
    if spawn(opt) ~= 0 then
        raise("%s did not %s; %s says why\n%s", opt.what, opt.verb, opt.log, tail(opt.log, opt.tail or 20))
    end
end

function device(launch)
    local found
    for _, line in ipairs(lines(launch)) do
        found = string.match(line, ".*emulator log is (/[^ ]*)/emulator%.log") or found
    end
    return found
end

function exit_field(folder)
    local verdict = folder and path.join(folder, "verdict.json")
    if not verdict or not os.isfile(verdict) then
        return ""
    end
    local fields = {}
    for _, line in ipairs(lines(io.readfile(verdict))) do
        for field in string.gmatch(line, "\"exit\":{[^}]*}") do
            table.insert(fields, field)
        end
    end
    return table.concat(fields, "\n")
end

function clean_exit(field)
    return string.find(field, "\"status\":0", 1, true) ~= nil and string.find(field, "\"signal\":0", 1, true) ~= nil
end

function accept_launch(status, launch, report)
    if status == 0 then
        return
    end
    local folder = device(launch)
    local field = exit_field(folder)
    if not clean_exit(field) then
        raise("the launch exited %d and the application's exit is not clean: %s/verdict.json", status, folder or "")
    end
    print("the launch status %d is %s; the application's own exit is clean (%s)", status, report, field)
end

function options(arguments, known)
    local opt = {}
    local i = 1
    while i <= #arguments do
        local argument = arguments[i]
        local kind = known[argument]
        if kind == "value" then
            if arguments[i + 1] == nil then
                raise("%s needs a value", argument)
            end
            opt[argument:sub(3)] = arguments[i + 1]
            i = i + 2
        elseif kind == "flag" then
            opt[argument:sub(3)] = true
            i = i + 1
        else
            raise("unknown argument: %s", argument)
        end
    end
    return opt
end

function guard(work, ...)
    local arguments = {...}
    try {
        function ()
            work(table.unpack(arguments))
        end,
        catch {
            function (errors)
                io.stdout:flush()
                io.stderr:write(tostring(errors), "\n")
                os.exit(1)
            end
        }
    }
end
