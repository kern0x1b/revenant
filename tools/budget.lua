local TOKEN_MB = 1536
local RESERVE_MB = 2048
local RESERVE_CORES = 2
local DISK_FLOOR_GB = 100
local POLL_MS = 1000
local NICE = "/usr/bin/nice"
local TASKPOLICY = "/usr/sbin/taskpolicy"
local CLOSE_INHERITED = 'i=3; while [ $i -lt 256 ]; do eval "exec $i>&-" 2>/dev/null; i=$((i+1)); done; exec "$@"'
local PRESSURE_WARN = 2
local PRESSURE_CRITICAL = 4
local COMPRESSOR_GROWTH = 1024
local MB = 1024 * 1024
local SYSCTL = "/usr/sbin/sysctl"
local VMSTAT = "/usr/bin/vm_stat"
local DF = "/bin/df"

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

local function parse_loadavg(text)
    return tonumber((text or ""):match("{%s*([%d%.]+)")) or 0
end

local function parse_pressure(text)
    return tonumber((text or ""):match("(%d+)")) or 1
end

local function parse_vmstat(text)
    local size = tonumber(text:match("page size of (%d+) bytes")) or 4096
    local function pages(label)
        return tonumber(text:match(label .. ":%s+(%d+)")) or 0
    end
    return {size = size, free = pages("Pages free"), speculative = pages("Pages speculative"),
            compressor = pages("Pages occupied by compressor"), pageouts = pages("Pageouts")}
end

local previous

local function sample()
    local loadavg = parse_loadavg(os.iorunv(SYSCTL, {"-n", "vm.loadavg"}))
    local pressure = parse_pressure(os.iorunv(SYSCTL, {"-n", "kern.memorystatus_vm_pressure_level"}))
    local vm = parse_vmstat(os.iorunv(VMSTAT, {}))
    local reading = {loadavg = loadavg, pressure = pressure, vm = vm, previous = previous}
    previous = vm
    return reading
end

local function memory_headroom(reading)
    local vm = reading.vm
    local available = math.floor(math.max(0, ((vm.free + vm.speculative) * vm.size / MB) - RESERVE_MB) / TOKEN_MB)
    if reading.pressure >= PRESSURE_CRITICAL then
        return 0
    end
    local prev = reading.previous
    local growing = prev ~= nil and (vm.compressor - prev.compressor) > COMPRESSOR_GROWTH
    local pageouts = prev ~= nil and (vm.pageouts - prev.pageouts) > 0
    if reading.pressure >= PRESSURE_WARN or growing or pageouts then
        return 1
    end
    return math.max(1, available)
end

local function capacity(reading, held)
    local limit = reading.cores - RESERVE_CORES
    local headroom = memory_headroom(reading)
    if headroom == 0 then
        return held
    end
    local outside = math.max(0, reading.loadavg - held)
    local cpu = math.max(0, limit - outside)
    local fresh = math.min(headroom, limit - held)
    if cpu < fresh then
        fresh = math.max(1, cpu)
    end
    return held + fresh
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

local function free_disk_gb()
    local out = os.iorunv(DF, {"-Pk", cache().checkout()})
    local fields = {}
    for field in out:match("[^\n]*\n([^\n]+)"):gmatch("%S+") do
        table.insert(fields, field)
    end
    return tonumber(fields[4]) / (1024 * 1024)
end

local function disk_refused(free_gb, floor)
    return free_gb < floor
end

local function enqueue(folder, rank, minimum)
    local dir = path.join(folder, "queue")
    os.mkdir(dir)
    local name = string.format("%d-%013d-%08d.ticket", rank, os.time() * 1000 + math.random(0, 999), math.random(0, 99999999))
    local file = path.join(dir, name)
    local lock = io.openlock(file)
    lock:trylock()
    io.writefile(file, tostring(minimum))
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

local function ahead_of(folder, name, available)
    for _, file in ipairs(os.files(path.join(folder, "queue", "*.ticket"))) do
        if path.filename(file) < name and holder_alive(file) then
            local need = tonumber(io.readfile(file)) or 1
            if need <= available then
                return true
            end
        end
    end
    return false
end

local function snapshot_slots(folder, cores)
    local free_locks, held = {}, 0
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
    return free_locks, held
end

local function release_locks(locks)
    for _, lock in ipairs(locks) do
        lock:unlock()
        lock:close()
    end
end

local function acquire(folder, class, minimum, maximum, reading_fn, poll_ms)
    reading_fn = reading_fn or sample
    poll_ms = poll_ms or POLL_MS
    local ticket = enqueue(folder, CLASSES[class].rank, minimum)
    local announced
    while true do
        local cores = os.cpuinfo("ncpu")
        local reading = reading_fn()
        reading.cores = cores
        local free_locks, held = snapshot_slots(folder, cores)
        local cap = capacity(reading, held)
        local available = math.min(math.max(cap - held, 0), #free_locks)
        local count = grantable(cap, held, #free_locks, minimum, maximum)
        if count == 0 and cap > held then
            count = math.min(cap - held, #free_locks)
        end
        if count > 0 and not ahead_of(folder, ticket.name, available) then
            local grant = table.slice(free_locks, 1, count)
            release_locks(table.slice(free_locks, count + 1))
            leave(ticket)
            return grant
        end
        release_locks(free_locks)
        if not announced then
            print("budget: waiting for %d token(s), %s class", minimum, class)
            announced = true
        end
        os.sleep(poll_ms)
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
    release_locks(locks)
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
    local reading = sample()
    reading.cores = cores
    local outside = math.max(0, reading.loadavg - held)
    print("pool      %s", folder)
    print("cores     %d (reserve %d)", cores, RESERVE_CORES)
    print("cpu       %.2f loadavg, %.2f runnable outside the pool, %d token(s) of headroom", reading.loadavg, outside, math.max(0, cores - RESERVE_CORES - outside))
    print("memory    pressure %d, %d MB free (inactive pages not counted), %d token(s) of headroom", reading.pressure,
          math.floor((reading.vm.free + reading.vm.speculative) * reading.vm.size / MB), memory_headroom(reading))
    print("held      %d token(s)", held)
    print("capacity  %d token(s) for a new request now", capacity(reading, held))
    print("queued    %d ticket file(s)", queued(folder))
    print("disk      %.0f GB free on the checkout's volume (floor %d GB)", free_disk_gb(), DISK_FLOOR_GB)
end

local function test_reading(loadavg, pressure, free_mb, opt)
    opt = opt or {}
    local size = 16384
    local function pages(mb)
        return math.floor(mb * MB / size)
    end
    return {loadavg = loadavg, pressure = pressure,
            vm = {size = size, free = pages(free_mb), speculative = pages(opt.speculative or 0),
                  compressor = opt.compressor or 0, pageouts = opt.pageouts or 0},
            previous = opt.previous, cores = opt.cores or 12}
end

local function test_suite()
    local process = import("core.base.process")
    local count = 0
    local function check(name, got, want)
        count = count + 1
        assert(got == want, string.format("budget test %s: got %s, want %s", name, tostring(got), tostring(want)))
    end

    check("the one-minute window is the cpu reading", parse_loadavg("{ 8.50 2.10 1.00 }\n"), 8.5)
    check("a missing load average is zero", parse_loadavg(""), 0)
    check("pressure is read from the sysctl", parse_pressure("2\n"), 2)

    local vmtext = "Mach Virtual Memory Statistics: (page size of 16384 bytes)\n" ..
                   "Pages free:                  65536.\n" ..
                   "Pages inactive:            9999999.\n" ..
                   "Pages speculative:          16384.\n" ..
                   "Pages occupied by compressor: 1024.\n" ..
                   "Pageouts:                       7.\n"
    local vm = parse_vmstat(vmtext)
    check("the page size is read", vm.size, 16384)
    check("inactive pages are not part of the reading", vm.free, 65536)
    check("speculative pages are part of the reading", vm.speculative, 16384)
    check("compressor pages are read", vm.compressor, 1024)
    check("pageouts are read", vm.pageouts, 7)

    check("a normal machine counts free memory", memory_headroom(test_reading(0, 1, 11000)), 5)
    check("warning pressure grants only one token", memory_headroom(test_reading(0, 2, 11000)), 1)
    check("critical pressure grants none", memory_headroom(test_reading(0, 4, 11000)), 0)
    local prev = test_reading(0, 1, 11000).vm
    check("compressor growth grants only one token", memory_headroom(test_reading(0, 1, 11000, {previous = prev, compressor = prev.compressor + 2048})), 1)
    check("pageouts grant only one token", memory_headroom(test_reading(0, 1, 11000, {previous = prev, pageouts = prev.pageouts + 3})), 1)
    check("a stable compressor at normal pressure is not a limit", memory_headroom(test_reading(0, 1, 11000, {previous = prev, compressor = prev.compressor + 1})), 5)
    check("a machine below the reserve still starts one token", memory_headroom(test_reading(0, 1, 100, {speculative = 100})), 1)

    check("runnable load outside the pool bounds the jobs", capacity(test_reading(8, 1, 11000), 3), 8)
    check("held tokens are not load from outside", capacity(test_reading(8, 1, 11000), 0), 2)
    check("warning pressure with no free memory still starts one token", capacity(test_reading(40, 2, 100), 0), 1)
    check("a memory-fitting request starts with fewer jobs on a busy cpu", capacity(test_reading(20, 1, 11000), 0), 1)
    check("critical pressure makes a request wait", capacity(test_reading(0, 4, 11000), 0), 0)
    check("critical pressure leaves no headroom for holders", capacity(test_reading(0, 4, 11000), 2) - 2, 0)
    check("the pool still takes no reserved cores", capacity(test_reading(0, 1, 99999, {cores = 12}), 0), 10)

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
    io.writefile(stale, "1")
    check("a ticket whose holder died does not block", ahead_of(pool, "2-0000000000002-00000002.ticket", 1), false)
    check("and is removed", os.isfile(stale), false)

    local function ticket_at(name, need)
        local file = path.join(queue, name)
        local lock = io.openlock(file)
        lock:trylock()
        io.writefile(file, tostring(need))
        return {name = name, file = file, lock = lock}
    end
    local large = ticket_at("2-0000000000001-00000001.ticket", 6)
    check("a large ticket ahead does not block a small request that fits", ahead_of(pool, "2-0000000000002-00000002.ticket", 1), false)
    check("and does block one when there is room for it", ahead_of(pool, "2-0000000000002-00000002.ticket", 6), true)
    leave(large)
    check("a ticket behind the request does not block", ahead_of(pool, "1-0000000000000-00000000.ticket", 1), false)

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

    local fresh = path.join(base, "fresh")
    local readings = {test_reading(0, 4, 11000), test_reading(0, 4, 11000), test_reading(0, 1, 11000)}
    local calls = 0
    local function changing()
        calls = calls + 1
        return readings[math.min(calls, #readings)]
    end
    local began = os.mclock()
    local granted = acquire(fresh, "normal", 1, 1, changing, 1)
    local elapsed = os.mclock() - began
    check("a request that does not fit waits and is granted when it does", #granted, 1)
    check("and the re-check happens without a fixed patience wait", calls >= 3 and elapsed < 10000, true)
    release_locks(granted)

    local tight = acquire(path.join(base, "tight"), "normal", 2, 4, function () return test_reading(0, 1, 100) end, 1)
    check("a request that fits by one token starts with fewer jobs than its minimum", #tight, 1)
    release_locks(tight)

    local pidfile = path.join(base, "holder.pid")
    local log = path.join(base, "holder.log")
    local child = string.format("echo $$ > %q; exec sleep 600", pidfile)
    local holder = process.openv(os.programfile(), {"l", "-P", path.directory(os.scriptdir()),
        path.join(os.scriptdir(), "budget.lua"), "run", "--class", "normal", "--jobs", "1", "--min", "1", "--", "sh", "-c", child},
        {outpath = log, errpath = log, envs = {"REVENANT_BUDGET_POOL=" .. pool}})
    local deadline = os.mclock() + 90000
    while held_slots(pool) < 1 and os.mclock() < deadline do
        os.sleep(500)
    end
    check("a running command holds the tokens it was granted", held_slots(pool), 1)
    holder:kill()
    local child_pid = tonumber((io.readfile(pidfile) or ""):match("%d+"))
    if child_pid then
        os.iorunv("kill", {"-9", tostring(child_pid)})
    end
    deadline = os.mclock() + 10000
    while held_slots(pool) > 0 and os.mclock() < deadline do
        os.sleep(200)
    end
    check("a holder killed with SIGKILL releases its tokens", held_slots(pool), 0)

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
