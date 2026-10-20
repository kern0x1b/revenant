import("core.base.json")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "modules")})

local function registry_files(root)
    return table.join(os.files(path.join(root, "registry", "*.json")),
                      os.files(path.join(root, "registry", "*/*.json")))
end

function rows_of(root, framework)
    local rows = {}
    local files = registry_files(root)
    byteorder.sort(files)
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

function definitions(root, framework)
    local defines = {}
    for _, file in ipairs(os.files(path.join(root, "*/*.m"))) do
        if not framework or path.basename(path.directory(file)) == framework then
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
    local package = "packages/frameworks/apple-backports"
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
            .. " pass the path to packages/frameworks/apple-backports", table.concat(candidates, " or ")))
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
