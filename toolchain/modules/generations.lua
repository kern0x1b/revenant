-- Generations of a published folder, with the design of the package store (xmake's patch 0015, packages/x/xmake): the
-- store's code is methods of xmake's package instances, which the emulator's golden images do not have, so the same
-- design is kept here in its own words.
--
-- A published name is a link to a generation: the sibling folder <published>.g<token>, which holds the files. A build
-- makes its generation beside the published one and publishes it by swapping the link with one rename, so a reader
-- gets the old generation or the new one, whole. A reader holds a generation with a shared lock on <generation>.lock
-- while it uses it. A generation that a publish replaces stays for a grace period, REVENANT_GENERATION_GRACE seconds
-- (an hour by default), counted from the time it was replaced, and is removed after that once no reader holds it.
-- A folder from before generations existed is a generation too: publishing moves it aside.
--
-- A build holds the lock of its generation from begin to publish or abort, so a sweep leaves it alone. Every sweep and
-- every build of a name is made under <published>.build.lock, which the caller takes (emulator.lua): that serializes the
-- builds of one name and keeps two sweeps of it from running at once.

local REPLACED = ".replaced"
local DEFAULT_GRACE = 3600

function grace()
    return tonumber(os.getenv("REVENANT_GENERATION_GRACE")) or DEFAULT_GRACE
end

-- the generation a published name resolves to now, or nil
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

-- the inode of the file the path names now, or nil when it names none
local function named_inode(path)
    if not os.isfile(path) then
        return nil
    end
    local lock = io.openlock(path)
    local inode = lock:inode()
    lock:close()
    return inode
end

-- take the lock of a path that its holders remove. The lock is taken on the file the path names, and kept only when the
-- path still names that file once the lock is held: a waiter that was blocked on a file a holder has removed finds the
-- path gone or replaced, releases the old file, and takes the lock of the file that replaced it. With try, a lock held by
-- another session is not waited for, and nil is returned. With shared, the lock is a shared one.
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
            -- a lock of a module, which runs in xmake's sandbox, returns nothing when it is taken and raises when it is not
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

-- take the lock of a path, waiting for it, shared or exclusive
function take(path, shared)
    return take_lock(path, false, shared)
end

-- take the lock of a path if no other session holds it, or return nil
function try_take(path)
    return take_lock(path, true, false)
end

-- remove a lock file while the caller holds its lock, then release the lock: a session waiting on the removed file takes
-- the lock of the file that replaces it, if any
function drop(path, lock)
    os.tryrm(path)
    release(lock)
end

-- read a generation for as long as the caller holds the lock: a sweep does not remove it meanwhile
function hold(generation)
    return take_lock(generation .. ".lock", false, true)
end

-- rename one name over another in one step. xmake's os.rename does not move a link or a folder, and os.mv moves a link
-- into the folder it names when the destination is a link to a folder; mv -h replaces the destination link itself.
local function rename(source, destination)
    return try {function () os.execv("mv", {"-f", "-h", source, destination}) return true end,
                catch {function () return false end}}
end

-- remove a folder whose files nothing else has open
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

-- take the current generation out of the published name, and keep it for its readers; the folder that was published
-- before generations existed moves aside, since a link cannot replace a folder in one rename
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
        -- the readers of a real folder hold <published>.lock, which moves with it, so that they keep their hold on it
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

-- remove the generations of a published name that nothing reads: those no publish has replaced, which only an
-- abandoned build leaves, and those replaced for longer than the grace period. A generation a reader holds stays.
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
    -- a reader that waited on the lock of a generation which a sweep removed makes that lock file again when it retries,
    -- and nothing else removes it: the lock files of generations that are gone are removed here, each under its own lock
    for _, file in ipairs(os.files(published .. ".g*.lock")) do
        if not os.isdir(file:sub(1, #file - #".lock")) then
            local lock = try_take(file)
            if lock then
                drop(file, lock)
            end
        end
    end
end

-- begin a generation for a build of the published name, after the abandoned ones of earlier builds are gone. The build
-- holds the lock of the generation until it publishes or aborts, so a sweep leaves the generation alone meanwhile.
function begin(published)
    sweep(published)
    local generation = published .. ".g" .. hash.rand32()
    os.mkdir(generation)
    return generation, take(generation .. ".lock")
end

-- abandon a generation that a build has not published, or whose publish failed after the link moved; the generation that
-- is published stays. The lock of the generation is released either way, and removed with the generation it locks.
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

-- publish a generation a build has made: the published name becomes a link to it, in one rename. The caller releases the
-- lock of the generation after this returns.
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

-- unpublish the name: its generation stays for its readers, and is removed by a later sweep
function unpublish(published)
    displace(published)
    if os.islink(published) then
        os.tryrm(published)
    end
end

-- whether nothing of the published name is left: no link, no folder and no generation
function empty(published)
    return not os.islink(published) and not os.isdir(published) and #generations_of(published) == 0
end
