-- The literal test of the generator's steps: no string literal in tools/gen or tools/found names an SDK release (26.2, 16.4, iphoneos26)
-- or a machine path (/Users/, the xmake package folder, the platform folder). The release comes from the SDK (sdk.discover), and the
-- machine paths are the project's options in tools/gen/project.lua, the one file exempt here. Comments are not literals: a comment may
-- name a release. The scanner reads Lua tokens (strings and comments, long brackets too), so a pattern inside a comment is not a hit.
-- A mutant must make this test fail: a real step file with one release literal added is scanned, and the scan must report it.
-- Run: xmake l tests/gen/literal_test.lua (exits 1 on failure). Pure Lua: no SDK, no clang.

local ROOT = path.absolute(path.join(os.scriptdir(), "..", ".."))
local TOOLS = path.join(ROOT, "tools")

-- The patterns a step's string literal must not match (Lua patterns over the literal's value).
local FORBIDDEN = {"26%.2", "16%.4", "iphoneos%d", "iPhoneOS%d", "/Users/", "%.xmake", "iPhoneOS%.platform"}

-- The string literals of a Lua source: {line, value} for each quoted or long-bracket string. Comments are skipped whole: a "--" to the
-- end of its line, or a "--[[ ... ]]" block.
local function literals_of(text)
    local out = {}
    local i, n, line = 1, #text, 1
    while i <= n do
        local c = string.sub(text, i, i)
        if c == "\n" then
            line = line + 1
            i = i + 1
        elseif string.sub(text, i, i + 1) == "--" then
            local open = string.match(text, "^%-%-%[(=*)%[", i)
            if open then
                local close = "]" .. string.rep("=", #open) .. "]"
                local stop = (string.find(text, close, i, true) or n) + #close - 1
                local _, newlines = string.gsub(string.sub(text, i, stop), "\n", "")
                line = line + newlines
                i = stop + 1
            else
                i = string.find(text, "\n", i, true) or (n + 1)
            end
        elseif c == '"' or c == "'" then
            local j, buf, start_line = i + 1, {}, line
            while j <= n and string.sub(text, j, j) ~= c do
                if string.sub(text, j, j) == "\\" then
                    j = j + 1
                end
                if string.sub(text, j, j) == "\n" then
                    line = line + 1
                end
                table.insert(buf, string.sub(text, j, j))
                j = j + 1
            end
            table.insert(out, {line = start_line, value = table.concat(buf)})
            i = j + 1
        elseif string.match(text, "^%[(=*)%[", i) then
            local open = string.match(text, "^%[(=*)%[", i)
            local body = i + #open + 2
            local close = "]" .. string.rep("=", #open) .. "]"
            local stop = string.find(text, close, body, true) or (n + 1)
            local value = string.sub(text, body, stop - 1)
            table.insert(out, {line = line, value = value})
            local _, newlines = string.gsub(value, "\n", "")
            line = line + newlines
            i = stop + #close
        else
            i = i + 1
        end
    end
    return out
end

-- The hits of a source text: each string literal a FORBIDDEN pattern matches, as "line: value".
local function hits_of(text)
    local hits = {}
    for _, lit in ipairs(literals_of(text)) do
        for _, pattern in ipairs(FORBIDDEN) do
            if string.find(lit.value, pattern) then
                table.insert(hits, lit.line .. ": " .. lit.value)
                break
            end
        end
    end
    return hits
end

-- The step files: every .lua under the step folders, except the project's options and the tests of the folders.
local function step_files()
    local out = {}
    for _, folder in ipairs({path.join(TOOLS, "gen"), path.join(TOOLS, "found")}) do
        for _, file in ipairs(os.files(path.join(folder, "**.lua"))) do
            local rel = string.sub(file, #TOOLS + 2)
            local exempt = rel == path.join("gen", "project.lua") or string.find(rel, "/tests/", 1, true) or string.find(rel, ".xmake", 1, true)
            if not exempt then
                table.insert(out, file)
            end
        end
    end
    table.sort(out)
    return out
end

function main()
    local failures, count = 0, 0
    local function check(ok, label)
        count = count + 1
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    -- the scanner itself: a literal is a hit, a comment is not, a long string is read, an escaped quote does not end the string
    check(#hits_of('local x = "iPhoneOS26.2.sdk"') == 1, "a release in a string is a hit")
    check(#hits_of('-- the 26.2 headers and 16.4 body\nlocal x = 1') == 0, "a release in a line comment is not a hit")
    check(#hits_of('--[[ 26.2 ]] local x = 1') == 0, "a release in a block comment is not a hit")
    check(#hits_of('local x = [[ /Users/me ]]') == 1, "a machine path in a long string is a hit")
    check(#hits_of('local x = "a \\" 26.2"') == 1, "an escaped quote does not end the string")
    check(#hits_of('local x = "--sdk 26.2"') == 1, "a -- inside a string is not a comment")

    -- the real steps: no literal names a release or a machine path
    local files = step_files()
    check(#files > 0, "the step files are found")
    for _, file in ipairs(files) do
        for _, hit in ipairs(hits_of(io.readfile(file))) do
            check(false, string.sub(file, #TOOLS + 2) .. ":" .. hit)
        end
    end

    -- the mutant: a step file with one release literal added is reported (the test would fail on the mutant)
    local step = path.join(TOOLS, "gen", "cmd_scope.lua")
    local mutant = io.readfile(step) .. '\nlocal MUTANT_RELEASE = "iphoneos26.2"\n'
    local found = hits_of(mutant)
    check(#found == 1 and string.find(found[1], "iphoneos26.2", 1, true) ~= nil, "a mutant release literal in cmd_scope.lua is reported")

    print("literal test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)) .. " (" .. count .. " checks, " .. #files .. " files)")
    if failures > 0 then
        os.exit(1)
    end
end
