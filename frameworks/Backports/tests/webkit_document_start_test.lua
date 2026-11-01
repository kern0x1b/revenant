local workspace = import("@addon.revenant.workspace", {anonymous = true})
local TESTS = path.absolute(os.scriptdir())
local BACKPORTS = path.absolute(path.join(TESTS, ".."))
local SRC = path.join(BACKPORTS, "src", "WebKit")
local DIRECTORY = path.join(TESTS, "webkit_document_start")
local MAIN = path.join(DIRECTORY, "main.m")
local ORACLE = path.join(DIRECTORY, "oracle.m")
local INJECTOR = path.join(SRC, "RevenantDocumentInjector.m")
local PROTOCOL = path.join(SRC, "RevenantDocumentProtocol.m")
local CODEC = path.join(SRC, "RevenantScriptCodec.m")

local EXPECTED = {
    "start injected: 1",
    "start page script saw: set-by-start",
    "redirect final is start: 1",
    "redirect injected: 1",
    "redirect page script saw: set-by-start",
    "link tagged copy keeps the original: 1",
    "link injected: 1",
    "link page script saw: set-by-start|GET|probe-42|",
    "form injected: 1",
    "form page script saw: set-by-start|POST|probe-42|field=value",
    "history network starts: 1",
    "history network page script saw: set-by-start|GET||",
    "history repeat starts: 0",
    "forgotten expectation starts: 0",
    "reload starts: 1",
    "gzip injected: 1",
    "gzip header removed: 1",
    "gzip length matches: 1",
    "gzip page script saw: set-by-start",
    "latin1 injected: 1",
    "latin1 charset kept: 1",
    "latin1 decodes as iso-8859-1: 1",
    "latin1 start script present: 1",
    "meta charset injected: 1",
    "meta charset decodes as iso-8859-1: 1",
    "json injected: 0",
    "json bytes identical: 1",
    "missing injected: 0",
    "missing bytes identical: 1",
    "csp injected: 1",
    "csp header hash: 1",
    "csp page script saw: set-by-start",
    "csp meta hash: 1",
    "response denied: 1",
    "response denied injected: 0",
    "loadHTMLString page saw: set-by-start",
    "loadData page saw: set-by-start",
    "loadFileURL page saw: set-by-start",
    "started marker absent before the shim: 1",
    "started marker set by the shim: 1",
    "document start without head: 1",
    "after doctype: 1",
    "non-ascii escaped: 1",
    "script end tag escaped: 1",
}

local SHARED_WITH_MACOS = {"loadHTMLString page saw", "loadData page saw", "loadFileURL page saw", "reload starts"}

local function clang()
    return os.iorunv("xcrun", {"--sdk", "macosx", "--find", "clang"}):trim()
end

local function macos_sdk()
    return os.iorunv("xcrun", {"--sdk", "macosx", "--show-sdk-path"}):trim()
end

local function build(work, name, sources, flags)
    local output = path.join(work, name)
    local base = {"-O1", "-fobjc-arc", "-w", "-isysroot", macos_sdk(), "-framework", "Foundation", "-I", SRC, "-lz"}
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
            table.insert(differing, string.format("line %d\n    expected: %s\n    actual:   %s", index, line, tostring(actual[index])))
        end
    end
    return differing
end

local function line_starting(lines, prefix)
    for _, line in ipairs(lines) do
        if line:sub(1, #prefix) == prefix then
            return line
        end
    end
    return nil
end

function main()
    local work = workspace.fresh("webkit-document-start")

    local sources = {MAIN, INJECTOR, PROTOCOL, CODEC}
    local lines = run(build(work, "document_start", sources, {"-framework", "JavaScriptCore"}))
    assert(#lines == #EXPECTED, "the document-start test printed " .. #lines .. " lines, expected " .. #EXPECTED)
    local differing = compare(EXPECTED, lines)
    assert(#differing == 0, "document-start injection differs from what the page should see:\n  " .. table.concat(differing, "\n  "))

    local oracle = run(build(work, "document_start_oracle", {ORACLE}, {"-framework", "AppKit", "-framework", "WebKit"}))
    for _, prefix in ipairs(SHARED_WITH_MACOS) do
        local observed = line_starting(oracle, prefix .. ": ")
        assert(observed, "the macOS WKWebView oracle printed no line for " .. prefix)
        local backport = line_starting(lines, prefix .. ": ")
        assert(backport == observed, "the backport disagrees with macOS WKWebView:\n    macOS:    " .. observed .. "\n    backport: " .. tostring(backport))
    end
    local back = line_starting(oracle, "goBack starts: ")
    assert(back, "the macOS WKWebView oracle printed no goBack line")

    local control = run(build(work, "document_start_control", sources, {"-framework", "JavaScriptCore", "-DDOCUMENT_NEGATIVE_CONTROL"}))
    local detected = compare(EXPECTED, control)
    assert(#detected > 0, "the negative control passed: with no start scripts the page still saw them, so the comparison proves nothing")

    os.tryrm(work)
    print(string.format("WEBKIT_DOCUMENT_START_TEST passed (%d checks through the protocol and the rewrite; %d lines agree with macOS WKWebView; macOS %s; negative control detected %d)",
        #EXPECTED, #SHARED_WITH_MACOS, back, #detected))
end
