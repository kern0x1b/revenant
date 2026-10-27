local TESTS = path.absolute(os.scriptdir())
local BACKPORTS = path.absolute(path.join(TESTS, ".."))
local SRC = path.join(BACKPORTS, "src", "WebKit")
local MAIN = path.join(TESTS, "webkit_document_start", "main.m")
local INJECTOR = path.join(SRC, "RevenantDocumentInjector.m")
local PROTOCOL = path.join(SRC, "RevenantDocumentProtocol.m")

local EXPECTED = {
    "start injected: 1",
    "start page script saw: set-by-start",
    "redirect final is start: 1",
    "redirect injected: 1",
    "redirect page script saw: set-by-start",
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
    "document start without head: 1",
    "after doctype: 1",
    "non-ascii escaped: 1",
    "script end tag escaped: 1",
}

local function clang()
    return os.iorunv("xcrun", {"--sdk", "macosx", "--find", "clang"}):trim()
end

local function macos_sdk()
    return os.iorunv("xcrun", {"--sdk", "macosx", "--show-sdk-path"}):trim()
end

local function build(work, name, sources, flags)
    local output = path.join(work, name)
    local base = {"-O1", "-fobjc-arc", "-w", "-isysroot", macos_sdk(), "-framework", "Foundation", "-framework", "JavaScriptCore", "-lz", "-I", SRC}
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

function main()
    local work = path.join(os.tmpdir(), "webkit-document-start")
    os.tryrm(work)
    os.mkdir(work)

    local sources = {MAIN, INJECTOR, PROTOCOL}
    local lines = run(build(work, "document_start", sources, {}))
    assert(#lines == #EXPECTED, "the document-start test printed " .. #lines .. " lines, expected " .. #EXPECTED)
    local differing = compare(EXPECTED, lines)
    assert(#differing == 0, "document-start injection differs from what the page should see:\n  " .. table.concat(differing, "\n  "))

    local control = run(build(work, "document_start_control", sources, {"-DDOCUMENT_NEGATIVE_CONTROL"}))
    local detected = compare(EXPECTED, control)
    assert(#detected > 0, "the negative control passed: with no start scripts the page still saw them, so the comparison proves nothing")

    os.tryrm(work)
    print(string.format("WEBKIT_DOCUMENT_START_TEST passed (%d checks through the protocol and the rewrite, negative control detected %d)", #EXPECTED, #detected))
end
