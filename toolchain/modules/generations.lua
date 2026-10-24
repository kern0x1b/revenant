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

-- read a generation for as long as the caller holds the lock: a sweep does not remove it meanwhile
function hold(generation)
    local lock = io.openlock(generation .. ".lock")
    lock:lock({shared = true})
    return lock
end

function release(lock)
    lock:unlock()
    lock:close()
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
            local lock = io.openlock(folder .. ".lock")
            if lock and lock:trylock() then
                discard(folder)
                lock:unlock()
                lock:close()
                os.tryrm(folder .. ".lock")
            elseif lock then
                lock:close()
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
    local lock = io.openlock(generation .. ".lock")
    lock:lock()
    return generation, lock
end

-- abandon a generation that a build has not published, or whose publish failed after the link moved; the generation that
-- is published stays. The lock of the generation is released either way.
function abort(published, generation, lock)
    if resolve(published) ~= generation then
        discard(generation)
    end
    release(lock)
    if not os.isdir(generation) then
        os.tryrm(generation .. ".lock")
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
