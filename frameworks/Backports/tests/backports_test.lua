local tools = path.absolute(path.join(os.scriptdir(), "..", "tools"))
local facts = import("facts", {rootdir = tools, anonymous = true})
local ast = import("ast", {rootdir = tools, anonymous = true})
local sdkfiles = import("sdk", {rootdir = tools, anonymous = true})

local VERSION = "26.2"

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

    local keys = facts.src_keys(sdk, VERSION, path.join(data, "src", "Fixture", "Fixture.m"))
    local implemented, missing = 0, {}
    for _, row in ipairs(scoped) do
        local key = row.kind .. "|" .. row.container .. "|" .. row.name
        if keys[key] then
            implemented = implemented + 1
        else
            table.insert(missing, row.name)
        end
    end
    assert(implemented == 2, "expected 2 implemented members, got " .. implemented)
    assert(#missing == 1 and missing[1] == "fx_later", "expected fx_later to be the only missing member")

    print("backports tests passed: extracted " .. #rows .. " facts, Y=" .. #scoped .. ", X=" .. implemented)
end
