local pyish = import("pyish", {rootdir = path.join(os.scriptdir(), "..", "..", "common"), anonymous = true})

local function read(file)
    local cases, name, values, skipped = {}, nil, {}, {}
    for line in pyish.lines_of(file) do
        local done = false
        if line:sub(1, 6) == "image " then
            done = true
        elseif pyish.find_plain(line, " NOT COMPARED:") then
            if name then cases[name] = values end
            name, values = nil, {}
            local parts = pyish.split(line)
            local why = pyish.strip(line:match("NOT COMPARED:(.*)$") or "")
            table.insert(skipped, {#parts > 1 and parts[2] or "?", why})
            done = true
        elseif line:sub(1, 10) == "compared: " then
            if name then cases[name] = values end
            name, values = nil, {}
            done = true
        end
        if not done then
            local parts = pyish.split(line)
            if #parts == 2 and pyish.isdigit(parts[2]) then
                if name then cases[name] = values end
                name, values = parts[1], {}
            elseif #parts > 0 and name ~= nil then
                for _, v in ipairs(parts) do
                    table.insert(values, pyish.float(v))
                end
            end
        end
    end
    if name then cases[name] = values end
    return cases, skipped
end

local function sorted_keys(map)
    local keys = {}
    for k in pairs(map) do
        table.insert(keys, k)
    end
    table.sort(keys)
    return keys
end

function compare(system_path, port_path, tolerance)
    tolerance = pyish.float(tolerance)
    local a, a_skipped = read(system_path)
    local b, b_skipped = read(port_path)
    if #a_skipped > 0 or #b_skipped > 0 then
        local names = {}
        for _, s in ipairs(a_skipped) do names[s[1]] = true end
        for _, s in ipairs(b_skipped) do names[s[1]] = true end
        print(string.format("cases the harness refused to compare: %d", #sorted_keys(names)))
        for _, pair in ipairs({{"system", a_skipped}, {"port", b_skipped}}) do
            for _, s in ipairs(pair[2]) do
                print(string.format("  %s side: %s: %s", pair[1], s[1], s[2]))
            end
        end
        print("a case that did not run is not a case that passed; this comparison is red")
        return 1
    end
    if next(a) == nil then
        local err = os.isfile(system_path .. ".err") and io.readfile(system_path .. ".err"):sub(1, 200) or ""
        print("the system answered no case at all: " .. io.readfile(system_path):sub(1, 200) .. " " .. err)
        return 1
    end
    local a_keys, b_keys = sorted_keys(a), sorted_keys(b)
    if table.concat(a_keys, "\0") ~= table.concat(b_keys, "\0") then
        print(string.format("the two runs reached different cases: system %s, port %s",
            pyish.list_repr(a_keys), pyish.list_repr(b_keys)))
        return 1
    end
    print(string.format("cases: %d, tolerance %g absolute or relative", #a_keys, tolerance))
    local bad = 0
    local worst = {}
    for _, name in ipairs(a_keys) do
        local exact = name:sub(1, 8) == "pooling-"
        local limit = exact and 0.0 or tolerance
        local used = 0.0
        local xs, ys = a[name], b[name]
        for index = 1, math.min(#xs, #ys) do
            local x, y = xs[index], ys[index]
            local close
            if limit == 0.0 then
                close = x == y
                used = close and 0.0 or math.huge
            else
                local scale = limit * pyish.pymax(1.0, math.abs(x), math.abs(y))
                close = math.abs(x - y) <= scale
                local ratio = math.abs(x - y) / scale
                used = pyish.pymax(used, ratio)
            end
            if not close then
                print(string.format("  DIFFERS %-28s [%d] system %.9g port %.9g", name, index - 1, x, y))
                bad = bad + 1
                break
            end
        end
        if not exact then
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
