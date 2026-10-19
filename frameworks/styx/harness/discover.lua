local function skip_space(s, i)
    local _, last = s:find("^%s*", i)
    return last + 1
end

local function test_at(s, p)
    local line = s:sub(1, p - 1):match("[^\n]*$")
    if line:find("//", 1, true) then
        return nil
    end
    local i = skip_space(s, p + 4)
    local word = s:match("^[%w_]+", i) or ""
    if #word <= 4 or word:sub(1, 4) ~= "test" then
        return nil
    end
    i = skip_space(s, i + #word)
    if s:sub(i, i) ~= "(" then
        return nil
    end
    i = skip_space(s, i + 1)
    if s:sub(i, i) ~= ")" then
        return nil
    end
    i = skip_space(s, i + 1)
    local async = s:sub(i, i + 4) == "async"
    if async then
        i = skip_space(s, i + 5)
    end
    if s:sub(i, i + 5) == "throws" then
        i = skip_space(s, i + 6)
    end
    if s:sub(i, i) ~= "{" then
        return nil
    end
    return word, async, i + 1
end

local function tests_of(s)
    local tests = {}
    local pos = 1
    while true do
        local p = s:find("func", pos, true)
        if not p then
            break
        end
        local name, async, after = test_at(s, p)
        if name then
            if not async then
                table.insert(tests, name)
            end
            pos = after
        else
            pos = p + 1
        end
    end
    return tests
end

local function condition_of(s)
    for line in (s .. "\n"):gmatch("([^\n]*)\n") do
        if line:sub(1, 4) == "#if " then
            local at = line:find("//%s*TEST_DISCOVERY_CONDITION%s*$")
            if at and at > 5 then
                return line:sub(5, at - 1):trim()
            end
        end
    end
end

function main(folder, skipfile)
    local skipped = {}
    if skipfile then
        for line in io.readfile(skipfile):gmatch("[^\n]+") do
            skipped[line:trim()] = true
        end
    end
    local files = os.files(path.join(folder, "**Tests.swift"))
    table.sort(files)
    local out = {"import XCTest", "import Foundation", ""}
    local count = 0
    for _, file in ipairs(files) do
        local class = path.basename(file)
        local text = io.readfile(file)
        local tests = {}
        if not skipped[class] then
            for _, name in ipairs(tests_of(text)) do
                if not skipped[class .. "." .. name] then
                    table.insert(tests, name)
                end
            end
        end
        if #tests > 0 then
            local condition = condition_of(text)
            if condition then
                table.insert(out, "#if " .. condition)
            end
            for _, name in ipairs(tests) do
                table.insert(out, string.format('_runTest(%s.self, "%s") { $0.%s }', class, name, name))
                count = count + 1
            end
            if condition then
                table.insert(out, "#endif")
            end
        end
    end
    table.insert(out, "exit(_finishTests())")
    return table.concat(out, "\n") .. "\n", count
end
