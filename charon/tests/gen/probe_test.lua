local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")

local function checks()
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end
    return check, function() return failures end
end

local function test_values(check)
    local probe = import("gen.probe", {rootdir = TOOLS, anonymous = true})
    local library = "/System/Library/Frameworks/Foundation.framework/Foundation"
    local got = probe.values(library, {"NSMultipleUnderlyingErrorsKey", "NSNoSuchNameForTheProbeTest"})
    check(got.NSMultipleUnderlyingErrorsKey ~= nil and got.NSMultipleUnderlyingErrorsKey[1] == "found",
          "a constant the host framework exports is found")
    check(got.NSMultipleUnderlyingErrorsKey ~= nil and got.NSMultipleUnderlyingErrorsKey[2] == "NSMultipleUnderlyingErrorsKey",
          "the found value is the string the framework holds")
    check(got.NSNoSuchNameForTheProbeTest ~= nil and got.NSNoSuchNameForTheProbeTest[1] == "missing",
          "a name the framework does not export is missing")
    local crashed = probe.values("/nonexistent/probe-test/library", {"NSMultipleUnderlyingErrorsKey", "Another"})
    check(crashed.NSMultipleUnderlyingErrorsKey ~= nil and crashed.NSMultipleUnderlyingErrorsKey[1] == "probe-crashed"
          and crashed.NSMultipleUnderlyingErrorsKey[2] == "-", "a library the oracle cannot load gives probe-crashed per name")
    check(crashed.Another ~= nil and crashed.Another[1] == "probe-crashed", "every name of a failing library is probe-crashed")
end

local function test_probe(check)
    local probe = import("gen.probe", {rootdir = TOOLS, anonymous = true})
    local got = probe.probe(path.absolute("."), "Foundation", {"NSMultipleUnderlyingErrorsKey"})
    check(got.NSMultipleUnderlyingErrorsKey ~= nil and got.NSMultipleUnderlyingErrorsKey[1] == "found"
          and got.NSMultipleUnderlyingErrorsKey[2] == "NSMultipleUnderlyingErrorsKey", "probe reads the host framework of fw")
end

local function listing(folder)
    local entries = {}
    for _, filepath in ipairs(os.files(path.join(folder, "**"))) do
        table.insert(entries, filepath)
    end
    for _, dir in ipairs(os.dirs(path.join(folder, "**"))) do
        table.insert(entries, dir .. "/")
    end
    table.sort(entries)
    return table.concat(entries, "\n")
end

local function test_no_files(check)
    local probe = import("gen.probe", {rootdir = TOOLS, anonymous = true})
    local host = import("gen.host", {rootdir = TOOLS, anonymous = true})
    local library = "/System/Library/Frameworks/Foundation.framework/Foundation"
    local names = {"NSMultipleUnderlyingErrorsKey", "NSNoSuchNameForTheProbeTest"}
    local folder = path.join(host.builddir(), "gen")
    local before = listing(folder)
    local got = probe.values(library, names)
    local after_one = listing(folder)
    probe.values(library, names)
    local after_two = listing(folder)
    check(before == after_one, "a probe run creates no file under the probe folder")
    check(after_one == after_two, "a second probe run creates no file under the probe folder")
    check(not os.isfile(path.join(folder, "probe-names.txt")) and not os.isfile(path.join(folder, "probe-name.txt")),
          "no staging file of the probe names is written")
    check(got.NSMultipleUnderlyingErrorsKey ~= nil and got.NSMultipleUnderlyingErrorsKey[1] == "found",
          "the probe reads the names with no staging file")
end

local function test_text(check)
    local cmd = import("gen.cmd_diff", {rootdir = TOOLS, anonymous = true})
    local host = import("gen.host", {rootdir = TOOLS, anonymous = true})
    local strings = import("gen.strings", {rootdir = TOOLS, anonymous = true})
    check(cmd.repr("abc") == "'abc'", "repr of plain text is single quoted")
    check(cmd.repr("a'b") == '"a\'b"', "repr uses double quotes when the text holds a single quote and no double quote")
    check(cmd.repr("a\"b'c") == "'a\"b\\'c'", "repr escapes the single quote when both quotes are present")
    check(cmd.repr("a\\b\tc\n") == "'a\\\\b\\tc\\n'", "repr escapes backslash, tab and newline")
    check(cmd.repr("\1") == "'\\x01'", "repr escapes other control characters as \\xNN")
    local parts = strings.lines("a\r\nb\rc\vd\fe\n")
    check(#parts == 5 and parts[1] == "a" and parts[2] == "b" and parts[3] == "c" and parts[4] == "d" and parts[5] == "e",
          "lines splits on CR LF, CR, VT, FF and LF as splitlines does")
    check(#strings.lines("") == 0, "lines of the empty text is empty")
    check(host.tail("  abcdef  ", 3) == "def", "tail keeps the last bytes of the stripped text")
    local ok, out, err, status = host.run("/bin/sh", {"-c", "echo kept; echo failure >&2; exit 3"})
    check(ok == false and out == "kept\n" and err == "failure\n" and status == 3,
          "a failing program keeps its exit status and its stderr, and its ok flag is false")
end

function main()
    local check, failures = checks()
    test_no_files(check)
    test_text(check)
    test_values(check)
    test_probe(check)
    print("probe test: " .. (failures() == 0 and "OK" or ("FAIL " .. failures())))
    if failures() > 0 then
        os.exit(1)
    end
end
