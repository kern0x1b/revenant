local TESTS = path.absolute(os.scriptdir())
local BACKPORTS = path.absolute(path.join(TESTS, ".."))
local SRC = path.join(BACKPORTS, "src", "WebKit")
local MAIN = path.join(TESTS, "webkit_script_message", "main.m")
local CODEC = path.join(SRC, "RevenantScriptCodec.m")
local WINDOW_FEATURES = path.join(SRC, "WKWindowFeatures.m")

local SAMPLE_COUNT = 17
local WINDOW_COUNT = 2

local BACKPORT_ONLY = {
    "cycle identical: 1",
    "refused non-string body: 1",
    "refused non-JSON body: 1",
    "refused non-string tag: 1",
    "refused foreign URL: 1",
    "refused forged nonce: 1",
    "refused missing nonce: 1",
    "nesting capped: 1",
    "window proxy open envelope: 1",
    "window proxy is an object: 1",
    "window proxy starts open: 1",
    "window location starts at about:blank: 1",
    "window proxy close posts once: 1",
    "window closed after close() is true: 1",
    "window proxy postMessage posts origin: 1",
    "window proxy location set posts navigation: 1",
    "window proxy message round trips: 1",
    "window proxy native update moves location: 1",
    "window proxy native update closes: 1",
    "window self close posts: 1",
    "window proxy survives a second install: 1",
    "window open refused is null: 1",
    "window open refusal is sent synchronously: 1",
    "window open accepted is an object: 1",
    "window opener is an object: 1",
    "window opener href is the opener URL: 1",
    "window opener starts open: 1",
    "window opener postMessage posts origin: 1",
    "window opener location set posts navigation: 1",
    "window opener native update moves location: 1",
    "window message from opener has its source: 1",
    "window without opener has none: 1",
    "window location is the URL after load: 1",
    "window postMessage other origin is dropped: 1",
    "window postMessage matching origin is delivered: 1",
    "window origin drops default port: 1",
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
    local backport_flags = {"-I", SRC, "-framework", "JavaScriptCore", "-framework", "WebKit", "-framework", "AppKit", "-DREVENANT_HOST_BUILD"}
    local backport_program = build(work, "backport_messages", {MAIN, CODEC, WINDOW_FEATURES}, backport_flags)

    local oracle = run(oracle_program)
    assert(#oracle == SAMPLE_COUNT + WINDOW_COUNT, "the macOS WKWebView delivered " .. #oracle .. " of " .. (SAMPLE_COUNT + WINDOW_COUNT) .. " lines")

    local backport = run(backport_program)
    assert(#backport == SAMPLE_COUNT + WINDOW_COUNT + #BACKPORT_ONLY, "the backport printed " .. #backport .. " lines, expected "
        .. (SAMPLE_COUNT + WINDOW_COUNT + #BACKPORT_ONLY))
    local shared = {}
    for index = 1, SAMPLE_COUNT + WINDOW_COUNT do
        table.insert(shared, backport[index])
    end
    local differing = compare(oracle, shared)
    assert(#differing == 0, "the backport disagrees with macOS WKWebView:\n  " .. table.concat(differing, "\n  "))

    local checks = {}
    for index = SAMPLE_COUNT + WINDOW_COUNT + 1, #backport do
        table.insert(checks, backport[index])
    end
    local check_differing = compare(BACKPORT_ONLY, checks)
    assert(#check_differing == 0, "a backport-only check failed:\n  " .. table.concat(check_differing, "\n  "))

    local control_program = build(work, "control_messages", {MAIN, CODEC, WINDOW_FEATURES}, table.join(backport_flags, {"-DWEBKIT_MESSAGE_NEGATIVE_CONTROL"}))
    local detected = compare(oracle, run(control_program))
    assert(#detected > 0, "the negative control passed: a damaged bridge URL decoded to the macOS bodies, so the comparison proves nothing")

    os.tryrm(work)
    print(string.format("WEBKIT_SCRIPT_MESSAGE_TEST passed (%d page messages and %d window.open lines agree with macOS WKWebView, %d backport-only checks, negative control detected %d)",
        SAMPLE_COUNT, WINDOW_COUNT, #BACKPORT_ONLY, #detected))
end
