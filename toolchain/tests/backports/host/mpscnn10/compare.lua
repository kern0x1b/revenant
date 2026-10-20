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
        if not handled then
            local parts0 = pyish.split(line)
            if #parts0 >= 2 and not pyish.isdigit(parts0[2]) and line:sub(1, 1) ~= " " and line:sub(1, 10) ~= "compared: " then
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
        if not handled and pyish.find_plain(line, " NOT COMPARED:") then
            close()
            local parts = pyish.split(line)
            table.insert(skipped, {#parts > 1 and parts[2] or "?", pyish.strip(line:match("NOT COMPARED:(.*)$") or "")})
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

function compare(system_path, port_path, tolerance)
    tolerance = pyish.float(tolerance)
    local a, a_skipped, a_defaults = read(system_path)
    local b, b_skipped, b_defaults = read(port_path)
    if #a_skipped > 0 or #b_skipped > 0 then
        local names = {}
        for _, s in ipairs(a_skipped) do names[s[1]] = true end
        for _, s in ipairs(b_skipped) do names[s[1]] = true end
        print(string.format("cases the harness refused to compare: %d", #pyish.sorted_keys(names)))
        for _, pair in ipairs({{"system", a_skipped}, {"port", b_skipped}}) do
            for _, s in ipairs(pair[2]) do
                print(string.format("  %s side: %s: %s", pair[1], s[1], s[2]))
            end
        end
        print("a case that did not run is not a case that passed; this comparison is red")
        return 1
    end
    if next(a) == nil then
        print("the system answered no case at all: " .. io.readfile(system_path):sub(1, 200))
        return 1
    end
    local a_keys, b_keys = pyish.sorted_keys(a), pyish.sorted_keys(b)
    if table.concat(a_keys, "\0") ~= table.concat(b_keys, "\0") then
        print(string.format("the two runs reached different cases: system %s, port %s",
            pyish.list_repr(a_keys), pyish.list_repr(b_keys)))
        return 1
    end
    if not pyish.same_list(a_defaults, b_defaults) then
        print("the two runs disagree on a fresh kernel's defaults:")
        for _, line in ipairs(a_defaults) do
            if not pyish.contains(b_defaults, line) then
                print("  system only: " .. line)
            end
        end
        for _, line in ipairs(b_defaults) do
            if not pyish.contains(a_defaults, line) then
                print("  port only:   " .. line)
            end
        end
        return 1
    end
    print(string.format("defaults: %d lines agree exactly, as text", #a_defaults))
    for _, line in ipairs(a_defaults) do
        print("  " .. line)
    end
    print(string.format("cases: %d, tolerance %g absolute or relative", #a_keys, tolerance))
    local bad = 0
    local worst = {}
    for _, name in ipairs(a_keys) do
        local xs, ys = a[name], b[name]
        if #xs ~= #ys then
            print(string.format("  DIFFERS %-28s element count %d vs %d", name, #xs, #ys))
            bad = bad + 1
        else
            local used = 0.0
            for index = 1, #xs do
                local x, y = xs[index], ys[index]
                local scale = tolerance * pyish.pymax(1.0, math.abs(x), math.abs(y))
                local close = math.abs(x - y) <= scale
                used = pyish.pymax(used, math.abs(x - y) / scale)
                if not close then
                    print(string.format("  DIFFERS %-28s [%d] system %.9g port %.9g", name, index - 1, x, y))
                    bad = bad + 1
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
    print(string.format("differing cases: %d", bad))
    return bad > 0 and 1 or 0
end

function main(system_path, port_path, tolerance)
    os.exit(compare(system_path, port_path, tolerance))
end
