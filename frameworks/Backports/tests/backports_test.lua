local tools = path.absolute(path.join(os.scriptdir(), "..", "tools"))
local facts = import("facts", {rootdir = tools, anonymous = true})
local ast = import("ast", {rootdir = tools, anonymous = true})
local sdkfiles = import("sdk", {rootdir = tools, anonymous = true})
local generate = import("generate", {rootdir = tools, anonymous = true})
local implemented = import("implemented", {rootdir = tools, anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

local VERSION = "26.2"

local function failure_of(action)
    local message
    try
    {
        action,
        catch
        {
            function (errors)
                message = tostring(errors)
            end
        }
    }
    return message
end

function main()
    local data = path.absolute(path.join(os.scriptdir(), "data"))
    local sdk = path.join(data, "sdk")
    local minimum = ast.version_of("6.0")
    assert(minimum, "ast.version_of cannot read 6.0")

    local rows = facts.objc_facts(sdk, "Fixture", VERSION)
    local class_seen = false
    local methods = {}
    for _, row in ipairs(rows) do
        if row.kind == "class" and row.name == "FXRoot" then
            class_seen = true
        elseif row.kind == "instance method" then
            table.insert(methods, row)
        end
    end
    assert(class_seen, "the class FXRoot was not extracted")
    assert(#methods == 4, "expected 4 instance methods, got " .. #methods)

    local scoped = {}
    for _, row in ipairs(methods) do
        if sdkfiles.in_scope(row, minimum, nil) then
            table.insert(scoped, row)
        end
    end
    assert(#scoped == 3, "expected 3 in-scope methods, got " .. #scoped)

    local objects = path.join(workspace.home(), "cache", "backports-test-objects")
    os.tryrm(objects)
    local object = path.join(objects, "Fixture", "src", "Fixture", "Fixture.m.o")
    os.mkdir(path.directory(object))
    os.vrunv("clang", {"-target", "armv7-apple-ios6.0", "-isysroot", sdk, "-fobjc-arc", "-w", "-c", "-o", object,
        path.join(data, "src", "Fixture", "Fixture.m")})
    local keys = implemented.from_objects(objects).Fixture or {}
    local found, missing = 0, {}
    for _, row in ipairs(scoped) do
        local key = row.kind .. "|" .. row.container .. "|" .. row.name
        if keys[key] then
            found = found + 1
        else
            table.insert(missing, row.name)
        end
    end
    assert(found == 2, "expected 2 implemented members, got " .. found)
    assert(#missing == 1 and missing[1] == "fx_later", "expected fx_later to be the only missing member")

    local cache = path.join(workspace.home(), "cache", "backports-test")
    os.tryrm(cache)
    os.mkdir(cache)
    local logs = path.join(cache, "logs")
    os.mkdir(logs)
    generate.extract_all(sdk, VERSION, cache, logs, {"Fixture"})
    assert(os.isfile(path.join(cache, "Fixture.tsv")), "extract_all wrote no TSV for Fixture")

    local clang = failure_of(function () generate.extract_all(sdk, VERSION, cache, logs, {"Broken"}) end)
    assert(clang and string.find(clang, "Broken: ", 1, true), "a failing clang call did not raise naming Broken: " .. tostring(clang))

    local digester = failure_of(function () generate.extract_all(sdk, VERSION, cache, logs, {"BadSwift"}) end)
    assert(digester and string.find(digester, "BadSwift: ", 1, true), "a failing digester call did not raise naming BadSwift: " .. tostring(digester))

    os.tryrm(cache)
    print("backports tests passed: extracted " .. #rows .. " facts, Y=" .. #scoped .. ", X=" .. found)
    print("clang failure: " .. clang)
    print("digester failure: " .. digester)
end
