local REPLACED = ".replaced"
local DEFAULT_GRACE = 3600

function grace()
    return tonumber(os.getenv("REVENANT_GENERATION_GRACE")) or DEFAULT_GRACE
end

function resolve(published)
    if os.islink(published) then
        local folder = path.join(path.directory(published), os.readlink(published))
        return os.isdir(folder) and folder or nil
    end
    return os.isdir(published) and published or nil
end

function release(lock)
    lock:unlock()
    lock:close()
end

local function named_inode(path)
    if not os.isfile(path) then
        return nil
    end
    local lock = io.openlock(path)
    local inode = lock:inode()
    lock:close()
    return inode
end

local function take_lock(path, try, shared)
    while true do
        local lock = io.openlock(path)
        if not lock then
            raise("cannot open the lock %s", path)
        end
        local taken
        if try then
            taken = lock:trylock({shared = shared})
        else
            taken = lock:lock({shared = shared}) ~= false
        end
        if not taken then
            lock:close()
            if try then
                return nil
            end
            raise("cannot lock %s", path)
        end
        local held = lock:inode()
        if not held then
            release(lock)
            raise("cannot read the inode of the lock %s", path)
        end
        if held == named_inode(path) then
            return lock
        end
        release(lock)
    end
end

function take(path, shared)
    return take_lock(path, false, shared)
end

function try_take(path)
    return take_lock(path, true, false)
end

function drop(path, lock)
    os.tryrm(path)
    release(lock)
end

function hold(generation)
    return take_lock(generation .. ".lock", false, true)
end

local function rename(source, destination)
    return try {function () os.execv("mv", {"-f", "-h", source, destination}) return true end,
                catch {function () return false end}}
end

function discard(folder)
    if os.isdir(folder) or os.isfile(folder) or os.islink(folder) then
        os.execv("chmod", {"-R", "u+rwX", folder}, {try = true})
        os.tryrm(folder)
        if os.isdir(folder) or os.isfile(folder) or os.islink(folder) then
            raise("cannot remove %s", folder)
        end
    end
end

local function generations_of(published)
    return os.dirs(published .. ".g*")
end

local function replaced_at(folder)
    local marker = path.join(folder, REPLACED)
    return os.isfile(marker) and tonumber(io.readfile(marker)) or nil
end

local function mark_replaced(folder)
    io.writefile(path.join(folder, REPLACED), tostring(os.time()))
end

local function displace(published)
    if os.islink(published) then
        local previous = resolve(published)
        if previous then
            mark_replaced(previous)
        end
        return previous
    end
    if os.isdir(published) then
        local legacy = published .. ".g" .. hash.rand32()
        if os.isfile(published .. ".lock") and not rename(published .. ".lock", legacy .. ".lock") then
            raise("cannot move the lock of %s aside", published)
        end
        if not rename(published, legacy) then
            raise("cannot move %s aside", published)
        end
        mark_replaced(legacy)
        return legacy
    end
end

function sweep(published, opt)
    opt = opt or {}
    local limit = opt.grace or grace()
    local current = resolve(published)
    local now = os.time()
    for _, folder in ipairs(generations_of(published)) do
        local replaced = replaced_at(folder)
        if folder ~= current and folder ~= opt.keep and (not replaced or now - replaced >= limit) then
            local lock = try_take(folder .. ".lock")
            if lock then
                discard(folder)
                drop(folder .. ".lock", lock)
            end
        end
    end
    for _, file in ipairs(os.files(published .. ".g*.lock")) do
        if not os.isdir(file:sub(1, #file - #".lock")) then
            local lock = try_take(file)
            if lock then
                drop(file, lock)
            end
        end
    end
end

function begin(published)
    sweep(published)
    local generation = published .. ".g" .. hash.rand32()
    os.mkdir(generation)
    return generation, take(generation .. ".lock")
end

function abort(published, generation, lock)
    if resolve(published) ~= generation then
        discard(generation)
    end
    if os.isdir(generation) then
        release(lock)
    else
        drop(generation .. ".lock", lock)
    end
end

function publish(published, generation)
    local previous = displace(published)
    local link = published .. ".t" .. hash.rand32()
    os.ln(path.filename(generation), link)
    if not rename(link, published) then
        os.tryrm(link)
        raise("cannot publish %s", published)
    end
    sweep(published, {keep = previous})
end

function unpublish(published)
    displace(published)
    if os.islink(published) then
        os.tryrm(published)
    end
end

function empty(published)
    return not os.islink(published) and not os.isdir(published) and #generations_of(published) == 0
end
