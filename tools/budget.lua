local TOKEN_MB = 1536
local RESERVE_MB = 2048
local RESERVE_CORES = 2
local DISK_FLOOR_GB = 100
local PATIENCE_S = 300
local POLL_MS = 1000
local NICE = "/usr/bin/nice"
local TASKPOLICY = "/usr/sbin/taskpolicy"
local CLOSE_INHERITED = 'i=3; while [ $i -lt 256 ]; do eval "exec $i>&-" 2>/dev/null; i=$((i+1)); done; exec "$@"'

local CLASSES = {
    critical = {rank = 1, nice = 0},
    normal = {rank = 2, nice = 5},
    background = {rank = 3, nice = 15, background = true},
}

local function cache()
    return import("@addon.revenant.cache", {anonymous = true})
end

local function pool_folder()
    return os.getenv("REVENANT_BUDGET_POOL") or path.join(cache().checkout(), ".cache", "budget")
end

local function slot_path(folder, index)
    return path.join(folder, string.format("slot-%02d.lock", index))
end

local function free_memory_mb()
    local out = os.iorunv("vm_stat", {})
    local size = tonumber(out:match("page size of (%d+) bytes")) or 4096
    local pages = 0
    for _, name in ipairs({"free", "inactive", "speculative"}) do
        pages = pages + (tonumber(out:match("Pages " .. name .. ":%s+(%d+)")) or 0)
    end
    return math.floor(pages * size / (1024 * 1024))
end

local function idle_cores(cores)
    local out = try { function () return os.iorunv("top", {"-l", "2", "-s", "1", "-n", "0"}) end } or ""
    local idle
    for value in out:gmatch("([%d%.]+)%% idle") do
        idle = tonumber(value)
    end
    return cores * (idle or 0) / 100
end

local function free_disk_gb()
    local out = os.iorunv("df", {"-Pk", cache().checkout()})
    local fields = {}
    for field in out:match("[^\n]*\n([^\n]+)"):gmatch("%S+") do
        table.insert(fields, field)
    end
    return tonumber(fields[4]) / (1024 * 1024)
end

local function disk_refused(free_gb, floor)
    return free_gb < floor
end

local function capacity(opt)
    local limit = opt.cores - RESERVE_CORES
    local by_memory = opt.held + math.floor(math.max(0, opt.free_mb - RESERVE_MB) / TOKEN_MB)
    local by_cpu = opt.waited and limit or (opt.held + math.floor(opt.idle))
    local cap = math.min(limit, by_cpu, by_memory)
    if opt.held == 0 then
        cap = math.max(cap, 1)
    end
    return cap
end

local function grantable(cap, held, free, minimum, maximum)
    local count = math.min(math.max(cap - held, 0), free, maximum)
    if count < minimum then
        return 0
    end
    return count
end

local function tokens_wanted(opt, cores)
    local limit = cores - RESERVE_CORES
    local minimum = math.max(opt.min or 1, math.ceil((opt.mb or 0) / TOKEN_MB))
    local maximum = math.max(opt.jobs or minimum, minimum)
    return math.min(minimum, limit), math.min(maximum, limit)
end

local function enqueue(folder, rank)
    local dir = path.join(folder, "queue")
    os.mkdir(dir)
    local name = string.format("%d-%013d-%08d.ticket", rank, os.time() * 1000 + math.random(0, 999), math.random(0, 99999999))
    local file = path.join(dir, name)
    local lock = io.openlock(file)
    lock:trylock()
    return {name = name, file = file, lock = lock}
end

local function leave(ticket)
    os.tryrm(ticket.file)
    ticket.lock:unlock()
    ticket.lock:close()
end

local function holder_alive(file)
    local lock = io.openlock(file)
    if not lock then
        return false
    end
    local free = lock:trylock()
    if free then
        lock:unlock()
    end
    lock:close()
    if free then
        os.tryrm(file)
    end
    return not free
end

local function ahead_of(folder, name)
    for _, file in ipairs(os.files(path.join(folder, "queue", "*.ticket"))) do
        if path.filename(file) < name and holder_alive(file) then
            return true
        end
    end
    return false
end

local function try_grant(folder, minimum, maximum, waited)
    local cores = os.cpuinfo("ncpu")
    local free_locks, held = {}, 0
    local snapshot = {cores = cores, idle = idle_cores(cores), free_mb = free_memory_mb(), waited = waited}
    for index = 1, cores - RESERVE_CORES do
        local lock = io.openlock(slot_path(folder, index))
        if lock and lock:trylock() then
            table.insert(free_locks, lock)
        else
            held = held + 1
            if lock then
                lock:close()
            end
        end
    end
    snapshot.held = held
    local count = grantable(capacity(snapshot), held, #free_locks, minimum, maximum)
    local grant = {}
    for index, lock in ipairs(free_locks) do
        if index <= count then
            table.insert(grant, lock)
        else
            lock:unlock()
            lock:close()
        end
    end
    return grant
end

local function acquire(folder, class, minimum, maximum)
    local ticket = enqueue(folder, CLASSES[class].rank)
    local started = os.mclock()
    local patience = (tonumber(os.getenv("REVENANT_BUDGET_PATIENCE")) or PATIENCE_S) * 1000
    local announced
    while true do
        local waited = os.mclock() - started >= patience
        if not ahead_of(folder, ticket.name) then
            local grant = try_grant(folder, minimum, maximum, waited)
            if #grant > 0 then
                leave(ticket)
                return grant
            end
        end
        if not announced then
            print("budget: waiting for %d token(s), %s class", minimum, class)
            announced = true
        end
        os.sleep(POLL_MS)
    end
end

local function launch(class, command)
    local program, args = command[1], table.slice(command, 2)
    if class.nice > 0 then
        args = table.join({"-n", tostring(class.nice), program}, args)
        program = NICE
    end
    if class.background then
        args = table.join({"-b", program}, args)
        program = TASKPOLICY
    end
    return "/bin/sh", table.join({"-c", CLOSE_INHERITED, "budget", program}, args)
end

local function run(opt)
    local class = CLASSES[opt.class]
    local inherited = tonumber(os.getenv("REVENANT_BUDGET_HELD"))
    local locks = {}
    local count = inherited
    if not inherited then
        local free = free_disk_gb()
        local floor = tonumber(os.getenv("REVENANT_BUDGET_DISK_GB")) or DISK_FLOOR_GB
        if disk_refused(free, floor) then
            raise("budget: %.0f GB free on the checkout's volume, below the %d GB floor, so no heavy command starts", free, floor)
        end
        local minimum, maximum = tokens_wanted(opt, os.cpuinfo("ncpu"))
        locks = acquire(pool_folder(), opt.class, minimum, maximum)
        count = #locks
    end
    local program, args = launch(class, opt.command)
    local status = os.execv(program, args, {envs = {XMAKE_MAX_JOBS = tostring(count), REVENANT_BUDGET_HELD = tostring(count)}, try = true})
    for _, lock in ipairs(locks) do
        lock:unlock()
        lock:close()
    end
    return status or 1
end

local function parse_run(args)
    local opt = {class = "normal"}
    local index = 1
    while index <= #args do
        local arg = args[index]
        if arg == "--" then
            opt.command = table.slice(args, index + 1)
            break
        end
        local value = args[index + 1]
        if arg == "--class" and CLASSES[value or ""] then
            opt.class = value
        elseif arg == "--jobs" and tonumber(value) then
            opt.jobs = tonumber(value)
        elseif arg == "--min" and tonumber(value) then
            opt.min = tonumber(value)
        elseif arg == "--mb" and tonumber(value) then
            opt.mb = tonumber(value)
        else
            raise("usage: ./xmakew l -P . tools/budget.lua run [--class critical|normal|background] [--jobs N] [--min N] [--mb M] -- <command> [args...]")
        end
        index = index + 2
    end
    if not opt.command or #opt.command == 0 then
        raise("budget run needs a command after --")
    end
    return opt
end

local function held_slots(folder)
    local count = 0
    for index = 1, os.cpuinfo("ncpu") - RESERVE_CORES do
        local lock = io.openlock(slot_path(folder, index))
        if lock then
            if lock:trylock() then
                lock:unlock()
            else
                count = count + 1
            end
            lock:close()
        end
    end
    return count
end

local function queued(folder)
    return #os.files(path.join(folder, "queue", "*.ticket"))
end

local function status()
    local folder = pool_folder()
    local cores = os.cpuinfo("ncpu")
    local held = held_slots(folder)
    local snapshot = {cores = cores, held = held, idle = idle_cores(cores), free_mb = free_memory_mb(), waited = false}
    print("pool      %s", folder)
    print("cores     %d (reserve %d)", cores, RESERVE_CORES)
    print("memory    %d MB free or inactive (reserve %d MB, one token %d MB)", snapshot.free_mb, RESERVE_MB, TOKEN_MB)
    print("cpu       %.1f idle cores", snapshot.idle)
    print("held      %d token(s)", held)
    print("capacity  %d token(s) for a new request now", capacity(snapshot))
    print("queued    %d ticket file(s)", queued(folder))
    print("disk      %.0f GB free on the checkout's volume (floor %d GB)", free_disk_gb(), DISK_FLOOR_GB)
end

local function test_suite()
    local count = 0
    local function check(name, got, want)
        count = count + 1
        assert(got == want, string.format("budget test %s: got %s, want %s", name, tostring(got), tostring(want)))
    end

    check("the cpu idle bounds a pool that memory allows", capacity({cores = 12, held = 0, idle = 6, free_mb = 20000, waited = false}), 6)
    check("memory bounds a pool the cpu allows", capacity({cores = 12, held = 0, idle = 11, free_mb = 9000, waited = false}), 4)
    check("held tokens count against memory and cpu", capacity({cores = 12, held = 3, idle = 2, free_mb = 3000, waited = false}), 3)
    check("the pool never takes the reserved cores", capacity({cores = 12, held = 0, idle = 12, free_mb = 99999, waited = false}), 10)
    check("an exhausted machine still grants one token when none is held", capacity({cores = 12, held = 0, idle = 0, free_mb = 0, waited = false}), 1)
    check("a patient request ignores a busy cpu", capacity({cores = 12, held = 0, idle = 0, free_mb = 9000, waited = true}), 4)

    check("a request gets what the room holds", grantable(6, 3, 5, 1, 6), 3)
    check("a request below its minimum gets nothing", grantable(6, 3, 5, 4, 6), 0)
    check("a grant stops at the free slots", grantable(10, 0, 2, 1, 6), 2)
    check("a grant stops at the maximum", grantable(10, 0, 9, 1, 6), 6)

    local minimum, maximum = tokens_wanted({mb = 2500, min = 1, jobs = 1}, 12)
    check("a 2.5 GB class takes two tokens", minimum .. "/" .. maximum, "2/2")
    minimum, maximum = tokens_wanted({min = 2, jobs = 6}, 12)
    check("a build asks for its jobs as the maximum", minimum .. "/" .. maximum, "2/6")
    minimum, maximum = tokens_wanted({mb = 2200, jobs = 4}, 12)
    check("a 2.2 GB class takes two tokens and at most its jobs", minimum .. "/" .. maximum, "2/4")
    minimum, maximum = tokens_wanted({jobs = 14}, 12)
    check("the request is clamped to the cores less the reserve", minimum .. "/" .. maximum, "1/10")

    check("a 60 GB floor refuses a 50 GB volume", disk_refused(50, 100), true)
    check("a volume at the floor is not refused", disk_refused(100, 100), false)

    local base = os.iorunv("mktemp", {"-d"}):trim()
    local pool = path.join(base, "pool")
    local queue = path.join(pool, "queue")
    os.mkdir(queue)
    local stale = path.join(queue, "1-0000000000001-00000001.ticket")
    io.writefile(stale, "")
    check("a ticket whose holder died does not block", ahead_of(pool, "2-0000000000002-00000002.ticket"), false)
    check("and is removed", os.isfile(stale), false)
    check("a ticket behind the request does not block", ahead_of(pool, "1-0000000000000-00000000.ticket"), false)

    local nested = os.iorunv("sh", {"-c", string.format("REVENANT_BUDGET_HELD=3 REVENANT_BUDGET_POOL=%s %s l -P %s %s run -- sh -c 'echo $XMAKE_MAX_JOBS'",
        pool, os.programfile(), path.directory(os.scriptdir()), path.join(os.scriptdir(), "budget.lua"))}):trim()
    check("a command under a budget takes its parent's tokens without a pool", nested, "3")
    check("and holds no slot of its own", held_slots(pool), 0)

    local started_anyway = true
    try { function ()
        os.iorunv("sh", {"-c", string.format("REVENANT_BUDGET_DISK_GB=100000000 REVENANT_BUDGET_POOL=%s %s l -P %s %s run -- true 2>&1",
            pool, os.programfile(), path.directory(os.scriptdir()), path.join(os.scriptdir(), "budget.lua"))})
    end, catch { function () started_anyway = false end } }
    check("a volume below the floor starts nothing", started_anyway, false)

    local marker = 600 + math.random(1, 99999)
    local launcher = string.format("REVENANT_BUDGET_POOL=%s REVENANT_BUDGET_PATIENCE=0 %s l -P %s %s run --class normal --jobs 2 --min 2 -- sleep %d >/dev/null 2>&1 & echo $!",
        pool, os.programfile(), path.directory(os.scriptdir()), path.join(os.scriptdir(), "budget.lua"), marker)
    local pid = os.iorunv("sh", {"-c", launcher}):trim()
    local deadline = os.mclock() + 90000
    while held_slots(pool) < 2 and os.mclock() < deadline do
        os.sleep(500)
    end
    check("a running command holds the tokens it was granted", held_slots(pool), 2)
    os.iorunv("kill", {"-9", pid})
    deadline = os.mclock() + 10000
    while held_slots(pool) > 0 and os.mclock() < deadline do
        os.sleep(200)
    end
    local released = held_slots(pool)
    try { function () os.iorunv("sh", {"-c", string.format("pkill -f 'sleep %d$' || true", marker)}) end }
    check("a holder killed with SIGKILL releases its tokens", released, 0)

    os.rm(base)
    print("budget: %d tests passed", count)
end

function main(command, ...)
    local args = {...}
    if command == "run" then
        local status = run(parse_run(args))
        if status ~= 0 then
            os.exit(status)
        end
    elseif command == "status" then
        status()
    elseif command == "test" then
        test_suite()
    else
        raise("usage: ./xmakew l -P . tools/budget.lua run [--class critical|normal|background] [--jobs N] [--min N] [--mb M] -- <command> [args...] | status | test")
    end
end
