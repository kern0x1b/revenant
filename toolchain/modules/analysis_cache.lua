import("byteorder")
import("cache")
import("exclusive")

local STALE_AFTER = 3600

function store_root(opt)
    return opt and opt.store or cache.store()
end

function home_root(opt)
    return opt and opt.home or cache.root()
end

function sdk_paths(opt)
    local pattern = path.join(store_root(opt), "xmake-global", ".xmake", "packages", "i", "iphoneos-sdk", "*", "*", "Developer.app", "Contents",
                              "Developer", "Platforms", "iPhoneOS.platform", "Developer", "SDKs", "iPhoneOS*.sdk")
    local seen, found = {}, {}
    for _, folder in ipairs(os.dirs(pattern)) do
        local real = os.iorunv("sh", {"-c", "cd \"$1\" && pwd -P", "sh", folder}):trim()
        if not seen[real] then
            seen[real] = true
            table.insert(found, real)
        end
    end
    byteorder.sort(found)
    return found
end

function folders(sdkfiles, opt)
    local home = home_root(opt)
    local found = {}
    for _, real in ipairs(sdk_paths(opt)) do
        local key = try { function () return sdkfiles.cache_key(real) end }
        if key then
            table.insert(found, path.join("backports", key))
            table.insert(found, path.relative(sdkfiles.model_cache(real), home))
        end
    end
    return found
end

local function missing_files(source, target)
    local found = {}
    for _, file in ipairs(os.files(path.join(source, "**"))) do
        local relative = path.relative(file, source)
        if not os.exists(path.join(target, relative)) then
            table.insert(found, relative)
        end
    end
    return found
end

local function clone(source, staging)
    local cloned = try { function () os.vrunv("cp", {"-c", "-R", source, staging}) return true end }
    if not cloned then
        os.tryrm(staging)
        os.vrunv("cp", {"-R", source, staging})
    end
end

local function sweep(parent)
    for _, folder in ipairs(os.dirs(path.join(parent, ".analysis-*"))) do
        if os.time() - os.mtime(folder) > STALE_AFTER then
            os.tryrm(folder)
        end
    end
end

local function adopt(staging, target, wanted)
    for _, relative in ipairs(wanted) do
        local destination = path.join(target, relative)
        os.mkdir(path.directory(destination))
        if not os.exists(destination) then
            os.mv(path.join(staging, relative), destination)
        end
    end
    os.tryrm(staging)
end

function lock_files(source, target)
    local files = {source .. ".lock", target .. ".lock"}
    byteorder.sort(files)
    return files
end

local function locked(files, work)
    local function nest(index)
        if index > #files then
            return work()
        end
        return exclusive.run(files[index], "the analysis cache " .. path.filename(files[index]), function ()
            return nest(index + 1)
        end)
    end
    return nest(1)
end

local function merge(source, target)
    if #missing_files(source, target) == 0 then
        return 0
    end
    local parent = path.directory(target)
    os.mkdir(parent)
    sweep(parent)
    local staging = path.join(parent, ".analysis-" .. hash.uuid():sub(1, 8))
    local count, failure = 0, nil
    try {
        function ()
            count = locked(lock_files(source, target), function ()
                local wanted = missing_files(source, target)
                if #wanted == 0 then
                    return 0
                end
                clone(source, staging)
                if os.isdir(target) then
                    adopt(staging, target, wanted)
                else
                    os.mv(staging, target)
                end
                os.vrunv("touch", {target})
                return #wanted
            end)
        end,
        catch {
            function (errors)
                failure = tostring(errors)
            end
        },
        finally {
            function ()
                os.tryrm(staging)
            end
        }
    }
    if failure then
        raise("%s", failure)
    end
    return count
end

local function transfer(folders, from, to)
    local moved = {}
    for _, folder in ipairs(folders) do
        local source = path.join(from, folder)
        if os.isdir(source) then
            local count = merge(source, path.join(to, folder))
            if count > 0 then
                moved[folder] = count
            end
        end
    end
    return moved
end

function restore(folders, opt)
    return transfer(folders, store_root(opt), home_root(opt))
end

function publish(folders, opt)
    return transfer(folders, home_root(opt), store_root(opt))
end

function lines_of(verb, moved, source)
    local lines = {}
    for _, folder in ipairs(table.orderkeys(moved)) do
        table.insert(lines, string.format("analysis cache: %s %d files of %s %s (copy on write)", verb, moved[folder], folder, source))
    end
    return lines
end
