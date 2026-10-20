local pyish = import("pyish", {rootdir = path.join(os.scriptdir(), "..", "..", "common"), anonymous = true})

local function cases(file)
    local out, name, values = {}, nil, {}
    for line in pyish.lines_of(file) do
        if line:sub(1, 6) == "image " or pyish.find_plain(line, " NOT COMPARED:") or line:sub(1, 10) == "compared: " then
            if name then out[name] = values end
            name, values = nil, {}
        else
            local parts = pyish.split(line)
            if #parts == 2 and pyish.isdigit(parts[2]) then
                if name then out[name] = values end
                name, values = parts[1], {}
            elseif #parts > 0 and name ~= nil then
                for _, v in ipairs(parts) do
                    table.insert(values, v)
                end
            end
        end
    end
    if name then out[name] = values end
    return out
end

local function same_list(a, b)
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

local function measure(system, port)
    local identical, worst, compared = {}, 0.0, 0
    for name, a in pairs(system) do
        local b = port[name]
        if b ~= nil and #a == #b then
            compared = compared + 1
            if same_list(a, b) then
                identical[name] = true
            else
                for i = 1, #a do
                    local x, y = a[i], b[i]
                    if x ~= y then
                        local fx, fy = pyish.float(x), pyish.float(y)
                        if fx ~= 0.0 and fy ~= 0.0 then
                            worst = pyish.pymax(worst, math.abs(fx - fy) / pyish.pymax(math.abs(fx), math.abs(fy)))
                        end
                    end
                end
            end
        end
    end
    return identical, worst, compared
end

local function keys_of(set)
    local out = {}
    for k in pairs(set) do
        table.insert(out, k)
    end
    table.sort(out)
    return out
end

local function number_at(text, i)
    if not text:match("^%d", i) then
        return nil
    end
    local j = i + 1
    local frac = text:match("^%.%d+", j)
    if frac then
        j = j + #frac
    end
    local exp = text:match("^e[%-+]?%d+", j)
    if exp then
        j = j + #exp
    end
    return text:sub(i, j - 1)
end

local function first_number_after(text, pattern)
    local init = 1
    while true do
        local s, _, pos = text:find(pattern, init)
        if not s then
            return nil
        end
        local found = number_at(text, pos)
        if found then
            return found
        end
        init = s + 1
    end
end

function check(rundir, page)
    local system_path, port_path = rundir .. "/system.txt", rundir .. "/port.txt"
    for _, p in ipairs({system_path, port_path}) do
        if not os.isfile(p) then
            io.stderr:write(string.format("cnn page-check: %s is not there, so nothing was measured and this check cannot pass\n", p))
            return 2
        end
    end
    local system, port = cases(system_path), cases(port_path)
    if next(system) == nil then
        io.stderr:write(string.format("cnn page-check: %s carries no case, so nothing was measured\n", system_path))
        return 2
    end
    local identical, worst, compared = measure(system, port)
    local text = io.readfile(page)
    local identical_keys = keys_of(identical)
    print(string.format("measured over %s: %d cases, %d bit-identical, largest relative distance %.3g",
        rundir, compared, #identical_keys, worst))
    print("  bit-identical: " .. table.concat(identical_keys, ", "))

    local bad, claims = 0, 0

    local listed = text:match("%*%*Five of the six cases are bit%-identical%*%*, and they are the run's own list: (.-)\n`batch%-normalization` is")
    if not listed then
        print("  FAIL  the page does not say which cases are bit-identical, in the form this check reads")
        return 1
    end
    claims = claims + 1
    local said, said_names = {}, {}
    for name in listed:gmatch("`([^`]+)`") do
        if not said[name] then
            said[name] = true
            table.insert(said_names, name)
        end
    end
    table.sort(said_names)
    local same = #said_names == #identical_keys
    if same then
        for i, name in ipairs(said_names) do
            if identical_keys[i] ~= name then
                same = false
                break
            end
        end
    end
    if same then
        print("  ok    the page names exactly the run's bit-identical cases")
    else
        print(string.format("  FAIL  the page names %s and the run's bit-identical cases are %s",
            table.concat(said_names, ", "), table.concat(identical_keys, ", ")))
        bad = bad + 1
    end
    for _, name in ipairs(said_names) do
        if not identical[name] then
            print(string.format("       the page calls %s bit-identical and the transcript says otherwise", name))
        end
    end

    local distance = first_number_after(text, "largest%s+distance anywhere in the [%w_%-]+ cases is%s+()")
    claims = claims + 1
    if not distance then
        print("  FAIL  the page quotes no largest distance, so this check examined nothing about it")
        bad = bad + 1
    else
        local said_value = tonumber(distance)
        if math.abs(said_value - worst) <= 0.02 * worst then
            print(string.format("  ok    the page's largest distance %.3g is what the transcripts carry (%.3g)", said_value, worst))
        else
            print(string.format("  FAIL  the page says %.3g and the transcripts carry %.3g", said_value, worst))
            bad = bad + 1
        end
    end

    local count
    for line in io.lines(page) do
        count = count or line:match("^%s*cases: (%d+), tolerance")
    end
    claims = claims + 1
    if not count then
        print("  FAIL  the page pastes no `cases: N, tolerance …` line, so this check examined nothing about the case count")
        bad = bad + 1
    else
        local said_cases = math.tointeger(tonumber(count))
        if said_cases == compared then
            print(string.format("  ok    the page's case count %d is what the transcripts carry", said_cases))
        else
            print(string.format("  FAIL  the page says `cases: %d` and the transcripts carry %d cases", said_cases, compared))
            bad = bad + 1
        end
    end

    print(string.format("%d claim(s) checked, %d wrong", claims, bad))
    return bad > 0 and 1 or 0
end

function main(...)
    local argv = {...}
    if #argv ~= 2 then
        io.stderr:write("usage: page-check.lua <run-dir> <page>\n")
        os.exit(2)
    end
    os.exit(check(argv[1], argv[2]))
end
