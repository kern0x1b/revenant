local TESTS = path.absolute(os.scriptdir())
local BACKPORTS = path.absolute(path.join(TESTS, ".."))
local SRC = path.join(BACKPORTS, "src", "WebKit")
local MAIN = path.join(TESTS, "webkit_script_message", "main.m")
local CODEC = path.join(SRC, "RevenantScriptCodec.m")

local SAMPLE_COUNT = 17

local BACKPORT_ONLY = {
    "cycle identical: 1",
    "refused non-string body: 1",
    "refused non-JSON body: 1",
    "refused non-string tag: 1",
    "refused foreign URL: 1",
    "refused forged nonce: 1",
    "refused missing nonce: 1",
    "nesting capped: 1",
}

local function clang()
    return os.iorunv("xcrun", {"--sdk", "macosx", "--find", "clang"}):trim()
end

local function macos_sdk()
    return os.iorunv("xcrun", {"--sdk", "macosx", "--show-sdk-path"}):trim()
end

local function build(work, name, sources, flags)
    local output = path.join(work, name)
    local base = {"-O1", "-fobjc-arc", "-w", "-isysroot", macos_sdk(), "-framework", "Foundation"}
    os.vrunv(clang(), table.join(base, flags, sources, {"-o", output}))
    return output
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

local function run(program)
    return lines_of(os.iorunv(program, {}))
end

local function compare(expected, actual)
    local differing = {}
    for index, line in ipairs(expected) do
        if actual[index] ~= line then
            table.insert(differing, string.format("line %d\n    macOS:    %s\n    backport: %s", index, line, tostring(actual[index])))
        end
    end
    return differing
end

function main()
    local work = path.join(os.tmpdir(), "webkit-script-message")
    os.tryrm(work)
    os.mkdir(work)

    local oracle_program = build(work, "oracle_messages", {MAIN}, {"-DWEBKIT_MESSAGE_ORACLE", "-framework", "WebKit", "-framework", "AppKit"})
    local backport_flags = {"-I", SRC, "-framework", "JavaScriptCore"}
    local backport_program = build(work, "backport_messages", {MAIN, CODEC}, backport_flags)

    local oracle = run(oracle_program)
    assert(#oracle == SAMPLE_COUNT, "the macOS WKWebView delivered " .. #oracle .. " of " .. SAMPLE_COUNT .. " messages")

    local backport = run(backport_program)
    assert(#backport == SAMPLE_COUNT + #BACKPORT_ONLY, "the backport printed " .. #backport .. " lines, expected "
        .. (SAMPLE_COUNT + #BACKPORT_ONLY))
    local shared = {}
    for index = 1, SAMPLE_COUNT do
        table.insert(shared, backport[index])
    end
    local differing = compare(oracle, shared)
    assert(#differing == 0, "the backport's message bodies disagree with macOS WKWebView:\n  " .. table.concat(differing, "\n  "))

    local checks = {}
    for index = SAMPLE_COUNT + 1, #backport do
        table.insert(checks, backport[index])
    end
    local check_differing = compare(BACKPORT_ONLY, checks)
    assert(#check_differing == 0, "a backport-only check failed:\n  " .. table.concat(check_differing, "\n  "))

    local control_program = build(work, "control_messages", {MAIN, CODEC}, table.join(backport_flags, {"-DWEBKIT_MESSAGE_NEGATIVE_CONTROL"}))
    local detected = compare(oracle, run(control_program))
    assert(#detected > 0, "the negative control passed: a damaged bridge URL decoded to the macOS bodies, so the comparison proves nothing")

    os.tryrm(work)
    print(string.format("WEBKIT_SCRIPT_MESSAGE_TEST passed (%d page messages agree with macOS WKWebView, %d backport-only checks, negative control detected %d)",
        SAMPLE_COUNT, #BACKPORT_ONLY, #detected))
end
