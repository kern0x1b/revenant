local pyish = import("pyish", {rootdir = path.join(os.scriptdir(), "..", "..", "common"), anonymous = true})

local function read(file)
    local cases, name, values = {}, nil, {}
    local skipped, defaults = {}, {}
    local function close()
        if name then
            cases[name] = values
        end
        name, values = nil, {}
    end
    for line in pyish.lines_of(file) do
        local handled = line:sub(1, 6) == "image "
        if not handled and pyish.find_plain(line, "NOT COMPARED") then
            close()
            local parts = pyish.split(line)
            table.insert(skipped, {#parts > 1 and parts[2] or "?", pyish.strip(line)})
            handled = true
        end
        if not handled then
            local parts0 = pyish.split(line)
            if #parts0 >= 2 and not pyish.isdigit(parts0[2]) and line:sub(1, 1) ~= " "
                and line:sub(1, 10) ~= "compared: " and line:sub(1, 7) ~= "device " then
                close()
                table.insert(defaults, pyish.strip(line))
                handled = true
            end
        end
        if not handled and (pyish.find_plain(line, "defaults") or line:sub(1, 13) == "relu-defaults") then
            close()
            table.insert(defaults, pyish.strip(line))
            handled = true
        end
        if not handled and line:sub(1, 10) == "compared: " then
            close()
            handled = true
        end
        if not handled then
            local parts = pyish.split(line)
            if #parts == 2 and pyish.isdigit(parts[2]) then
                close()
                name, values = parts[1], {}
            elseif #parts > 0 and name ~= nil then
                local tail = parts
                if tail[1]:sub(1, 2) == "ch" then
                    table.remove(tail, 1)
                end
                if tail[1] and tail[1]:sub(1, 3) == "row" then
                    table.remove(tail, 1)
                end
                for _, v in ipairs(tail) do
                    table.insert(values, pyish.float(v))
                end
            end
        end
    end
    close()
    return cases, skipped, defaults
end

local function distinct_names(entries)
    local seen = {}
    for _, e in ipairs(entries) do
        seen[e[1]] = true
    end
    return pyish.sorted_keys(seen)
end

local function named_lines(list)
    local out = {}
    for _, line in ipairs(list) do
        out[line:match("^%S+")] = line
    end
    return out
end

function compare(system_path, port_path, tolerance)
    tolerance = pyish.float(tolerance)
    local a, a_skipped, a_defaults = read(system_path)
    local b, b_skipped, b_defaults = read(port_path)
    if #a_skipped > 0 then
        print("the SYSTEM side refused a case, which is a harness defect:")
        for _, s in ipairs(a_skipped) do
            print(string.format("  system: %s: %s", s[1], s[2]))
        end
        return 1
    end
    if #b_skipped > 0 then
        print(string.format("the port refused %d case(s), which its rows say it does not carry:", #distinct_names(b_skipped)))
        for _, s in ipairs(b_skipped) do
            print(string.format("  port: %s: %s", s[1], s[2]))
        end
    end
    if next(a) == nil then
        print("the system answered no case at all: " .. io.readfile(system_path):sub(1, 200))
        return 1
    end
    local not_compared = distinct_names(b_skipped)
    local missing, extra = {}, {}
    for _, name in ipairs(pyish.sorted_keys(a)) do
        if b[name] == nil then
            table.insert(missing, name)
        end
    end
    for _, name in ipairs(pyish.sorted_keys(b)) do
        if a[name] == nil then
            table.insert(extra, name)
        end
    end
    if #extra > 0 then
        print("the port reached cases the system did not, which cannot be right: " .. pyish.list_repr(extra))
        return 1
    end
    if not pyish.same_list(missing, not_compared) then
        print("the port did not reach " .. pyish.list_repr(missing)
            .. ", which its own transcript does not name as NOT COMPARED and which its rows therefore say it does carry")
        return 1
    end
    if #missing == 0 then
        print("the port reached every case the system reached")
    else
        print("the port did not reach " .. pyish.list_repr(missing)
            .. ", which its own transcript names as NOT COMPARED and which is what its rows say it does not carry")
    end
    for _, s in ipairs(b_skipped) do
        print(string.format("  port: %s: %s", s[1], s[2]:sub(1, 90)))
    end
    local a_named, b_named = named_lines(a_defaults), named_lines(b_defaults)
    local bad = {}
    for name, line in pairs(a_named) do
        if b_named[name] ~= nil and line ~= b_named[name] then
            table.insert(bad, name)
        end
    end
    if #bad > 0 then
        table.sort(bad)
        print("the two runs disagree on a fresh kernel's defaults:")
        for _, name in ipairs(bad) do
            print("  system: " .. a_named[name])
            print("  port:   " .. b_named[name])
        end
        return 1
    end
    local shared, only_system = {}, {}
    for _, name in ipairs(pyish.sorted_keys(a_named)) do
        if b_named[name] ~= nil then
            table.insert(shared, name)
        else
            table.insert(only_system, name)
        end
    end
    if #only_system > 0 then
        print("the system measured a kernel the port did not build, which is its row's absence: " .. table.concat(only_system, ", "))
    end
    print(string.format("defaults: %d line(s) compared, agree exactly as text", #shared))
    for _, name in ipairs(shared) do
        print("  " .. a_named[name])
    end
    local port_count = 0
    for _ in pairs(b) do
        port_count = port_count + 1
    end
    print(string.format("cases: %d compared, %d expected absent, tolerance %g absolute or relative", port_count, #missing, tolerance))
    local failures = 0
    local worst = {}
    for _, name in ipairs(pyish.sorted_keys(b)) do
        local xs, ys = a[name], b[name]
        if #xs ~= #ys then
            print(string.format("  DIFFERS %-28s element count %d vs %d", name, #xs, #ys))
            failures = failures + 1
        else
            local used = 0.0
            for index = 1, #xs do
                local x, y = xs[index], ys[index]
                local scale = tolerance * pyish.pymax(1.0, math.abs(x), math.abs(y))
                local close = math.abs(x - y) <= scale
                used = pyish.pymax(used, math.abs(x - y) / scale)
                if not close then
                    print(string.format("  DIFFERS %-28s [%d] system %.9g port %.9g", name, index - 1, x, y))
                    failures = failures + 1
                    break
                end
            end
            table.insert(worst, {used, name})
        end
    end
    table.sort(worst, function(p, q)
        if p[1] ~= q[1] then
            return p[1] > q[1]
        end
        return p[2] > q[2]
    end)
    print("closest to the tolerance, as a fraction of it:")
    for i = 1, math.min(5, #worst) do
        print(string.format("  %-28s %.3g", worst[i][2], worst[i][1]))
    end
    print(string.format("differing cases: %d", failures))
    return failures > 0 and 1 or 0
end

function main(system_path, port_path, tolerance)
    os.exit(compare(system_path, port_path, tolerance))
end
