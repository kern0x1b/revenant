local function finished(lock, results, failure)
    lock:unlock()
    lock:close()
    if failure then
        raise("%s", failure)
    end
    return table.unpack(results, 1, results.n)
end

function attempt(file, work)
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
    return true, finished(lock, results, failure)
end

function held(file)
    os.mkdir(path.directory(file))
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

function run(file, label, work)
    os.mkdir(path.directory(file))
    local lock = io.openlock(file)
    if not lock then
        raise("cannot open the lock %s", file)
    end
    local announced = false
    while not lock:trylock() do
        if not announced then
            print("waiting for %s: %s is held by another process", label, file)
            announced = true
        end
        os.sleep(100)
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
    return finished(lock, results, failure)
end
