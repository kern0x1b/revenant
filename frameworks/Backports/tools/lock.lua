local function start_of(pid)
    local text = os.iorunv("/bin/ps", {"-o", "lstart=", "-p", tostring(pid)}, {try = true}) or ""
    return text:trim()
end

local function lockfile(root, key)
    return path.join(root, key .. ".lock")
end

local function holderfile(root, key)
    return path.join(root, key .. ".holder")
end

local function describe(root, key)
    local holder = holderfile(root, key)
    if not os.isfile(holder) then
        return "whose holder recorded no process (it has only just started, or it is an older run)"
    end
    local pid, began, lstart = string.match(io.readfile(holder), "^(%d+) (%d+) (.+)$")
    if not pid then
        return "whose holder could not be read"
    end
    local elapsed = os.time() - tonumber(began)
    if lstart ~= "" and start_of(pid) == lstart then
        return string.format("which process %s has held for %d s", pid, elapsed)
    end
    return string.format("which process %s held for %d s and has ended (its number is free or has been reused), while a process it started still holds the lock", pid, elapsed)
end

function held(root, key)
    local file = lockfile(root, key)
    local lock = io.openlock(file)
    if not lock then
        raise("cannot open the lock %s", file)
    end
    if lock:trylock() then
        lock:unlock()
        lock:close()
        return false
    end
    lock:close()
    return true
end

function attempt(root, key, work)
    local file = lockfile(root, key)
    os.mkdir(path.directory(file))
    local lock = io.openlock(file)
    if not lock then
        raise("cannot open the lock %s", file)
    end
    if not lock:trylock() then
        lock:close()
        return false
    end
    local results, failure
    try {
        function ()
            results = table.pack(work())
        end,
        catch {
            function (errors)
                failure = tostring(errors)
            end
        }
    }
    lock:unlock()
    lock:close()
    if failure then
        raise("%s", failure)
    end
    return true, table.unpack(results, 1, results.n)
end

function run(root, key, work, opt)
    opt = opt or {}
    local wait = opt.wait or 1800
    local poll = opt.poll or 1
    local file = lockfile(root, key)
    os.mkdir(path.directory(file))
    local lock = io.openlock(file)
    if not lock then
        raise("cannot open the lock %s", file)
    end
    local pid = os.getpid()
    local began, lstart = os.time(), start_of(pid)
    local waited, announced, reported = 0, false, 0
    while not lock:trylock() do
        if not announced then
            print(string.format("waiting for %s: %s is held by %s", key, file, describe(root, key)))
            announced = true
        end
        os.sleep(poll * 1000)
        waited = waited + poll
        if waited - reported >= 30 then
            print(string.format("still waiting for %s after %d s: %s", key, waited, describe(root, key)))
            reported = waited
        end
        if waited >= wait then
            lock:close()
            raise("gave up on %s after %d s: if the holder has hung, stop the process named above and run this again", key, waited)
        end
    end
    local holder = holderfile(root, key)
    local temp = holder .. "." .. pid .. "." .. hash.strhash128(tostring({}) .. holder)
    io.writefile(temp, string.format("%d %d %s\n", pid, began, lstart))
    os.mv(temp, holder)
    local results, failure
    try {
        function ()
            results = table.pack(work())
        end,
        catch {
            function (errors)
                failure = tostring(errors)
            end
        }
    }
    os.tryrm(holder)
    lock:unlock()
    lock:close()
    if failure then
        raise("%s", failure)
    end
    return table.unpack(results, 1, results.n)
end
