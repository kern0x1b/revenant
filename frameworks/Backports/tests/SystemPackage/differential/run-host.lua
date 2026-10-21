local process = import("process", {rootdir = path.join(os.scriptdir(), "..", ".."), anonymous = true})

local HERE = os.scriptdir()
local SEED = "20261014"
local AVAILABILITY = {"0.0.2", "0.0.3", "1.1.0", "1.1.1", "1.2.0", "1.2.1", "1.3.0", "1.3.1", "1.3.2", "1.4.0", "1.7.0", "199"}
local COMPAT = {"openat", "unlinkat", "fdopendir", "fstatat"}

local function must(status)
    if status ~= 0 then
        raise("a command exited with status %s", tostring(status))
    end
end

local function xcrun(argv, opt)
    return process.run("xcrun", argv, opt)
end

local function capture(program, argv, file)
    local status = process.run(program, argv, {stdout = file .. ".out", stderr = file .. ".err"})
    local stdout = os.isfile(file .. ".out") and io.readfile(file .. ".out") or ""
    local stderr = os.isfile(file .. ".err") and io.readfile(file .. ".err") or ""
    io.writefile(file, stdout .. stderr)
    os.rm(file .. ".out")
    os.rm(file .. ".err")
    return status
end

local function newlines(text)
    local _, count = text:gsub("\n", "")
    return count
end

local function listing(text)
    return table.concat(text, "\n") .. (#text > 0 and "\n" or "")
end

local function differences(left_text, right_text)
    local left, right = process.lines(left_text), process.lines(right_text)
    local out = {}
    for index = 1, math.max(#left, #right) do
        if left[index] ~= right[index] then
            if left[index] then
                table.insert(out, "< " .. left[index])
            end
            if right[index] then
                table.insert(out, "> " .. right[index])
            end
        end
    end
    return listing(out)
end

local function rows_of(text)
    local rows = {}
    for _, line in ipairs(process.lines(text)) do
        if line:startswith("row ") then
            table.insert(rows, line)
        end
    end
    return rows
end

function main(src, out, seed)
    seed = seed or SEED
    local compat = os.getenv("APPLE_COMPAT")
    if compat == nil or compat == "" then
        io.stderr:write("set APPLE_COMPAT to packages/a/apple-compat\n")
        os.exit(1)
    end
    assert(src and out, "usage: run-host.lua <swift-system source> <output folder> [seed]")
    src = path.absolute(src)
    out = path.absolute(out)
    compat = path.absolute(compat)
    local system = path.join(src, "Sources", "CSystem")
    os.mkdir(path.join(out, "run-apple"))
    os.mkdir(path.join(out, "run-ours"))

    local host = {}
    for _, name in ipairs({"shims", "csystem_port"}) do
        local object = path.join(out, name .. "-host.o")
        must(xcrun({"clang", "-c", path.join(system, name .. ".c"), "-I", path.join(system, "include"),
                    "-I", path.join(compat, "include"), "-o", object}))
        table.insert(host, object)
    end
    for _, name in ipairs(COMPAT) do
        local object = path.join(out, "compat-" .. name .. "-host.o")
        must(xcrun({"clang", "-c", path.join(compat, "src", name .. ".c"), "-I", path.join(compat, "include"), "-o", object}))
        table.insert(host, object)
    end

    local swifts = {}
    for _, file in ipairs(os.files(path.join(src, "Sources", "System", "**.swift"))) do
        if not file:find("/IORing/", 1, true) then
            table.insert(swifts, file)
        end
    end
    table.sort(swifts)
    local avail = {"-enable-experimental-feature", "AvailabilityMacro=System 0.0.1:macOS 10.10, iOS 6.1.3"}
    for _, version in ipairs(AVAILABILITY) do
        table.join2(avail, {"-enable-experimental-feature", "AvailabilityMacro=System " .. version .. ":macOS 10.10, iOS 6.1.3"})
    end
    must(xcrun(table.join({"swiftc", "-swift-version", "5", "-enable-experimental-feature", "Lifetimes",
                           "-I", path.join(system, "include"), "-I", path.join(compat, "include"),
                           "-D", "SYSTEM_PACKAGE_DARWIN", "-D", "SYSTEM_PACKAGE", "-module-name", "SystemUnderTest",
                           "-emit-library", "-emit-module", "-emit-module-path", path.join(out, "SystemUnderTest.swiftmodule"),
                           "-o", path.join(out, "libSystemUnderTest.dylib")}, host, avail, swifts)))

    local rows = {path.join(HERE, "main.swift"), path.join(HERE, "rows.swift"), path.join(HERE, "constants.swift")}
    local apple = path.join(out, "apple-prog")
    must(xcrun(table.join({"swiftc", "-swift-version", "5"}, rows, {"-o", apple})))
    local ours = path.join(out, "ours-prog")
    must(xcrun(table.join({"swiftc", "-swift-version", "5", "-D", "OURS", "-I", out, "-I", path.join(system, "include"),
                           "-L", out, "-lSystemUnderTest", "-Xlinker", "-rpath", "-Xlinker", out}, rows, {"-o", ours})))

    print("apple rc=" .. capture(apple, {path.join(out, "run-apple"), seed}, path.join(out, "apple.txt")))
    print("ours rc=" .. capture(ours, {path.join(out, "run-ours"), seed}, path.join(out, "ours.txt")))

    local apple_text = io.readfile(path.join(out, "apple.txt"))
    local ours_text = io.readfile(path.join(out, "ours.txt"))
    if apple_text == ours_text then
        print(string.format("DIFFERENTIAL: identical, %d lines", newlines(apple_text)))
    else
        local difference = differences(apple_text, ours_text)
        io.writefile(path.join(out, "diff.txt"), difference)
        print(string.format("DIFFERENTIAL: DIFFERENT, %d diff lines", newlines(difference)))
        os.exit(1)
    end

    local rows_apple, rows_ours = rows_of(apple_text), rows_of(ours_text)
    io.writefile(path.join(out, "rows-apple.txt"), listing(rows_apple))
    io.writefile(path.join(out, "rows-ours.txt"), listing(rows_ours))

    local names = {}
    for _, line in ipairs(rows_apple) do
        table.insert(names, line:match("^%S+%s+(%S+)"))
    end
    table.sort(names)
    local carried = process.lines(io.readfile(path.join(HERE, "carried-rows.txt")))
    local mismatch = differences(listing(names), listing(carried))
    if mismatch == "" then
        print(string.format("ROW NAMES: the %d rows are exactly carried-rows.txt", #names))
    else
        io.writefile(path.join(out, "rows-names.diff"), mismatch)
        print("ROW NAMES: DO NOT MATCH carried-rows.txt (see rows-names.diff)")
    end

    local same, different, skipped = 0, 0, 0
    for index = 1, math.max(#rows_apple, #rows_ours) do
        local apple_line = rows_apple[index] or ""
        local ours_line = rows_ours[index] or ""
        if (apple_line .. "\t" .. ours_line):find(" not%-exercised$") then
            skipped = skipped + 1
        elseif apple_line == ours_line then
            same = same + 1
        else
            different = different + 1
        end
    end
    print(string.format("ROWS: %d identical, %d different, %d not exercised on the host (reasons in run-apple/rows-detail.txt)",
                        same, different, skipped))

    local apple_detail, ours_detail = path.join(out, "run-apple", "rows-detail.txt"), path.join(out, "run-ours", "rows-detail.txt")
    if #rows_ours > 0 and os.isfile(apple_detail) and os.isfile(ours_detail) and io.readfile(apple_detail) == io.readfile(ours_detail) then
        print("ROWS detail: identical observations")
    else
        print("ROWS detail: observations differ (see run-*/rows-detail.txt)")
    end

    local run_compat = path.join(out, "run-compat")
    os.mkdir(path.join(run_compat, "sub"))
    io.writefile(path.join(run_compat, "a"), "hi\n")
    io.writefile(path.join(run_compat, "sub", "c"), "x\n")
    local objects = {}
    for _, name in ipairs(COMPAT) do
        local object = path.join(out, "compat-" .. name .. ".o")
        must(xcrun({"clang", "-c", "-I", path.join(compat, "include"), path.join(compat, "src", name .. ".c"), "-o", object}))
        table.insert(objects, object)
    end
    local test_object = path.join(out, "compat-test.o")
    must(xcrun({"clang", "-c", "-I", path.join(compat, "include"), path.join(HERE, "compat.c"), "-o", test_object}))
    local test_binary = path.join(out, "compat-test")
    must(xcrun(table.join({"clang"}, objects, {test_object, "-o", test_binary})))
    local status = capture(test_binary, {path.absolute(run_compat), seed}, path.join(out, "compat.txt"))
    local compat_text = io.readfile(path.join(out, "compat.txt"))
    print(string.format("compat rc=%d: %d fstatat same, %d different, %d unlinks gone", status,
                        process.count(compat_text, " same"), process.count(compat_text, "DIFFERENT"),
                        process.count(compat_text, "gone=1")))
end
