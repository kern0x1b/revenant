import("core.base.jobserver")

local CALLER = {XMAKE_GLOBALDIR = false, XMAKE_ADDONS_SOURCEDIRS = ""}

local function number(name, default)
    return tonumber(os.getenv(name)) or default
end

local function settings()
    local dir = os.getenv("FLEET_HEAVY_DIR") or "/tmp/fleet-heavy"
    local cores = number("FLEET_HEAVY_CORES", os.cpuinfo().ncpu)
    return {
        dir = dir,
        pool = path.join(dir, "pool"),
        cores = cores,
        tokens = math.max(cores - number("FLEET_HEAVY_RESERVE", 2), 1),
        fast_slots = number("FLEET_HEAVY_FAST_SLOTS", 2),
        bulk_slots = number("FLEET_HEAVY_BULK_SLOTS", 3),
        min_free = number("FLEET_HEAVY_MIN_FREE", 20),
        excl_wait = number("FLEET_HEAVY_EXCL_WAIT", 1200),
        excl_backoff = number("FLEET_HEAVY_EXCL_BACKOFF", 600),
        poll = number("FLEET_HEAVY_POLL", 2),
        log = os.getenv("FLEET_HEAVY_LOG") or path.join(dir, "jobs.log"),
        basedir = os.getenv("FLEET_HEAVY_BASEDIR") or path.join(os.getenv("HOME"), "Git", "projects", "ios")
    }
end

local function alive(pid)
    pid = tonumber(pid)
    if not pid then
        return false
    end
    if pid == os.getpid() then
        return true
    end
    return os.execv("kill", {"-0", tostring(pid)}, {try = true, stdout = os.nuldev(), stderr = os.nuldev()}) == 0
end

local function memory_level()
    local level = try { function () return os.iorunv("sysctl", {"-n", "kern.memorystatus_level"}) end }
    return tonumber(level and level:trim()) or 100
end

local function lane_of(command)
    local named = os.getenv("FLEET_HEAVY_LANE")
    if named and named ~= "" then
        return named
    end
    if command:find("build-gate.lua", 1, true) or command:find("release-split.lua", 1, true) or command:find("run_light_tests.lua", 1, true) then
        return "fast"
    end
    if command:find("lift-remeasure", 1, true) or command:find("emulate", 1, true) or command:find("run-emu", 1, true) then
        return "bulk"
    end
    return "slow"
end

local function lift(command)
    return command:find("lift-remeasure", 1, true) or command:find("apple.lift", 1, true) or command:find("lift.lua", 1, true)
end

local Pool = {}

function Pool.new(config)
    os.mkdir(path.join(config.pool, "jobs"))
    os.mkdir(path.join(config.pool, "wait"))
    local self = {config = config}
    for name, method in pairs(Pool) do
        self[name] = method
    end
    self.lock = io.openlock(path.join(config.pool, "lock"))
    return self
end

function Pool:locked(func)
    self.lock:lock()
    return try {
        func,
        finally {
            function ()
                self.lock:unlock()
            end
        }
    }
end

function Pool:records()
    local records = {}
    for _, file in ipairs(os.files(path.join(self.config.pool, "jobs", "*"))) do
        local record = try { function () return io.load(file) end }
        if record then
            record.file = file
            table.insert(records, record)
        end
    end
    return records
end

function Pool:current()
    local file = path.join(self.config.pool, "current")
    return os.isfile(file) and io.readfile(file):trim() or nil
end

function Pool:connect()
    local fifo = self:current()
    if self.client and self.client.fifo == fifo then
        return self.client
    end
    if self.client then
        self.client:close()
        self.client = nil
    end
    if fifo and os.exists(fifo) then
        self.client = jobserver.open(fifo)
    end
    return self.client
end

function Pool:reap()
    local live = {}
    for _, record in ipairs(self:records()) do
        if alive(record.pid) then
            table.insert(live, record)
        else
            if record.token and record.fifo == self:current() and self:connect() then
                self.client:give(record.token)
            end
            os.tryrm(record.file)
        end
    end
    return live
end

function Pool:renew()
    for _, old in ipairs(os.files(path.join(self.config.pool, "fifo.*"))) do
        os.tryrm(old)
    end
    local fifo = path.join(self.config.pool, string.format("fifo.%d.%d", os.time(), os.getpid()))
    os.vrunv("mkfifo", {"-m", "600", fifo})
    io.writefile(path.join(self.config.pool, "current"), fifo .. "\n")
    local client = assert(self:connect(), "heavy: the jobserver FIFO " .. fifo .. " cannot be opened")
    for _ = 1, self.config.tokens do
        client:give("+")
    end
end

function Pool:exclusive_owner()
    local file = path.join(self.config.pool, "exclusive")
    if os.isfile(file) then
        local pid = tonumber(io.readfile(file):trim())
        if alive(pid) then
            return pid
        end
        os.tryrm(file)
    end
end

function Pool:ahead(ticket, lane)
    local fast = lane == "fast"
    for _, file in ipairs(os.files(path.join(self.config.pool, "wait", "*"))) do
        if file ~= ticket then
            local waiter = try { function () return io.load(file) end }
            if not waiter or not alive(waiter.pid) then
                os.tryrm(file)
            elseif (waiter.lane == "fast") == fast and path.filename(file) < path.filename(ticket) then
                return true
            end
        end
    end
    return false
end

function Pool:admit(job, opt)
    opt = opt or {}
    local ticket = path.join(self.config.pool, "wait", string.format("%012d-%d", os.time(), os.getpid()))
    io.save(ticket, {pid = os.getpid(), lane = job.lane, command = job.command})
    local said = {}
    local function say(key, message, ...)
        if not said[key] then
            said[key] = true
            io.stderr:write(string.format("heavy: " .. message .. "\n", ...))
        end
    end
    local admitted
    while not admitted do
        admitted = self:locked(function ()
            local live = self:reap()
            local owner = self:exclusive_owner()
            if owner and owner ~= os.getpid() then
                say("exclusive", "an exclusive job holds the machine, waiting")
                return
            end
            if opt.exclusive then
                if #live > 0 then
                    say("drain", "exclusive: no new job is admitted; waiting for the %d running ones (at most %ds)", #live, self.config.excl_wait)
                    return
                end
            elseif self:ahead(ticket, job.lane) then
                say("queue", "jobs that came earlier wait in the %s lane, waiting", job.lane)
                return
            end
            local level = memory_level()
            if level < self.config.min_free and #live > 0 then
                say("memory", "free memory %d%% is under %d%%, waiting for a running job to finish", level, self.config.min_free)
                return
            end
            if #live == 0 or not self:connect() then
                self:renew()
            end
            local client = assert(self:connect(), "heavy: no jobserver FIFO")
            local token
            if job.lane == "fast" then
                local running = 0
                for _, record in ipairs(live) do
                    if record.lane == "fast" then
                        running = running + 1
                    end
                end
                if running >= self.config.fast_slots then
                    say("fast", "all %d fast slots busy, waiting", self.config.fast_slots)
                    return
                end
            else
                if job.lane == "bulk" then
                    local running = 0
                    for _, record in ipairs(live) do
                        if record.lane == "bulk" then
                            running = running + 1
                        end
                    end
                    if running >= self.config.bulk_slots then
                        say("bulk", "all %d bulk slots busy, waiting", self.config.bulk_slots)
                        return
                    end
                end
                token = client:take()
                if not token then
                    say("tokens", "all %d tokens of the machine are taken, waiting", self.config.tokens)
                    return
                end
            end
            local record = {pid = os.getpid(), lane = job.lane, command = job.command, token = token, fifo = client.fifo,
                            started = os.time(), exclusive = opt.exclusive or nil}
            record.file = path.join(self.config.pool, "jobs", tostring(os.getpid()))
            io.save(record.file, {pid = record.pid, lane = record.lane, command = record.command, token = record.token,
                                  fifo = record.fifo, started = record.started, exclusive = record.exclusive})
            return record
        end)
        if not admitted then
            if opt.deadline and os.time() >= opt.deadline then
                break
            end
            os.sleep(self.config.poll * 1000)
        end
    end
    os.tryrm(ticket)
    return admitted
end

function Pool:release(record)
    self:locked(function ()
        if record.token and record.fifo == self:current() and self:connect() then
            self.client:give(record.token)
        end
        os.tryrm(record.file)
        if record.exclusive then
            os.tryrm(path.join(self.config.pool, "exclusive"))
        end
    end)
end

function Pool:log(line)
    self:locked(function ()
        local file = io.open(self.config.log, "a")
        if file then
            file:write(os.date("%Y-%m-%dT%H:%M:%S") .. "\t" .. line .. "\n")
            file:close()
        end
    end)
end

local function makeflags(fifo)
    local flags = os.getenv("MAKEFLAGS") or ""
    flags = flags:gsub("%s*%-%-jobserver%-auth=%S+", ""):gsub("%s*%-%-jobserver%-fds=%S+", "")
    return (flags .. " --jobserver-auth=fifo:" .. fifo):trim()
end

local function ccache(config)
    local cache = os.getenv("CCACHE_DIR") or path.join(os.getenv("HOME"), ".revenant", "cache", "ccache")
    os.mkdir(cache)
    io.writefile(path.join(cache, "ccache.conf"), string.format("base_dir = %s\nhash_dir = false\nmax_size = %s\n",
                                                               config.basedir, os.getenv("CCACHE_MAXSIZE") or "2G"))
    local envs = {CCACHE_DIR = cache, CCACHE_BASEDIR = config.basedir, CCACHE_NOHASHDIR = "1"}
    if not os.getenv("CCACHE") and not try { function () return os.iorunv("sh", {"-c", "command -v ccache"}) end } then
        for _, candidate in ipairs({"/opt/homebrew/bin/ccache", "/usr/local/bin/ccache"}) do
            if os.isexec(candidate) then
                envs.CCACHE = candidate
                break
            end
        end
    end
    return envs
end

local function command_line(arguments, envs, nice)
    local argv = {}
    for _, name in ipairs(table.orderkeys(CALLER)) do
        local given = os.getenv("HEAVY_CALLER_" .. name)
        if given == nil and CALLER[name] then
            given = CALLER[name]
        end
        if given ~= nil then
            if given == "" then
                table.join2(argv, {"-u", name})
            else
                envs[name] = given
            end
        end
    end
    for _, name in ipairs(table.orderkeys(envs)) do
        table.insert(argv, name .. "=" .. envs[name])
    end
    if nice and nice > 0 then
        table.join2(argv, {"nice", "-n", tostring(nice)})
    end
    return table.join(argv, arguments)
end

local function run(arguments, envs, nice)
    return os.execv("env", command_line(arguments, envs, nice), {try = true})
end

local function status(config)
    local pool = Pool.new(config)
    pool:locked(function ()
        local live = pool:reap()
        print("pool: %d tokens of %d cores, reserve %d; fifo %s", config.tokens, config.cores, config.cores - config.tokens, pool:current() or "none")
        local owner = pool:exclusive_owner()
        if owner then
            print("exclusive: pid %d", owner)
        end
        for _, record in ipairs(live) do
            print("running %s %ds pid %d: %s", record.lane, os.time() - record.started, record.pid, record.command)
        end
        for _, file in ipairs(os.files(path.join(config.pool, "wait", "*"))) do
            local waiter = try { function () return io.load(file) end }
            if waiter and alive(waiter.pid) then
                print("waiting %s pid %d: %s", waiter.lane, waiter.pid, waiter.command)
            end
        end
    end)
end

function main(...)
    local arguments = {...}
    local config = settings()
    if arguments[1] == "--status" then
        return status(config)
    end
    local exclusive = false
    if arguments[1] == "--exclusive" then
        exclusive = true
        table.remove(arguments, 1)
    end
    if #arguments == 0 then
        raise("usage: xmake l tools/heavy.lua [--exclusive] <command> [args...] | --status")
    end
    if os.getenv("FLEET_HEAVY_HELD") and os.getenv("FLEET_HEAVY_HELD") ~= "" then
        os.exit(run(arguments, {}, 0))
    end
    local command = table.concat(arguments, " ")
    if lift(command) and os.isfile(path.join(config.dir, "lifts-stopped")) and not os.getenv("FLEET_HEAVY_LIFT_FIX") then
        io.stderr:write("heavy: lifts are stopped by the owner until the lift is fast: " .. io.readfile(path.join(config.dir, "lifts-stopped")):trim() .. "\n")
        os.exit(75)
    end
    local job = {lane = lane_of(command), command = command}
    local pool = Pool.new(config)
    local queued = os.time()
    local record
    if exclusive then
        while not record do
            local claimed = pool:locked(function ()
                local owner = pool:exclusive_owner()
                if owner and owner ~= os.getpid() then
                    return false
                end
                io.writefile(path.join(config.pool, "exclusive"), tostring(os.getpid()) .. "\n")
                return true
            end)
            if claimed then
                record = pool:admit(job, {exclusive = true, deadline = os.time() + config.excl_wait})
                if not record then
                    pool:locked(function ()
                        os.tryrm(path.join(config.pool, "exclusive"))
                    end)
                    io.stderr:write(string.format("heavy: exclusive: the running jobs did not finish in %ds; the queue runs for %ds, then asking again\n",
                                                  config.excl_wait, config.excl_backoff))
                    os.sleep(config.excl_backoff * 1000)
                end
            else
                os.sleep(config.poll * 1000)
            end
        end
        io.stderr:write("heavy: running exclusive, the machine is this job's\n")
    else
        record = pool:admit(job)
        io.stderr:write(string.format("heavy: running in the %s lane\n", job.lane))
    end
    local started = os.time()
    local envs = ccache(config)
    envs.MAKEFLAGS = makeflags(record.fifo)
    envs.XMAKE_MAX_JOBS = os.getenv("XMAKE_MAX_JOBS") or tostring(config.tokens)
    envs.FLEET_HEAVY_CPUS = tostring(config.tokens)
    envs.FLEET_HEAVY_BASEDIR = config.basedir
    envs.FLEET_HEAVY_HELD = "1"
    local nice = ({fast = 0, bulk = 19})[job.lane] or 10
    local code = run(arguments, envs, nice)
    pool:release(record)
    pool:log(string.format("%s %ds waited %ds ran exit=%s %s", job.lane, started - queued, os.time() - started, tostring(code), command))
    os.exit(code)
end
