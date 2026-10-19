-- xmake l tools/registry-one-minimum.lua [--framework NAME] [ROOT]
--
-- The gate's 4.3 rule over a whole tree: an object is carried from one release on, and its minimum
-- is read from the entries the symbols it carries answer to, so within one object those entries all
-- name the same minimum or none of them names one. A set holding both none and a value, or two
-- values, is what minimums() refuses as misplaced. This prints those objects and exits 1.
--
--   NSURLSessionWebSocket13.m: ... rows name the minimums 5.0 and 6.0 - NSURLSession (5.0), ...
--   WKContentWorld14.m:        ... rows name the minimums 6.0 and none - WKContentWorld (6.0), ...
--
-- It is a tool and not a guard test on purpose. The rule is the gate's, and a guard that holds the
-- whole repository to it is red on objects the gate itself carries in a stack - four of them, none of
-- them in CloudKit. This reports them and leaves landing them to whoever owns the object.
-- tests/addon/registry_test.lua proves the rule on synthetic objects, which is where a rule of this
-- shape is settled, and calls the same offenders() this calls.
--
-- ROOT is resolved against the current directory and, failing that, against the PROJECT's own root,
-- which is where xmake found this project however the run was invoked - so an absolute ROOT and a run
-- from any directory of the project both land on the package. Reading nothing is never a clean bill of health: a run that read zero objects prints a
-- different sentence and exits non-zero, because "nothing is owed" and "nothing was read" must never
-- print the same line.
--
-- Objects are the files, so the grouping is by the file that DEFINES a class and never by the row's
-- `source` field: that field is a transcription, it can be wrong, and eight were - the rows of
-- CKSyncEngineConfiguration and of the six scopes, options and contexts named CKSyncEngine17.m while
-- CKSyncEngine.m and CKSyncEngineState17.m define them - which is how a check keyed on it reads clean
-- over an object the gate refuses. A class two files implement is carried by both, so both are asked.

import("core.base.json")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "modules")})

-- The registry files the gate reads: registry/<Framework>.json and registry/<Framework>/<part>.json
local function registry_files(root)
    return table.join(os.files(path.join(root, "registry", "*.json")),
                      os.files(path.join(root, "registry", "*/*.json")))
end

-- api -> the entries filed under that spelling, each with the registry it was read from
function rows_of(root, framework)
    local rows = {}
    local files = registry_files(root)
    byteorder.sort(files)                     -- sorts in place and returns nothing
    for _, file in ipairs(files) do
        local folder = path.filename(path.directory(file))
        local name = folder == "registry" and path.basename(file) or folder
        if not framework or name == framework then
            local held = json.decode(io.readfile(file))
            for _, entry in ipairs(held.entries or held) do
                rows[entry.api] = rows[entry.api] or {}
                table.insert(rows[entry.api], {registry = file, entry = entry})
            end
        end
    end
    return rows
end

-- class -> the source files that define it
function definitions(root, framework)
    local defines = {}
    for _, file in ipairs(os.files(path.join(root, "*/*.m"))) do
        if not framework or path.basename(path.directory(file)) == framework then
            -- comments go first: a sentence beginning "// @implementation" is not a definition
            local text = io.readfile(file):gsub("//[^\n]*", "")
            for cls in text:gmatch("@implementation%s+(%w+)") do
                local places = defines[cls]
                if not places then
                    places = {}
                    defines[cls] = places
                end
                if not table.contains(places, file) then
                    table.insert(places, file)
                end
            end
        end
    end
    return defines
end

-- The objects that mix: {{object = file, minimums = {...}, names = {...}}}, and how many objects
-- were read. offenders() is what tests/addon/registry_test.lua drives on synthetic objects.
function offenders(root, framework)
    local defines = definitions(root, framework)
    local objects, order = {}, {}
    for api, held in pairs(rows_of(root, framework)) do
        for _, file in ipairs(defines[api] or {}) do
            local by = objects[file]
            if not by then
                by = {minimums = {}, names = {}}
                objects[file] = by
                table.insert(order, file)
            end
            for _, one in ipairs(held) do
                local minimum = one.entry.minimum or "none"
                by.minimums[minimum] = true
                table.insert(by.names, string.format("%s (%s)", api, minimum))
            end
        end
    end
    local found = {}
    for _, file in ipairs(order) do
        local by = objects[file]
        local all, values = {}, 0
        for minimum in pairs(by.minimums) do
            table.insert(all, minimum)
            if minimum ~= "none" then
                values = values + 1
            end
        end
        if #all > 0 and (values > 1 or (values > 0 and by.minimums["none"])) then
            byteorder.sort(all)
            byteorder.sort(by.names)
            table.insert(found, {object = file, minimums = all, names = by.names})
        end
    end
    return found, #order
end

function main(...)
    local framework, root
    local args = {...}
    local index = 1
    while index <= #args do
        local value = args[index]
        if value == "--framework" then
            framework = args[index + 1]
            index = index + 2
        elseif not value:match("^%-") then
            root = value
            index = index + 1
        else
            index = index + 1
        end
    end
    -- the package, wherever this was run from: the given ROOT, else the default relative to the cwd,
    -- else the default relative to this script
    local package = "packages/a/apple-backports"
    local candidates = {}
    if root then
        table.insert(candidates, root)
    else
        table.insert(candidates, package)
        table.insert(candidates, path.join(os.projectdir() or ".", package))
    end
    local chosen
    for _, candidate in ipairs(candidates) do
        if os.isdir(path.join(candidate, "registry")) then
            chosen = candidate
            break
        end
    end
    if not chosen and root then
        print(string.format("registry-one-minimum: read nothing - %s is not a package (no registry"
            .. " under it)", root))
        os.exit(1)
    end
    if not chosen then
        print(string.format("registry-one-minimum: read nothing - no package at %s;"
            .. " pass the path to packages/a/apple-backports", table.concat(candidates, " or ")))
        os.exit(1)
    end
    root = chosen
    local found, objects = offenders(root, framework)
    for _, one in ipairs(found) do
        print(string.format("%s: an object is carried from one release on, and its rows name the"
                            .. " minimums %s - %s", one.object, table.concat(one.minimums, " and "),
                            table.concat(one.names, ", ")))
    end
    print(string.format("registry-one-minimum: %d object(s) with rows read%s, %d mixing%s", objects,
                        framework and (" (" .. framework .. ")") or "", #found,
                        #found == 1 and "" or "s"))
    if objects == 0 then
        print("registry-one-minimum: read nothing - the registry of " .. root .. " names no object with"
              .. " a row, which is a read that measured nothing and not a tree that owes nothing")
        os.exit(1)
    end
    os.exit(#found == 0 and 0 or 1)
end
