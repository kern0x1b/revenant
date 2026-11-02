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
    local rows = facts.objc_facts(sdk, "Fixture", VERSION)
    local class_seen = false
    local methods = {}
    local unavailable = {}
    local shared = nil
    for _, row in ipairs(rows) do
        if row.kind == "class" and row.name == "FXRoot" then
            class_seen = true
        elseif row.kind == "class" and generate.has_flag(row, "unavailable") then
            unavailable[row.name] = true
        elseif row.kind == "global variable" and row.name == "fx_shared" then
            shared = row
        elseif row.kind == "instance method" and row.container == "FXRoot" then
            table.insert(methods, row)
        end
    end
    assert(class_seen, "the class FXRoot was not extracted")
    assert(unavailable.FXGone, "the class FXGone is not marked unavailable")
    assert(shared and generate.has_flag(shared, "unavailable"), "fx_shared is not unavailable: the second declaration's attribute was lost")
    assert(not generate.exists_on_ios(shared, unavailable), "fx_shared exists on iOS although one declaration marks it unavailable")
    assert(#methods == 5, "expected 5 instance methods of FXRoot, got " .. #methods)

    local scoped, withdrawn = {}, {}
    for _, row in ipairs(methods) do
        if generate.exists_on_ios(row, unavailable) then
            table.insert(scoped, row)
        else
            table.insert(withdrawn, row.name)
        end
    end
    table.sort(withdrawn)
    assert(#scoped == 4, "expected 4 members that exist on iOS, got " .. #scoped)
    assert(table.concat(withdrawn, ",") == "fx_gone", "expected only fx_gone unavailable among the methods, got " .. table.concat(withdrawn, ","))
    assert(not generate.exists_on_ios({kind = "instance method", container = "FXGone", name = "fx_inside", flags = "", intro = nil}, unavailable),
        "a method of an unavailable class exists on iOS")
    assert(generate.exists_on_ios({kind = "instance method", container = "FXRoot", name = "fx_old", flags = "", intro = 5000}, unavailable),
        "a member introduced in iOS 5.0 does not exist on iOS")

    local names = generate.implemented_names()
    assert(names.CFRunLoopObserverCreateWithHandler, "a C function that src/Foundation implements is not among the implemented names, so the skeleton would stub it again")

    local objects = path.join(workspace.scratch(), "backports-test-objects")
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
    assert(#missing == 2 and missing[1] == "fx_later" and missing[2] == "fx_old", "expected fx_later and fx_old to be the missing members, got " .. table.concat(missing, ","))

    local cache = path.join(workspace.scratch(), "backports-test")
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
