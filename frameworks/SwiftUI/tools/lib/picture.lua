local STATUS_BAR_POINTS = 20
local SPREAD_FACTOR = 2
local TOLERANCE_FLOOR = 1.0

function tool()
    local source = path.join(os.projectdir(), "frameworks", "SwiftUI", "tools", "lib", "picture_diff.swift")
    local binary = path.join(os.projectdir(), "build", "tools", "picture-diff-" .. hash.sha256(source):sub(1, 12))
    if not os.isfile(binary) then
        os.mkdir(path.directory(binary))
        os.vrunv("swiftc", {"-O", source, "-o", binary})
    end
    return binary
end

function masks(height)
    local bar = string.format("%.4f", STATUS_BAR_POINTS / height)
    return {"0.44,0,0.56," .. bar, "0.78,0,1," .. bar}
end

function compare(reference, candidate, height)
    local output = os.iorunv(tool(), table.join({reference, candidate}, masks(height)))
    local mean = tonumber(output:match("mean=([%d%.]+)"))
    if not mean then
        raise("picture-diff printed %s", output)
    end
    return mean, output:match("box=(%S+)")
end

function spread(captures, height)
    local largest = 0
    for i = 1, #captures do
        for j = i + 1, #captures do
            largest = math.max(largest, (compare(captures[i], captures[j], height)))
        end
    end
    return largest, math.max(SPREAD_FACTOR * largest, TOLERANCE_FLOOR)
end

function judge(reference, candidate, height, tolerance)
    local mean, box = compare(reference, candidate, height)
    if mean > tolerance then
        return false, mean, string.format("the difference %.4f is above the tolerance %.4f; the changed region is %s", mean, tolerance, box)
    end
    return true, mean, string.format("the difference %.4f is within the tolerance %.4f", mean, tolerance)
end

function read_tolerances(file)
    local tolerances = {}
    if os.isfile(file) then
        for name, value in io.readfile(file):gmatch("(%S+)%s+(%S+)") do
            tolerances[name] = tonumber(value)
        end
    end
    return tolerances
end

function sheet(output, columns, entries)
    local arguments = {"sheet", output, tostring(columns)}
    table.join2(arguments, entries)
    os.mkdir(path.directory(output))
    os.vrunv(tool(), arguments)
end

function tree_difference(reference, candidate)
    if io.readfile(reference, {encoding = "binary"}) == io.readfile(candidate, {encoding = "binary"}) then
        return 0, ""
    end
    local scratch = os.tmpfile()
    local file = io.open(scratch, "w")
    os.execv("diff", {"-u", reference, candidate}, {stdout = file, try = true})
    file:close()
    local diff = io.readfile(scratch)
    os.tryrm(scratch)
    local changed = 0
    for line in diff:gmatch("[^\n]+") do
        local first = line:sub(1, 1)
        if (first == "+" or first == "-") and line:sub(1, 3) ~= "+++" and line:sub(1, 3) ~= "---" then
            changed = changed + 1
        end
    end
    return math.max(changed, 1), diff
end

function read_screen(file)
    if os.isfile(file) then
        return tonumber(io.readfile(file):match("%d+"))
    end
end

function write_screen(file, height)
    os.mkdir(path.directory(file))
    io.writefile(file, tostring(height) .. "\n")
end

function write_tolerances(file, tolerances)
    local lines = {}
    for _, name in ipairs(table.orderkeys(tolerances)) do
        table.insert(lines, string.format("%s %.4f", name, tolerances[name]))
    end
    os.mkdir(path.directory(file))
    io.writefile(file, table.concat(lines, "\n") .. "\n")
end
