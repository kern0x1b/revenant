local TESTS = path.absolute(os.scriptdir())
local BACKPORTS = path.absolute(path.join(TESTS, ".."))
local SRC = path.join(BACKPORTS, "src", "WebKit")
local MAIN = path.join(TESTS, "webkit_download", "main.m")

local EXPECTED = {
    "download finished in time: 1",
    "download bytes match: 1",
    "download progress complete: 1",
    "download finished once: 1",
    "download without destination sends no failure: 1",
    "download without destination writes nothing: 1",
    "download original request set: 1",
    "resume data nil: 1",
    "resume data garbage: 1",
    "resume data offset zero: 1",
    "resume data range header: 1",
    "resume data url: 1",
}

local function clang()
    return os.iorunv("xcrun", {"--sdk", "macosx", "--find", "clang"}):trim()
end

local function macos_sdk()
    return os.iorunv("xcrun", {"--sdk", "macosx", "--show-sdk-path"}):trim()
end

local function build(work, name, extra)
    local output = path.join(work, name)
    local flags = {"-O1", "-fobjc-arc", "-w", "-isysroot", macos_sdk(), "-framework", "Foundation", "-framework", "CoreGraphics",
                   "-framework", "WebKit", "-DREVENANT_HOST_BUILD"}
    os.vrunv(clang(), table.join(flags, extra or {}, {MAIN, path.join(SRC, "WKDownload.m")}, {"-o", output}))
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
    local work = path.join(os.tmpdir(), "webkit-download")
    os.tryrm(work)
    os.mkdir(work)

    local lines = lines_of(os.iorunv(build(work, "download"), {}))
    local differing = compare(EXPECTED, lines)
    assert(#lines == #EXPECTED and #differing == 0, "the download backport does not behave as documented:\n  "
        .. table.concat(differing, "\n  "))

    local flipped = lines_of(os.iorunv(build(work, "control", {"-DWEBKIT_DOWNLOAD_NEGATIVE_CONTROL"}), {}))
    local detected = compare(EXPECTED, flipped)
    assert(#detected > 0, "the negative control passed: flipped results compared equal to the expected lines, so the comparison proves nothing")

    os.tryrm(work)
    print(string.format("WEBKIT_DOWNLOAD_TEST passed (%d checks, negative control detected %d)", #EXPECTED, #detected))
end
