import("core.base.json")

local ROOT = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
local TOOL = path.join(ROOT, "frameworks", "ReactNative", "tools", "coverage.lua")
local FILES = {
    "frameworks/ReactNative/src/coverage.json",
    "frameworks/ReactNative/src/stubs.json",
    "frameworks/ReactNative/src/expo/xmake.lua",
    "frameworks/ReactNative/src/expo/StubModules.swift",
    "docs/reference/react-native/coverage.md"
}

local function fixture(name)
    local dir = path.join(os.tmpdir(), "rn-coverage-test", name)
    os.rm(dir)
    for _, rel in ipairs(FILES) do
        local target = path.join(dir, rel)
        os.mkdir(path.directory(target))
        os.cp(path.join(ROOT, rel), target)
    end
    return dir
end

local function edit_file(dir, rel, edit)
    local file = path.join(dir, rel)
    local data = json.decode(io.readfile(file))
    edit(data)
    io.writefile(file, json.encode(data))
end

local function row(data, id)
    for _, item in ipairs(data.rows) do
        if item.id == id then
            return item
        end
    end
    raise("no coverage row %s", id)
end

local function check(dir)
    local log = path.join(dir, "check.log")
    local command = string.format("'%s' l -P '%s' '%s' --check --root '%s' > '%s' 2>&1", os.programfile(), ROOT, TOOL, dir, log)
    local status = os.execv("/bin/sh", {"-c", command}, {try = true})
    return status, io.readfile(log)
end

local function expect_pass(name, dir)
    local status, text = check(dir)
    if status ~= 0 then
        raise("%s: the checks failed on data that should pass:\n%s", name, text)
    end
    print(name .. ": passes")
end

local function expect_fail(name, dir, reason)
    local status, text = check(dir)
    if status == 0 or not text:find(reason, 1, true) then
        raise("%s: expected a failure mentioning %q, got status %s:\n%s", name, reason, tostring(status), text)
    end
    print(name .. ": fails as it should")
end

function main()
    expect_pass("the checked-in data", fixture("baseline"))

    local stubbed = fixture("verified-stub")
    edit_file(stubbed, "frameworks/ReactNative/src/coverage.json", function (data)
        row(data, "PaseoHardwareKeyboard").verified = "phone"
    end)
    expect_fail("a stub row verified on the phone", stubbed, "a stub is not a check of the module")

    local substitute = fixture("substitute-real")
    edit_file(substitute, "frameworks/ReactNative/src/coverage.json", function (data)
        row(data, "expo-localization").status = "real"
    end)
    expect_fail("a real row with a local copy of its file", substitute, "replaces its file with a local copy")

    local unlisted = fixture("unlisted-class")
    edit_file(unlisted, "frameworks/ReactNative/src/stubs.json", function (data)
        local kept = {}
        for _, stub in ipairs(data.stubs) do
            if stub.name ~= "StubDocumentPickerModule" then
                table.insert(kept, stub)
            end
        end
        data.stubs = kept
    end)
    expect_fail("a stub class missing from stubs.json", unlisted, "declares StubDocumentPickerModule, which stubs.json does not list")

    local orphan = fixture("stub-without-entry")
    edit_file(orphan, "frameworks/ReactNative/src/coverage.json", function (data)
        table.insert(data.rows, {id = "orphan-stub", group = "sdk", version = "", native = true, status = "stub", verified = "none", note = "A stub with no entry."})
    end)
    expect_fail("a stub row with no stubs.json entry", orphan, "no entry of stubs.json stands in for it")

    local unbuilt = fixture("verified-unbuilt")
    edit_file(unbuilt, "frameworks/ReactNative/src/coverage.json", function (data)
        row(data, "react-native-svg").status = "evaluate"
    end)
    expect_fail("a native row verified but not built", unbuilt, "is not a built module")
end
