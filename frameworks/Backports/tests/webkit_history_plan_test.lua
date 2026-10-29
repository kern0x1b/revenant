local TESTS = path.absolute(os.scriptdir())
local BACKPORTS = path.absolute(path.join(TESTS, ".."))
local SRC = path.join(BACKPORTS, "src", "WebKit")
local MAIN = path.join(TESTS, "webkit_history_plan", "main.m")
local PLAN = path.join(SRC, "RevenantHistoryPlan.m")

local EXPECTED = {
    "plain entry, engine trusted: engine",
    "plain entry, engine not trusted: load",
    "string entry, engine trusted: replay",
    "string entry, engine not trusted: replay",
}

local function clang()
    return os.iorunv("xcrun", {"--sdk", "macosx", "--find", "clang"}):trim()
end

local function macos_sdk()
    return os.iorunv("xcrun", {"--sdk", "macosx", "--show-sdk-path"}):trim()
end

local function lines_of(text)
    local lines = {}
    for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
        if line ~= "" then
            table.insert(lines, line)
        end
    end
    return lines
end

function main()
    local work = path.join(os.tmpdir(), "webkit-history-plan")
    os.tryrm(work)
    os.mkdir(work)

    local output = path.join(work, "history_plan")
    os.vrunv(clang(), {"-O1", "-fobjc-arc", "-w", "-isysroot", macos_sdk(), "-framework", "Foundation", "-I", SRC, MAIN, PLAN, "-o", output})
    local lines = lines_of(os.iorunv(output, {}))

    assert(#lines == #EXPECTED, "the history plan test printed " .. #lines .. " lines, expected " .. #EXPECTED)
    for index, line in ipairs(EXPECTED) do
        assert(lines[index] == line, string.format("history move %d differs:\n    expected: %s\n    actual:   %s", index, line, tostring(lines[index])))
    end

    os.tryrm(work)
    print(string.format("WEBKIT_HISTORY_PLAN_TEST passed (%d moves)", #EXPECTED))
end
