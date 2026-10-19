-- discover_tests.lua: parses the test files of the OpenCombine test suite and writes Tests/LinuxMain.swift from them.
--
--     xmake l utils/discover_tests.lua [WORKDIR]
--
-- WORKDIR is the root of the OpenCombine Swift package; it defaults to the current directory.
--
-- This uses plain string matching because the regular expressions of the Python this replaces need alternation and
-- optional groups, which Lua patterns do not have. Each regex is kept in a comment above the code that matches it.
-- Two things differ from the Python: the test files are visited in path order (Python's glob order is the file
-- system's), and a condition line whose "//" comes after a line break is not matched (no test file has one).

-- the position of the first character after the whitespace that starts at i
local function skip_space(s, i)
    local _, last = string.find(s, "^%s*", i)
    return last + 1
end

-- func\s*(test\w+)\s*\(\s*\)\s*(async\s*)?(?:throws\s*)?{ , matched at the "func" at p: the test name, whether it is
-- async, and the position after its "{", or nil when the text at p is not such a declaration
local function test_at(s, p)
    local i = skip_space(s, p + 4)
    local word = string.match(s, "^[%w_]+", i) or ""
    if #word <= 4 or string.sub(word, 1, 4) ~= "test" then
        return nil
    end
    i = skip_space(s, i + #word)
    if string.sub(s, i, i) ~= "(" then
        return nil
    end
    i = skip_space(s, i + 1)
    if string.sub(s, i, i) ~= ")" then
        return nil
    end
    i = skip_space(s, i + 1)
    local is_async = string.sub(s, i, i + 4) == "async"
    if is_async then
        i = skip_space(s, i + 5)
    end
    if string.sub(s, i, i + 5) == "throws" then
        i = skip_space(s, i + 6)
    end
    if string.sub(s, i, i) ~= "{" then
        return nil
    end
    return word, is_async, i + 1
end

-- every test method of the file, in order of appearance: the matches of test_at, found the way re.finditer finds them
local function test_methods(s)
    local tests = {}
    local pos = 1
    while true do
        local p = string.find(s, "func", pos, true)
        if not p then
            break
        end
        local name, is_async, after = test_at(s, p)
        if name then
            tests[#tests + 1] = {name = name, is_async = is_async}
            pos = after
        else
            pos = p + 1
        end
    end
    return tests
end

-- the position of the last "//" of the line that is followed by TEST_DISCOVERY_CONDITION and the end of the line, or nil
local function condition_marker(line)
    local found = nil
    local at = string.find(line, "//", 1, true)
    while at do
        if string.match(string.sub(line, at + 2), "^%s*TEST_DISCOVERY_CONDITION%s*$") then
            found = at
        end
        at = string.find(line, "//", at + 1, true)
    end
    return found
end

-- ^#if (.+)\s*\/\/\s*TEST_DISCOVERY_CONDITION\s*$ , on the first line it matches: the condition, or nil. The group is
-- greedy, so it runs to the last "//" that the rest of the line allows, and it keeps the spaces before that "//".
local function discovery_condition(s)
    for line in string.gmatch(s .. "\n", "([^\n]*)\n") do
        if string.sub(line, 1, 4) == "#if " then
            local marker = condition_marker(line)
            if marker and marker > 5 then
                return string.sub(line, 5, marker - 1)
            end
        end
    end
    return nil
end

function main(...)
    local workdir = ({...})[1] or os.curdir()
    local tests_dir = path.join(workdir, "Tests")

    local suites = os.dirs(path.join(tests_dir, "OpenCombineTests", "*"))
    table.sort(suites)
    local test_files = {}
    for _, suite in ipairs(suites) do
        for _, file in ipairs(os.files(path.join(suite, "*Tests.swift"))) do
            test_files[#test_files + 1] = file
        end
    end
    table.sort(test_files)

    local out = {"import XCTest\n\n@testable import OpenCombineTests\n\nvar tests = [XCTestCaseEntry]()\n\n"}
    for _, file in ipairs(test_files) do
        local tests = test_methods(io.readfile(file))
        if #tests > 0 then
            -- the stem of the file: its name without ".swift"
            local stem = string.sub(path.filename(file), 1, -7)
            local condition = discovery_condition(io.readfile(file))
            if condition then
                out[#out + 1] = "#if " .. condition .. "\n"
            end
            out[#out + 1] = "let allTests_" .. stem .. " = [\n"
            for _, test in ipairs(tests) do
                if test.is_async then
                    out[#out + 1] = '    ("' .. test.name .. '", asyncTest(' .. stem .. "." .. test.name .. ")),\n"
                else
                    out[#out + 1] = '    ("' .. test.name .. '", ' .. stem .. "." .. test.name .. "),\n"
                end
            end
            out[#out + 1] = "]\n"
            out[#out + 1] = "tests.append(testCase(allTests_" .. stem .. "))\n"
            if condition then
                out[#out + 1] = "#endif\n"
            end
            out[#out + 1] = "\n"
        end
    end
    out[#out + 1] = "XCTMain(tests)"

    io.writefile(path.join(tests_dir, "LinuxMain.swift"), table.concat(out))
end
