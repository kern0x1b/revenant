import("core.base.json")
import("net.http")

local USAGE = [==[usage: ./xmakew l frameworks/WebKit/tools/port-delta.lua [--tree DIR] [--unguarded [AREA]] [--freshness]
  how much the patch series in third_party/webkit/patches changes upstream WebKit: by area, by kind,
  and how much of it carries the WEBKIT_IOS6 guard in the patched tree (the installed webkit package's
  unless --tree names one). --unguarded lists the changed files under AREA (default Source) that carry
  no guard, largest first, LIMIT of them (default 40); --freshness asks GitHub how far upstream main
  has moved past the base commit.]==]

local function area_of(file)
    local first, second = file:match("^([^/]+)/([^/]+)")
    return first and (first .. "/" .. second) or (file .. "/")
end

local function recipe_base(tree)
    local text = io.readfile(tree.recipe())
    return text:match("local commit = \"(%x+)\""), text:match("add_versions%(\"([^\"]+)\"")
end

function series(folder)
    local files, order = {}, {}
    local patches = os.files(path.join(folder, "*.patch"))
    table.sort(patches)
    for _, patch in ipairs(patches) do
        local lines = io.readfile(patch):split("\n", {strict = true})
        local index, current = 1, nil
        while index <= #lines do
            local line = lines[index]
            local a, b = line:match("^diff %-%-git a/(.-) b/(.+)$")
            if a then
                current = files[b]
                if not current then
                    current = {name = b, added = 0, deleted = 0, kind = "M"}
                    files[b] = current
                    table.insert(order, b)
                end
                index = index + 1
            elseif current and line:startswith("new file mode") then
                current.kind = "A"
                index = index + 1
            elseif current and line:startswith("deleted file mode") then
                current.kind = "D"
                index = index + 1
            elseif current and line:startswith("@@ ") then
                local old_count = tonumber(line:match("^@@ %-%d+,(%d+)") or (line:match("^@@ %-%d+ ") and "1") or "0")
                local new_count = tonumber(line:match("^@@ %-[%d,]+ %+%d+,(%d+)") or (line:match("^@@ %-[%d,]+ %+%d+ ") and "1") or "0")
                index = index + 1
                while (old_count > 0 or new_count > 0) and index <= #lines do
                    local body = lines[index]
                    local first = body:sub(1, 1)
                    if first == "+" then
                        current.added = current.added + 1
                        new_count = new_count - 1
                    elseif first == "-" then
                        current.deleted = current.deleted + 1
                        old_count = old_count - 1
                    elseif first ~= "\\" then
                        old_count = old_count - 1
                        new_count = new_count - 1
                    end
                    index = index + 1
                end
            else
                index = index + 1
            end
        end
    end
    local found = {}
    for _, name in ipairs(order) do
        table.insert(found, files[name])
    end
    return found, #patches
end

local function guarded(source, wanted)
    local found = {}
    local carry = import("carry", {rootdir = path.join(os.scriptdir(), "..", "src", "modules"), anonymous = true})
    for _, line in ipairs(carry.files_containing(path.join(source, "Source"), wanted)) do
        found[path.relative(line, source)] = true
    end
    return found
end

local function sorted_by(rows, key)
    table.sort(rows, function (a, b)
        if a[key] ~= b[key] then
            return a[key] > b[key]
        end
        return a.name > b.name
    end)
    return rows
end

local function report_size(files, count, base, version, source)
    local added, deleted = 0, 0
    for _, file in ipairs(files) do
        added = added + file.added
        deleted = deleted + file.deleted
    end
    print(string.format("port delta: %d patches against upstream WebKit %s (%s)", count, base, version))
    print(string.format(" %d files changed, %d insertions(+), %d deletions(-) over the series", #files, added, deleted))
    print("")
    print("by area:")
    local areas, rows = {}, {}
    for _, file in ipairs(files) do
        local area = area_of(file.name)
        local row = areas[area]
        if not row then
            row = {name = area, files = 0, added = 0, deleted = 0}
            areas[area] = row
            table.insert(rows, row)
        end
        row.files = row.files + 1
        row.added = row.added + file.added
        row.deleted = row.deleted + file.deleted
    end
    for index, row in ipairs(sorted_by(rows, "files")) do
        if index > 12 then
            break
        end
        print(string.format("  %-34s %5d files  +%-7d -%d", row.name, row.files, row.added, row.deleted))
    end
    print("")
    local kinds = {M = 0, A = 0, D = 0}
    for _, file in ipairs(files) do
        kinds[file.kind] = kinds[file.kind] + 1
    end
    print("kind of change:")
    print(string.format("  %d modified, %d added, %d deleted", kinds.M, kinds.A, kinds.D))
    local marked = guarded(source, "defined(WEBKIT_IOS6)")
    local changed, carrying, bare = 0, 0, {}
    for _, file in ipairs(files) do
        if file.name:startswith("Source/") and file.kind ~= "D" then
            changed = changed + 1
            if marked[file.name] then
                carrying = carrying + 1
            else
                local area = area_of(file.name)
                bare[area] = (bare[area] or 0) + 1
            end
        end
    end
    print("")
    print("how much of it announces itself:")
    print(string.format("  %5d files changed under Source", changed))
    print(string.format("  %5d of them carry the WEBKIT_IOS6 guard", carrying))
    print(string.format("  %5d do not - these are the ones a conflict has to be read by hand in", changed - carrying))
    print("")
    print("  the unguarded ones, by area:")
    local by_area = {}
    for area, number in pairs(bare) do
        table.insert(by_area, {name = area, count = number})
    end
    for index, row in ipairs(sorted_by(by_area, "count")) do
        if index > 8 then
            break
        end
        print(string.format("    %-32s %d", row.name, row.count))
    end
end

local function report_unguarded(files, area, source)
    local limit = tonumber(os.getenv("LIMIT") or "40")
    if not limit or limit <= 0 or math.floor(limit) ~= limit then
        raise("LIMIT has to be a positive number of lines, not %s", os.getenv("LIMIT"))
    end
    print("changed files under " .. area .. " that carry no WEBKIT_IOS6 guard, largest first")
    print("  these are the ones a conflict here has to be read by hand")
    local marked = guarded(source, "WEBKIT_IOS6")
    local rows = {}
    for _, file in ipairs(files) do
        if (file.name == area or file.name:startswith(area .. "/")) and not marked[file.name] then
            table.insert(rows, {name = file.name, total = file.added + file.deleted})
        end
    end
    for index, row in ipairs(sorted_by(rows, "total")) do
        if index > limit then
            break
        end
        print(string.format("%d\t%s", row.total, row.name))
    end
end

local function report_freshness(base, version)
    local answer = os.tmpfile() .. ".json"
    http.download("https://api.github.com/repos/WebKit/WebKit/compare/" .. base .. "...main", answer)
    local compared = json.loadfile(answer)
    os.tryrm(answer)
    print("how fresh the base is, against WebKit/WebKit main")
    print(string.format("  base:        %s, the version %s of the webkit package", base, version))
    print(string.format("  main is:     %s commits ahead of it", tostring(compared.ahead_by)))
    if compared.behind_by and compared.behind_by > 0 then
        print(string.format("  and %d commits of the base are not on main", compared.behind_by))
    end
end

function main(...)
    local tree = import("lib.tree", {rootdir = os.scriptdir(), anonymous = true})
    local argv = {...}
    local unguarded
    for index, given in ipairs(argv) do
        if given == "--unguarded" then
            unguarded = argv[index + 1] and not argv[index + 1]:startswith("--") and table.remove(argv, index + 1) or "Source"
            table.remove(argv, index)
            break
        end
    end
    local given = tree.arguments(argv, {tree = "value", freshness = "switch", help = "switch"})
    if given.help then
        print(USAGE)
        return
    end
    local base, version = recipe_base(tree)
    if given.freshness then
        report_freshness(base, version)
        return
    end
    local files, count = series(tree.patches())
    local source = tree.engine_source(given.tree)
    if unguarded then
        report_unguarded(files, unguarded, source)
    else
        report_size(files, count, base, version, source)
    end
end
