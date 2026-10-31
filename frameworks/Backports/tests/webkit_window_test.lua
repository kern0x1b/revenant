local workspace = import("@addon.revenant.workspace", {anonymous = true})
local TESTS = path.absolute(os.scriptdir())
local BACKPORTS = path.absolute(path.join(TESTS, ".."))
local SRC = path.join(BACKPORTS, "src", "WebKit")
local ORACLE = path.join(TESTS, "webkit_window", "oracle.m")
local MAIN = path.join(TESTS, "webkit_script_message", "main.m")
local CODEC = path.join(SRC, "RevenantScriptCodec.m")
local WINDOW_FEATURES = path.join(SRC, "WKWindowFeatures.m")

local ORACLE_ONLY = {
    "popup message reaches opener with source: 1",
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

local function name_of(line)
    local name = string.match(line, "^(.-): %d+$")
    assert(name, "a check line has no name and value: " .. line)
    return name
end

local function index_by_name(lines)
    local index = {}
    for _, line in ipairs(lines) do
        local name = string.match(line, "^(.-): %d+$")
        if name then
            assert(index[name] == nil, "a check name is printed twice: " .. name)
            index[name] = line
        end
    end
    return index
end

function main()
    local work = workspace.fresh("webkit-window")

    local oracle_program = build(work, "oracle_window", {ORACLE}, {"-framework", "WebKit", "-framework", "AppKit"})
    local backport_flags = {"-I", SRC, "-framework", "JavaScriptCore", "-framework", "WebKit", "-framework", "AppKit", "-DREVENANT_HOST_BUILD"}
    local backport_program = build(work, "backport_window", {MAIN, CODEC, WINDOW_FEATURES}, backport_flags)

    local oracle = lines_of(os.iorunv(oracle_program, {}))
    local backport = index_by_name(lines_of(os.iorunv(backport_program, {})))

    local only = {}
    for _, line in ipairs(ORACLE_ONLY) do
        only[line] = true
    end

    local compared = 0
    local differing = {}
    local seen_only = {}
    for _, line in ipairs(oracle) do
        if only[line] then
            seen_only[line] = true
        else
            local name = name_of(line)
            local actual = backport[name]
            compared = compared + 1
            if actual ~= line then
                table.insert(differing, string.format("%s\n    macOS:    %s\n    backport: %s", name, line, tostring(actual)))
            end
        end
    end
    assert(#differing == 0, "the backport disagrees with macOS WKWebView:\n  " .. table.concat(differing, "\n  "))

    for _, line in ipairs(ORACLE_ONLY) do
        assert(seen_only[line], "the macOS oracle did not print: " .. line)
    end

    local expected = #oracle - #ORACLE_ONLY
    assert(compared == expected, "compared " .. compared .. " checks, expected " .. expected)

    os.tryrm(work)
    print(string.format("WEBKIT_WINDOW_TEST passed (%d window checks agree with macOS WKWebView by name, %d oracle-only checks present)",
        compared, #ORACLE_ONLY))
end
