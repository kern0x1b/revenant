local workspace = import("@addon.revenant.workspace", {anonymous = true})
local TESTS = path.absolute(os.scriptdir())
local BACKPORTS = path.absolute(path.join(TESTS, ".."))
local SRC = path.join(BACKPORTS, "src", "WebKit")
local MAIN = path.join(TESTS, "webkit_values", "main.m")

local ENGINE = {
    "engine download original request nil: 1",
    "engine download web view nil: 1",
    "engine download user initiated: 0",
    "engine download originating frame nil: 1",
    "engine download progress nil: 1",
    "engine download cancel reports no resume data: 1",
    "engine open panel multiple selection: 0",
    "engine open panel directories: 0",
    "engine window features unset: 1",
}

local SHARED_COUNT = 4

local function clang()
    return os.iorunv("xcrun", {"--sdk", "macosx", "--find", "clang"}):trim()
end

local function macos_sdk()
    return os.iorunv("xcrun", {"--sdk", "macosx", "--show-sdk-path"}):trim()
end

local function build(work, name, sources, extra)
    local output = path.join(work, name)
    local flags = {"-O1", "-fobjc-arc", "-w", "-isysroot", macos_sdk(), "-framework", "Foundation", "-framework", "CoreGraphics",
                   "-framework", "WebKit"}
    os.vrunv(clang(), table.join(flags, extra or {}, sources, {"-o", output}))
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
    local work = workspace.fresh("webkit-values")

    local backport_sources = {MAIN, path.join(SRC, "WKSnapshotConfiguration.m"), path.join(SRC, "WKDownload.m"),
                              path.join(SRC, "WKOpenPanelParameters.m"), path.join(SRC, "WKWindowFeatures.m")}
    local backport_flags = {"-DREVENANT_HOST_BUILD", "-DREVENANT_BACKPORT"}

    local oracle = run(build(work, "oracle_values", {MAIN}, {}))
    assert(#oracle == SHARED_COUNT, "the macOS build printed " .. #oracle .. " shared values, expected " .. SHARED_COUNT)

    local backport = run(build(work, "backport_values", backport_sources, backport_flags))
    local shared = {}
    local engine = {}
    for index, line in ipairs(backport) do
        if index <= #oracle then
            table.insert(shared, line)
        else
            table.insert(engine, line)
        end
    end

    local differing = compare(oracle, shared)
    assert(#differing == 0, "the backport's shared WebKit values disagree with macOS:\n  " .. table.concat(differing, "\n  "))

    local engine_differing = compare(ENGINE, engine)
    assert(#engine == #ENGINE and #engine_differing == 0, "the backport's engine values are not the documented ones:\n  "
        .. table.concat(engine_differing, "\n  "))

    local flipped = run(build(work, "control_values", backport_sources, table.join(backport_flags, {"-DWEBKIT_VALUES_NEGATIVE_CONTROL"})))
    local detected = compare(oracle, flipped)
    assert(#detected > 0, "the negative control passed: a flipped default compared equal to macOS, so the comparison proves nothing")

    os.tryrm(work)
    print(string.format("WEBKIT_VALUES_TEST passed (%d shared values agree with macOS, %d engine values as documented, negative control detected %d)",
        #oracle, #ENGINE, #detected))
end
