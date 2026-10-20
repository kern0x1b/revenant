local pyish = import("pyish", {rootdir = path.join(os.scriptdir(), "..", "..", "common"), anonymous = true})

local function read(file)
    local out = {}
    for line in pyish.lines_of(file) do
        if pyish.strip(line) ~= "" and line:sub(1, 7) ~= "commit:" then
            table.insert(out, line)
        end
    end
    return out
end

function compare(release, port)
    local a, b = read(release), read(port)
    local bad = {}
    for i = 1, math.min(#a, #b) do
        if a[i] ~= b[i] then
            table.insert(bad, {a[i], b[i]})
        end
    end
    if #a ~= #b then
        print(string.format("compared: the release printed %d lines, the port %d", #a, #b))
        for _ = 1, math.abs(#a - #b) do
            table.insert(bad, {"<missing>", ">"})
        end
    end
    print(string.format("compared: %d lines", math.min(#a, #b)))
    if #bad > 0 then
        print(string.format("MISMATCHES: %d", #bad))
        for _, pair in ipairs(bad) do
            print(string.format("  release: %s\n  port:    %s", pair[1], pair[2]))
        end
        return 1
    end
    print("MISMATCHES: 0")
    return 0
end

function same(first, second)
    return pyish.same_list(read(first), read(second)) and 0 or 1
end

function main(command, ...)
    if command == "compare" then
        os.exit(compare(...))
    elseif command == "same" then
        os.exit(same(...))
    end
    io.stderr:write("usage: compare.lua compare <release> <port> | same <first> <second>\n")
    os.exit(2)
end
