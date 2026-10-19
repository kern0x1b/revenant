local lib = import("vtlib", {rootdir = os.scriptdir(), anonymous = true})
local json = import("core.base.json")

local HERE = os.scriptdir()
local WORKTREE = path.join(HERE, "..", "..", "..", "..")
local PACKAGE = path.join(WORKTREE, "packages", "a", "apple-backports")

local PREFIX = "VideoToolboxConstants"

local function file_release(file)
    local name = path.filename(file)
    local middle = name:match("^" .. PREFIX .. "(.*)%.m$")
    if not middle then
        return nil
    end
    local parts = lib.split_text(middle, "_")
    if #parts < 2 then
        return nil
    end
    for _, part in ipairs(parts) do
        if not part:match("^%d+$") then
            return nil
        end
    end
    return table.concat(parts, ".")
end

local function registry_releases(registry)
    local found = {}
    for _, file in ipairs(lib.files_matching(registry, "*.json")) do
        local data = json.decode(lib.read_text(file))
        for _, row in ipairs(data.entries or {}) do
            if row.kind == "constant" then
                found[row.api] = row.introduced
            end
        end
    end
    return found
end

local function check(objects, registry)
    local releases = registry_releases(registry)
    local problems, defined = {}, {}
    local files = lib.files_matching(objects, PREFIX .. "*.m")
    local definedCount = 0
    for _, file in ipairs(files) do
        local base = path.filename(file)
        local release = file_release(file)
        if release == nil then
            problems[#problems + 1] = base .. ": a file of constants whose name does not say a release"
        else
            for _, line in ipairs(lib.split_text(lib.read_text(file), "\n")) do
                local name = line:match("^const CFStringRef ([%w_]+) = CFSTR")
                if name then
                    if defined[name] then
                        problems[#problems + 1] = string.format("%s is defined twice: %s and %s", name, defined[name], base)
                    else
                        definedCount = definedCount + 1
                    end
                    defined[name] = base
                    if releases[name] == nil then
                        problems[#problems + 1] = string.format("%s (in %s) has no registry row", name, base)
                    elseif releases[name] ~= release then
                        problems[#problems + 1] = string.format("%s is in %s but its row says %s", name, base, releases[name])
                    end
                end
            end
        end
    end
    local rowCount = 0
    for _ in pairs(releases) do
        rowCount = rowCount + 1
    end
    print(string.format("%d constants defined by %d files, %d registry rows of kind constant", definedCount, #files, rowCount))
    return problems
end

local function control(scratch, objects, registry)
    os.rm(scratch)
    os.mkdir(scratch)
    for _, file in ipairs(lib.files_matching(objects, PREFIX .. "*.m")) do
        os.cp(file, scratch)
    end
    local before = check(scratch, registry)
    if #before > 0 then
        print("CONTROL cannot start: the copy is red before the move: " .. before[1])
        return 1
    end
    local files = lib.files_matching(scratch, PREFIX .. "*.m")
    local source, target = files[1], files[#files]
    local lines = lib.split_text(lib.read_text(source), "\n")
    local index
    for i, line in ipairs(lines) do
        if string.sub(line, 1, 18) == "const CFStringRef " then
            index = i
            break
        end
    end
    if not index then
        raise("StopIteration: no constant line in " .. path.filename(source))
    end
    local moved = table.remove(lines, index)
    local name = moved:match("^const CFStringRef ([%w_]+)")
    lib.write_text(source, table.concat(lines, "\n"))
    local handle = assert(io.open(target, "ab"))
    handle:write(moved .. "\n")
    handle:close()
    local after = check(scratch, registry)
    local named = nil
    for _, p in ipairs(after) do
        if string.sub(p, 1, #name + 1) == name .. " " then
            named = named or p
        end
    end
    print(string.format("CONTROL moved %s from %s into %s: %s", name, path.filename(source), path.filename(target),
        named or "NOT CAUGHT"))
    if named then
        return 0
    end
    return 1
end

function main(...)
    local args = { ... }
    local objects = path.join(PACKAGE, "VideoToolbox")
    local registry = path.join(PACKAGE, "registry", "VideoToolbox")
    local scratch
    for i, arg in ipairs(args) do
        if arg == "--control" then
            scratch = args[i + 1]
            if not scratch then
                raise("check-constant-files.lua: --control needs a scratch directory")
            end
        end
    end
    local problems = check(objects, registry)
    for _, problem in ipairs(problems) do
        print("FAIL " .. problem)
    end
    local status = #problems > 0 and 1 or 0
    if scratch and status == 0 then
        status = control(scratch, objects, registry)
    end
    print("check-constant-files: " .. (status ~= 0 and "RED" or "OK"))
    os.exit(status)
end
