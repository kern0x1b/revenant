local process = import("core.base.process")
local exclusive = import("@addon.revenant.exclusive", {anonymous = true})

local TOKEN_MB = 1536
local RESERVE_MB = 2048
local RESERVE_CORES = 2
local DISK_FLOOR_GB = 100
local POLL_MS = 1000
local NICE = "/usr/bin/nice"
local TASKPOLICY = "/usr/sbin/taskpolicy"
local CLOSE_INHERITED = 'i=3; while [ $i -lt 256 ]; do eval "exec $i>&-" 2>/dev/null; i=$((i+1)); done; exec "$@"'
local MB = 1024 * 1024
local PRESSURE_WARN = 2
local PRESSURE_CRITICAL = 4
local PAGEOUT_BYTES = 1 * MB
local COMPRESSOR_BYTES = 512 * MB
local SYSCTL = "/usr/sbin/sysctl"
local VMSTAT = "/usr/bin/vm_stat"
local DF = "/bin/df"
local PS = "/bin/ps"
local LOAD_WINDOW_MS = 60000
local ANNOUNCE_S = 300
local AGING_S = 300
local WAIT_JOURNAL = "wait-journal"
local WAIT_DAY_S = 86400

local function say(format, ...)
    print(format, ...)
    io.flush()
end

local function duration(seconds)
    seconds = math.max(0, seconds)
    if seconds < 90 then
        return string.format("%d s", seconds)
    elseif seconds < 5400 then
        return string.format("%d min", seconds // 60)
    end
    return string.format("%.1f h", seconds / 3600)
end

local CLASSES = {
    critical = {rank = 1, nice = 0},
    normal = {rank = 2, nice = 5},
    background = {rank = 3, nice = 15, background = true},
}

local function cache()
    return import("@addon.revenant.cache", {anonymous = true})
end

local function checkout_dir()
    return try { function () return cache().checkout() end } or os.projectdir()
end

local function pool_folder()
    return os.getenv("REVENANT_BUDGET_POOL") or path.join(checkout_dir(), ".cache", "budget")
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

local function parse_sysctl_number(key, out)
    local value = tonumber((out:match("^%s*(%d+)%s*$")))
    if not value then
        raise("budget: cannot read %s: got %q", key, out:gsub("%s+$", ""))
    end
    return value
end

local function numeric_sysctl(key)
    return parse_sysctl_number(key, os.iorunv(SYSCTL, {"-n", key}))
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

local function read_grants(folder)
    local now, window = os.time(), LOAD_WINDOW_MS / 1000
    local total = 0
    for _, file in ipairs(os.files(path.join(folder, "slot-*.lock"))) do
        for at, count in (io.readfile(file) or ""):gmatch("g (%d+) (%d+)") do
            local age = now - tonumber(at)
            if age >= 0 and age < window then
                total = total + tonumber(count) * math.max(0, 1 - age / window)
            end
        end
    end
    return total
end

local function sample()
    local loadavg = parse_loadavg(os.iorunv(SYSCTL, {"-n", "vm.loadavg"}))
    local pressure = parse_pressure(os.iorunv(SYSCTL, {"-n", "kern.memorystatus_vm_pressure_level"}))
    local level = numeric_sysctl("kern.memorystatus_level")
    local memsize = numeric_sysctl("hw.memsize")
    local vm = parse_vmstat(os.iorunv(VMSTAT, {}))
    vm.at = os.mclock()
    local available = level * memsize / (100 * MB)
    local reading = {loadavg = loadavg, load = math.max(loadavg, read_grants(pool_folder())),
                     pressure = pressure, available = available, level = level, memsize = memsize,
                     vm = vm, previous = previous}
    previous = vm
    return reading
end

local function own_runnable(pids)
    if #pids == 0 then
        return 0
    end
    local out = try { function () return os.iorunv(PS, {"-ax", "-o", "pid=,ppid=,state="}) end } or ""
    local kids, states = {}, {}
    for line in out:gmatch("[^\n]+") do
        local pid, ppid, state = line:match("(%d+)%s+(%d+)%s+(%a)")
        if pid then
            pid, ppid = tonumber(pid), tonumber(ppid)
            states[pid] = state
            kids[ppid] = kids[ppid] or {}
            table.insert(kids[ppid], pid)
        end
    end
    local seen, total = {}, 0
    local function walk(pid)
        if not seen[pid] then
            seen[pid] = true
            if states[pid] == "R" then
                total = total + 1
            end
            for _, child in ipairs(kids[pid] or {}) do
                walk(child)
            end
        end
    end
    for _, pid in ipairs(pids) do
        walk(pid)
    end
    return total
end

local function memory_headroom(reading)
    if reading.pressure >= PRESSURE_CRITICAL then
        return 0
    end
    local vm = reading.vm
    local prev = reading.previous
    if prev then
        local elapsed = (vm.at or 0) - (prev.at or 0)
        elapsed = elapsed > 0 and elapsed / 1000 or 1
        local pageouts = (vm.pageouts - prev.pageouts) * vm.size / elapsed
        local compressor = (vm.compressor - prev.compressor) * vm.size / elapsed
        if pageouts > PAGEOUT_BYTES or compressor > COMPRESSOR_BYTES then
            return 1
        end
    end
    if reading.pressure >= PRESSURE_WARN then
        return 1
    end
    local available = math.floor(math.max(0, (reading.available or 0) - RESERVE_MB) / TOKEN_MB)
    if available < 1 then
        return 1
    end
    return available, true
end

local function capacity(reading, held, own)
    local limit = reading.cores - RESERVE_CORES
    local headroom = memory_headroom(reading)
    if headroom == 0 then
        return held
    end
    local load = math.max(reading.load or reading.loadavg, own or 0)
    local cpu = math.max(0, limit - load)
    local fresh = math.min(headroom, limit - held)
    if cpu < fresh then
        fresh = math.max(1, cpu)
    end
    return held + fresh
end

local function progress_capacity(reading, held, minimum)
    if memory_headroom(reading) < minimum then
        return held
    end
    return held + minimum
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
    local out = os.iorunv(DF, {"-Pk", checkout_dir()})
    local fields = {}
    for field in out:match("[^\n]*\n([^\n]+)"):gmatch("%S+") do
        table.insert(fields, field)
    end
    return tonumber(fields[4]) / (1024 * 1024)
end

local function disk_refused(free_gb, floor)
    return free_gb < floor
end

local REFUSAL_EXIT = 3

local function budget_floor()
    return tonumber(os.getenv("REVENANT_BUDGET_DISK_GB")) or DISK_FLOOR_GB
end

local function refusal_text(free, floor)
    return string.format("budget: %.0f GB free on the checkout's volume, below the %d GB floor, so no heavy command starts", free, floor)
end

local function who_line(who)
    local command = (who.command or ""):gsub("%s+", " ")
    if #command > 160 then
        command = command:sub(1, 157) .. "..."
    end
    return string.format("h %d\t%s\t%s", who.at or os.time(), ((who.worktree or ""):gsub("[\t\n]", " ")), command)
end

local function who_of(text)
    local at, worktree, command = (text or ""):match("\nh (%d+)\t([^\t\n]*)\t([^\n]*)")
    return {at = tonumber(at), worktree = worktree or "", command = command or ""}
end

local function journal_path(folder)
    return path.join(folder, WAIT_JOURNAL)
end

local function append_journal(folder, at, entry)
    exclusive.run(journal_path(folder) .. ".lock", "the budget wait journal", function ()
        local lines = {}
        local previous = os.isfile(journal_path(folder)) and io.readfile(journal_path(folder)) or ""
        for line in previous:gmatch("[^\n]+") do
            local stamped = tonumber(line:match("^at (%d+)"))
            if stamped and stamped >= at - WAIT_DAY_S then
                table.insert(lines, line)
            end
        end
        table.insert(lines, entry)
        io.writefile(journal_path(folder), table.concat(lines, "\n") .. "\n")
    end)
end

local function record_wait(folder, class, tokens, seconds, who)
    local at = os.time()
    local failure
    try {
        function ()
            append_journal(folder, at, string.format("at %d\tclass %s\ttokens %d\twait %d\tpid %d\t%s", at, class, tokens, seconds, who.pid or 0, who_line(who)))
        end,
        catch {
            function (errors)
                failure = tostring(errors):gsub("%s+", " ")
            end
        }
    }
    if failure then
        local note = string.format("at %d granted %d token(s) to pid %d: the journal write failed: %s", at, tokens, who.pid or 0, failure)
        io.stderr:write("budget: " .. note .. "\n")
        try { function () local file = io.open(journal_path(folder) .. ".errors", "a"); file:write(note .. "\n"); file:close() end }
    end
end

local function record_stops(folder, kind, parent, run, listing)
    local at = os.time()
    for line in listing:gmatch("[^\n]+") do
        local pid, command = line:match("^%s*(%d+)%s+(.-)%s*$")
        if pid then
            append_journal(folder, at, string.format("at %d\tstopped %s\tpid %s\tparent %s\trun %s\t%s", at, kind, pid, parent, run, command))
        end
    end
end

local function wait_summary(folder)
    if not os.isfile(journal_path(folder)) then
        return 0, 0, {}
    end
    local cutoff = os.time() - WAIT_DAY_S
    local groups, order, total, count = {}, {}, 0, 0
    for line in (io.readfile(journal_path(folder)) or ""):gmatch("[^\n]+") do
        local at, class, tokens, seconds, pid, worktree, command = line:match("^at (%d+)\tclass (%a+)\ttokens (%d+)\twait (%d+)\tpid (%d+)\th %d+\t([^\t]*)\t([^\n]*)$")
        if at and tonumber(at) >= cutoff then
            local key = pid .. "\t" .. worktree .. "\t" .. command
            if not groups[key] then
                groups[key] = {pid = pid, worktree = worktree, command = command, seconds = 0, waits = 0, tokens = 0, classes = {}}
                table.insert(order, key)
            end
            local group = groups[key]
            group.seconds = group.seconds + tonumber(seconds)
            group.waits = group.waits + 1
            group.tokens = group.tokens + tonumber(tokens)
            group.classes[class] = true
            total = total + tonumber(seconds)
            count = count + 1
        end
    end
    local lines = {}
    for _, key in ipairs(order) do
        local group = groups[key]
        local classes = table.keys(group.classes)
        table.sort(classes)
        table.insert(lines, string.format("pid %s in %s: %s — %d s in %d wait(s), %d token(s) in %s class(es)",
            group.pid, group.worktree ~= "" and group.worktree or "an unknown worktree", group.command,
            group.seconds, group.waits, group.tokens, table.concat(classes, ", ")))
    end
    return total, count, lines
end

local function stop_summary(folder)
    local cutoff = os.time() - WAIT_DAY_S
    local processes, count, newest = {}, 0, nil
    for line in (io.readfile(journal_path(folder)) or ""):gmatch("[^\n]+") do
        local at, what, pid, run, command = line:match("^at (%d+)\tstopped (%a+)\tpid (%d+)\tparent %d+\trun (%d+)\t(.*)$")
        if at and tonumber(at) >= cutoff then
            if not processes[pid .. "\t" .. run] then
                processes[pid .. "\t" .. run] = true
                count = count + 1
            end
            newest = os.date("%Y-%m-%d %H:%M:%S", tonumber(at)) .. " " .. pid .. " " .. what .. " " .. command
        end
    end
    return count, newest
end

local function ticket_need(file)
    return tonumber((io.readfile(file) or ""):match("^%d+")) or 1
end

local function aged_path(folder, name)
    return path.join(folder, "queue", "aged-" .. name)
end

local function enqueue(folder, rank, minimum, who)
    local dir = path.join(folder, "queue")
    os.mkdir(dir)
    local named = who or {pid = os.getpid(), worktree = checkout_dir(), command = "", at = os.time()}
    if not named.pid then
        named = table.clone(named)
        named.pid = os.getpid()
    end
    local name = string.format("%d-%013d-%08d.ticket", rank, os.time() * 1000 + math.random(0, 999), math.random(0, 99999999))
    local file = path.join(dir, name)
    local lock = io.openlock(file)
    lock:trylock()
    io.writefile(file, tostring(minimum) .. string.format("\np %d\n%s\n", named.pid, who_line(named)))
    return {name = name, file = file, lock = lock}
end

local function leave(ticket)
    os.tryrm(ticket.file)
    os.tryrm(path.join(path.directory(ticket.file), "aged-" .. ticket.name))
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
        os.tryrm(path.join(path.directory(file), "aged-" .. path.filename(file)))
    end
    return not free
end

local function write_pid(file, pid)
    local lines = {}
    for line in (io.readfile(file) or ""):gmatch("[^\n]+") do
        if not line:match("^%d+$") then
            table.insert(lines, line)
        end
    end
    table.insert(lines, 1, tostring(pid))
    io.writefile(file, table.concat(lines, "\n") .. "\n")
end

local function ahead_of(folder, name, reach)
    local own_aged = os.isfile(aged_path(folder, name))
    for _, file in ipairs(os.files(path.join(folder, "queue", "*.ticket"))) do
        local other = path.filename(file)
        if not other:find("^aged%-") then
            local other_aged = os.isfile(aged_path(folder, other))
            local first = other < name
            if other_aged ~= own_aged then
                first = other_aged
            end
            if first and holder_alive(file) and ticket_need(file) <= reach then
                return true
            end
        end
    end
    return false
end

local function snapshot_slots(folder, cores)
    local free, held, pids = {}, 0, {}
    for index = 1, cores - RESERVE_CORES do
        local file = slot_path(folder, index)
        local lock = io.openlock(file)
        if lock and lock:trylock() then
            write_pid(file, os.getpid())
            table.insert(free, {lock = lock, file = file})
        else
            held = held + 1
            table.insert(pids, tonumber((io.readfile(file) or ""):match("%d+")) or -1)
            if lock then
                lock:close()
            end
        end
    end
    return free, held, pids
end

local function release_locks(entries)
    for _, entry in ipairs(entries) do
        entry.lock:unlock()
        entry.lock:close()
    end
end

local function publish_slot(entry, count, who)
    local lines = {}
    for line in (io.readfile(entry.file) or ""):gmatch("[^\n]+") do
        if not line:match("^g ") and not line:match("^h ") then
            table.insert(lines, line)
        end
    end
    if who then
        table.insert(lines, who_line(who))
    end
    table.insert(lines, string.format("g %d %d", os.time(), count))
    io.writefile(entry.file, table.concat(lines, "\n") .. "\n")
end

local function process_command(pid)
    return try { function () return os.iorunv(PS, {"-o", "command=", "-p", tostring(pid)}):trim() end } or ""
end

local function holders(folder)
    local found = {}
    for index = 1, os.cpuinfo("ncpu") - RESERVE_CORES do
        local file = slot_path(folder, index)
        local lock = io.openlock(file)
        if lock then
            if lock:trylock() then
                lock:unlock()
            else
                local text = io.readfile(file) or ""
                local held = who_of(text)
                held.slot = index
                held.pid = tonumber(text:match("^%d+"))
                if held.command == "" and held.pid then
                    held.command = process_command(held.pid)
                    held.worktree = held.command:match("%-P (%S+)") or ""
                end
                table.insert(found, held)
            end
            lock:close()
        end
    end
    return found
end

local function waiters(folder)
    local names = {}
    for _, file in ipairs(os.files(path.join(folder, "queue", "*.ticket"))) do
        if not path.filename(file):find("^aged%-") then
            table.insert(names, file)
        end
    end
    table.sort(names)
    local found = {}
    for _, file in ipairs(names) do
        if holder_alive(file) then
            local text = io.readfile(file) or ""
            local waiting = who_of(text)
            waiting.name = path.filename(file)
            waiting.need = ticket_need(file)
            waiting.pid = tonumber(text:match("\np (%d+)"))
            local rank = tonumber(waiting.name:match("^(%d+)%-"))
            for name, class in pairs(CLASSES) do
                if class.rank == rank then
                    waiting.class = name
                end
            end
            table.insert(found, waiting)
        end
    end
    return found
end

local function holder_lines(folder, indent)
    local groups, order = {}, {}
    for _, held in ipairs(holders(folder)) do
        local key = tostring(held.pid)
        if not groups[key] then
            groups[key] = {holder = held, count = 0}
            table.insert(order, key)
        end
        groups[key].count = groups[key].count + 1
    end
    local lines = {}
    for _, key in ipairs(order) do
        local held = groups[key].holder
        table.insert(lines, string.format("%spid %s holds %d token(s)%s in %s: %s", indent, key, groups[key].count,
                                          held.at and " for " .. duration(os.time() - held.at) or "",
                                          held.worktree ~= "" and held.worktree or "an unknown worktree",
                                          held.command ~= "" and held.command or "an unknown command"))
    end
    return lines
end

local function waiter_lines(folder, indent)
    local lines = {}
    for _, waiting in ipairs(waiters(folder)) do
        table.insert(lines, string.format("%spid %s waits%s for %d token(s), %s class, in %s: %s", indent, tostring(waiting.pid),
                                          waiting.at and " " .. duration(os.time() - waiting.at) or "", waiting.need, waiting.class or "unknown",
                                          waiting.worktree ~= "" and waiting.worktree or "an unknown worktree",
                                          waiting.command ~= "" and waiting.command or "an unknown command"))
    end
    return lines
end

local function waiting_text(folder, minimum, class, again)
    local lines = holder_lines(folder, "  ")
    local head = string.format("budget: %s for %d token(s), %s class", again and "still waiting" or "waiting", minimum, class)
    if #lines == 0 then
        return head .. "; no process holds a token, so the machine's own load or memory is the limit"
    end
    return head .. "; held by:\n" .. table.concat(lines, "\n")
end

local function acquire(folder, class, minimum, maximum, reading_fn, poll_ms, who)
    reading_fn = reading_fn or sample
    poll_ms = poll_ms or POLL_MS
    local ticket = enqueue(folder, CLASSES[class].rank, minimum, who)
    local started = os.mclock()
    local announce = (tonumber(os.getenv("REVENANT_BUDGET_ANNOUNCE_S")) or ANNOUNCE_S) * 1000
    local aging = (tonumber(os.getenv("REVENANT_BUDGET_AGING_S")) or AGING_S) * 1000
    local announced, marked
    while true do
        local cores = os.cpuinfo("ncpu")
        local reading = reading_fn()
        reading.cores = cores
        local free, held, pids = snapshot_slots(folder, cores)
        local cap = capacity(reading, held, own_runnable(pids))
        local headroom, measured = memory_headroom(reading)
        local progress = held == 0 and progress_capacity(reading, held, minimum) or held
        local guarantee = progress > held
        if guarantee then
            cap = math.max(cap, progress)
        end
        local count = grantable(cap, held, #free, minimum, maximum)
        local reach = math.min(measured and headroom + held or headroom, cores - RESERVE_CORES)
        if count > 0 and not ahead_of(folder, ticket.name, reach) then
            local grant = table.slice(free, 1, count)
            release_locks(table.slice(free, count + 1))
            for _, entry in ipairs(grant) do
                publish_slot(entry, 1, who)
            end
            record_wait(folder, class, count, math.max(0, (os.mclock() - started) // 1000), who or {pid = os.getpid(), worktree = checkout_dir(), command = "", at = os.time()})
            leave(ticket)
            return grant
        end
        release_locks(free)
        if not marked and os.mclock() - started > aging then
            io.writefile(aged_path(folder, ticket.name), tostring(minimum))
            marked = true
        end
        if not announced or os.mclock() - announced > announce then
            say("%s", waiting_text(folder, minimum, class, announced ~= nil))
            announced = os.mclock()
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

local WATCHER = [[parent=$1; target=$2; program=$3; project=$4; script=$5; errors=$6; me=$
tree() { for child in $(pgrep -P "$1"); do tree "$child"; done; echo "$1"; }
journal() {
    out=$("$program" l -P "$project" "$script" stopped "$1" "$parent" "$target" "$2" 2>&1) || echo "at $(date +%s) stopped $1 parent $parent run $target: the journal write failed: $(echo $out | tr '\n' ' ')" >> "$errors"
}
listing() { ps -o pid=,command= -p "$(echo $1 | tr ' ' ',')" 2>/dev/null; }
while [ "$(ps -o ppid= -p "$target" 2>/dev/null | tr -d ' ')" = "$parent" ]; do sleep 1; done
kill -0 "$target" 2>/dev/null || exit 0
pids=$(tree "$target" | grep -v "^$me\$")
seen=$(listing "$pids")
journal TERM "$seen"
kill -TERM $pids 2>/dev/null
sleep 2
alive=""
for pid in $pids; do kill -0 "$pid" 2>/dev/null && alive="$alive $pid"; done
if [ -n "$alive" ]; then
    seen=$(listing "$alive")
    journal KILL "$seen"
    kill -KILL $alive 2>/dev/null
fi
exit 0]]

local function parent_of(pid)
    return tonumber(try { function () return os.iorunv(PS, {"-o", "ppid=", "-p", tostring(pid)}):trim() end })
end

local function watch_parent()
    local parent = parent_of(os.getpid())
    if not parent or parent <= 1 then
        return nil
    end
    return process.openv("/bin/sh", {"-c", CLOSE_INHERITED, "budget", "/bin/sh", "-c", WATCHER, "watcher", tostring(parent), tostring(os.getpid()), os.programfile(), os.projectdir(), path.join(os.scriptdir(), "budget.lua"), journal_path(pool_folder()) .. ".errors"},
                         {outpath = "/dev/null", errpath = "/dev/null"})
end

local function run(opt)
    local class = CLASSES[opt.class]
    local inherited = tonumber(os.getenv("REVENANT_BUDGET_HELD"))
    local watcher = watch_parent()
    local locks = {}
    local count = inherited
    if not inherited then
        local free = free_disk_gb()
        local floor = budget_floor()
        if disk_refused(free, floor) then
            say("%s", refusal_text(free, floor))
            os.exit(REFUSAL_EXIT)
        end
        local minimum, maximum = tokens_wanted(opt, os.cpuinfo("ncpu"))
        locks = acquire(pool_folder(), opt.class, minimum, maximum, nil, nil,
                        {pid = os.getpid(), worktree = os.projectdir(), command = table.concat(opt.command, " "), at = os.time()})
        count = #locks
    end
    local program, args = launch(class, opt.command)
    local status = os.execv(program, args, {envs = {XMAKE_MAX_JOBS = tostring(count), REVENANT_BUDGET_HELD = tostring(count)}, try = true})
    if watcher then
        watcher:kill()
        watcher:close()
    end
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

local function status()
    local folder = pool_folder()
    local cores = os.cpuinfo("ncpu")
    local free, held, pids = snapshot_slots(folder, cores)
    release_locks(free)
    local own = own_runnable(pids)
    local reading = sample()
    reading.cores = cores
    local load = math.max(reading.load, own)
    say("pool      %s", folder)
    say("cores     %d (reserve %d)", cores, RESERVE_CORES)
    say("cpu       %.2f loadavg, %.2f effective load, %d runnable of holders, %d token(s) of headroom",
        reading.loadavg, load, own, math.max(0, cores - RESERVE_CORES - load))
    say("memory    pressure %d, %d MB available (memorystatus %d%%), %d token(s) of headroom", reading.pressure,
        math.floor(reading.available), reading.level or 0, (memory_headroom(reading)))
    say("held      %d token(s)", held)
    for _, line in ipairs(holder_lines(folder, "          ")) do
        say("%s", line)
    end
    say("capacity  %d token(s) for a new request now", capacity(reading, held, own))
    local waiting = waiter_lines(folder, "          ")
    say("queued    %d ticket(s) with a live holder", #waiting)
    for _, line in ipairs(waiting) do
        say("%s", line)
    end
    local seconds, entries, waits = wait_summary(folder)
    say("waited    %d s in %d grant(s) over the last 24 h", seconds, entries)
    for _, line in ipairs(waits) do
        say("waited    %s", line)
    end
    local stopped, newest = stop_summary(folder)
    say("stopped   %d process(es) by the watcher over the last 24 h%s", stopped, newest and ("; newest: " .. newest) or "")
    local failed = os.isfile(journal_path(folder) .. ".errors") and io.readfile(journal_path(folder) .. ".errors") or ""
    local failures = 0
    for _ in failed:gmatch("[^\n]+") do
        failures = failures + 1
    end
    if failures > 0 then
        say("stopped   %d journal write(s) failed (watcher stops or grants), see %s", failures, journal_path(folder) .. ".errors")
    end
    say("disk      %.0f GB free on the checkout's volume (floor %d GB)", free_disk_gb(), DISK_FLOOR_GB)
end

local function test_reading(loadavg, pressure, available_mb, opt)
    opt = opt or {}
    local size = opt.size or 16384
    local function pages(mb)
        return math.floor(mb * MB / size)
    end
    return {loadavg = loadavg, load = opt.load or loadavg, pressure = pressure,
            available = opt.available or available_mb,
            vm = {size = size, free = pages(opt.free or available_mb), speculative = pages(opt.speculative or 0),
                  inactive = pages(opt.inactive or 0), purgeable = pages(opt.purgeable or 0),
                  compressor = opt.compressor or 0, pageouts = opt.pageouts or 0, at = opt.at or 0},
            previous = opt.previous, cores = opt.cores or 12}
end

local function test_suite()
    local count = 0
    local function check(name, got, want)
        count = count + 1
        assert(got == want, string.format("budget test %s: got %s, want %s", name, tostring(got), tostring(want)))
    end

    check("the one-minute window is the cpu reading", parse_loadavg("{ 8.50 2.10 1.00 }\n"), 8.5)
    check("a missing load average is zero", parse_loadavg(""), 0)
    check("pressure is read from the sysctl", parse_pressure("2\n"), 2)
    check("a numeric sysctl answer is parsed", parse_sysctl_number("test", "77\n"), 77)
    local bad_sysctl
    try { function () parse_sysctl_number("test", "not a number\n") end,
          catch { function (raised) bad_sysctl = tostring(raised) end } }
    check("an unparseable sysctl answer raises instead of becoming zero", bad_sysctl ~= nil, true)

    local vmtext = "Mach Virtual Memory Statistics: (page size of 16384 bytes)\n" ..
                   "Pages free:                  65536.\n" ..
                   "Pages inactive:            9999999.\n" ..
                   "Pages speculative:          16384.\n" ..
                   "Pages occupied by compressor: 1024.\n" ..
                   "Pageouts:                       7.\n"
    local vm = parse_vmstat(vmtext)
    check("the page size is read", vm.size, 16384)
    check("inactive pages are not read from vm_stat", vm.free, 65536)
    check("speculative pages are part of the reading", vm.speculative, 16384)
    check("compressor pages are read", vm.compressor, 1024)
    check("pageouts are read", vm.pageouts, 7)

    check("a normal machine counts available memory", memory_headroom(test_reading(0, 1, 11000)), 5)
    check("much inactive memory gives tokens with little free", memory_headroom(test_reading(0, 1, 17203, {free = 135, inactive = 458752})), 9)
    check("warning pressure grants only one token", memory_headroom(test_reading(0, 2, 11000)), 1)
    check("critical pressure grants none", memory_headroom(test_reading(0, 4, 11000)), 0)
    local prev = test_reading(0, 1, 11000).vm
    check("a single pageout does not clamp", memory_headroom(test_reading(0, 1, 11000, {previous = prev, pageouts = prev.pageouts + 1, at = 1000})), 5)
    check("a pageout trickle below the rate does not clamp", memory_headroom(test_reading(0, 1, 11000, {previous = prev, pageouts = prev.pageouts + 8, at = 1000})), 5)
    check("a pageout burst above the rate clamps to one token", memory_headroom(test_reading(0, 1, 11000, {previous = prev, pageouts = prev.pageouts + 128, at = 1000})), 1)
    check("a compressor burst above the rate clamps to one token", memory_headroom(test_reading(0, 1, 11000, {previous = prev, compressor = prev.compressor + 65536, at = 1000})), 1)
    check("a stable compressor at normal pressure is not a limit", memory_headroom(test_reading(0, 1, 11000, {previous = prev, compressor = prev.compressor + 1, at = 1000})), 5)
    local small_pages = test_reading(0, 1, 11000, {size = 4096}).vm
    check("a 4 KB pageout burst below the byte rate does not clamp", memory_headroom(test_reading(0, 1, 11000, {size = 4096, previous = small_pages, pageouts = small_pages.pageouts + 128, at = 1000})), 5)
    check("a 4 KB compressor burst below the byte rate does not clamp", memory_headroom(test_reading(0, 1, 11000, {size = 4096, previous = small_pages, compressor = small_pages.compressor + 65536, at = 1000})), 5)
    check("a machine below the reserve still starts one token", memory_headroom(test_reading(0, 1, 100, {speculative = 100})), 1)

    check("runnable load bounds the jobs", capacity(test_reading(8, 1, 11000), 3, 0), 5)
    check("a holder with no runnable children does not add load", capacity(test_reading(8, 1, 11000), 0, 0), 2)
    check("more runnable holders than load gives no extra headroom", capacity(test_reading(5, 1, 11000), 2, 9), 3)
    check("grants since the last load sample stay counted as load", capacity(test_reading(1, 1, 11000, {load = 10}), 0, 0), 1)
    check("warning pressure with no free memory still starts one token", capacity(test_reading(40, 2, 100), 0, 0), 1)
    check("a memory-fitting request starts with fewer jobs on a busy cpu", capacity(test_reading(20, 1, 11000), 0, 0), 1)
    check("critical pressure makes a request wait", capacity(test_reading(0, 4, 11000), 0, 0), 0)
    check("critical pressure leaves no headroom for holders", capacity(test_reading(0, 4, 11000), 2, 0) - 2, 0)
    check("the pool still takes no reserved cores", capacity(test_reading(0, 1, 99999, {cores = 12}), 0, 0), 10)

    local raw_load = os.iorunv(SYSCTL, {"-n", "vm.loadavg"}):match("{%s*([%d%.]+)")
    local live = sample()
    check("sample reads the machine's load average", tostring(live.loadavg), tostring(tonumber(raw_load)))
    local raw_pressure = os.iorunv(SYSCTL, {"-n", "kern.memorystatus_vm_pressure_level"}):match("(%d+)")
    check("sample reads the machine's pressure", tostring(live.pressure), tostring(tonumber(raw_pressure)))
    local raw_level = tonumber((os.iorunv(SYSCTL, {"-n", "kern.memorystatus_level"})))
    check("sample reads the machine's memorystatus level", math.abs(live.level - raw_level) <= 1, true)
    local raw_memsize = tonumber((os.iorunv(SYSCTL, {"-n", "hw.memsize"})))
    check("sample reads the machine's memory size", live.memsize, raw_memsize)
    check("available memory is the kernel's free share of physical memory", math.abs(live.available - live.level * live.memsize / (100 * MB)) < 1, true)
    local raw_vm = os.iorunv(VMSTAT, {})
    local raw_free = tonumber(raw_vm:match("Pages free:%s+(%d+)"))
    check("sample reads the machine's free pages", math.abs(live.vm.free - raw_free) < 100000, true)
    local first, second = sample(), nil
    os.sleep(1100)
    second = sample()
    check("a second sample chains the first as its previous", second.previous, first.vm)
    check("the second sample stamps a later time", second.vm.at > first.vm.at, true)
    local window = (second.vm.at - first.vm.at) / 1000
    check("the sampling window is the elapsed seconds", window >= 1 and window < 10, true)
    second.pressure, second.available = 1, 11000
    second.vm.pageouts, second.vm.compressor = second.previous.pageouts, second.previous.compressor
    check("two real samples at normal pressure have full headroom", memory_headroom(second), 5)
    second.vm.pageouts = second.previous.pageouts + math.ceil(PAGEOUT_BYTES * window / second.vm.size) + 1
    check("the real previous and at plumbing clamps an above-rate pageout burst", memory_headroom(second), 1)
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

    local base = import("@addon.revenant.workspace", {anonymous = true}).fresh("revenant-budget")
    local no_floor = "REVENANT_BUDGET_DISK_GB=0"
    local pool = path.join(base, "pool")
    local loaded = try { function ()
        os.iorunv(os.programfile(), {"l", "-P", path.directory(os.scriptdir()),
            path.join(os.scriptdir(), "budget.lua"), "status"},
            {envs = {"REVENANT_BUDGET_POOL=" .. path.join(base, "loadpool")}})
        return true
    end } or false
    check("the tool loads as a module in a fresh process", loaded, true)
    local queue = path.join(pool, "queue")
    os.mkdir(queue)
    local stale = path.join(queue, "1-0000000000001-00000001.ticket")
    io.writefile(stale, "1")
    check("a ticket whose holder died does not block", ahead_of(pool, "2-0000000000002-00000002.ticket", 1), false)
    check("and is removed", os.isfile(stale), false)

    local named_pool = path.join(base, "namedpool")
    os.mkdir(named_pool)
    local anonymous = enqueue(named_pool, 2, 1, nil)
    local named_waiters = waiters(named_pool)
    check("a ticket enqueued without a holder still names the process that waits", #named_waiters, 1)
    check("and names it by pid, not by nil", named_waiters[1] and named_waiters[1].pid, os.getpid())
    leave(anonymous)

    local function ticket_at(name, need)
        local file = path.join(queue, name)
        local lock = io.openlock(file)
        lock:trylock()
        io.writefile(file, tostring(need))
        return {name = name, file = file, lock = lock}
    end
    local large = ticket_at("2-0000000000001-00000001.ticket", 6)
    check("a large ticket ahead does not block a small request when the pool could not hold it even empty", ahead_of(pool, "2-0000000000002-00000002.ticket", 1), false)
    check("and does block one when the pool could hold it once its holders are done", ahead_of(pool, "2-0000000000002-00000002.ticket", 6), true)
    leave(large)
    check("a ticket behind the request does not block", ahead_of(pool, "1-0000000000000-00000000.ticket", 1), false)

    local name_a, name_b = "2-0000000000003-00000003.ticket", "2-0000000000004-00000004.ticket"
    local early, late = ticket_at(name_a, 4), ticket_at(name_b, 4)
    check("an earlier ticket blocks a later one", ahead_of(pool, name_b, 4), true)
    check("a later ticket does not block the earlier one", ahead_of(pool, name_a, 4), false)
    early.lock:unlock()
    early.lock:close()
    check("a dead holder stops blocking", ahead_of(pool, name_b, 4), false)
    leave(late)

    local stamp_pool = path.join(base, "stamppool")
    os.mkdir(stamp_pool)
    local stamp_log = path.join(base, "stamp.log")
    local granter = process.openv(os.programfile(), {"l", "-P", path.directory(os.scriptdir()),
        path.join(os.scriptdir(), "budget.lua"), "run", "--class", "normal", "--jobs", "1", "--min", "1", "--", "/bin/sleep", "30"},
        {outpath = stamp_log, errpath = stamp_log, envs = {"REVENANT_BUDGET_POOL=" .. stamp_pool, no_floor}})
    local stamp_deadline = os.mclock() + 30000
    while not (held_slots(stamp_pool) >= 1 and read_grants(stamp_pool) >= 0.9) and os.mclock() < stamp_deadline do
        os.sleep(500)
    end
    check("a second process sees the grant made by the first", read_grants(stamp_pool) >= 0.9, true)
    check("the grant stamps the shared slot under the lock", (io.readfile(slot_path(stamp_pool, 1)) or ""):match("g %d+ %d+") ~= nil, true)
    granter:kill()
    os.tryrm(slot_path(stamp_pool, 1))
    local slot = slot_path(stamp_pool, 1)
    io.writefile(slot, string.format("12345\ng %d 4\n", os.time() - 30))
    check("a grant's load decays across the window", math.abs(read_grants(stamp_pool) - 2) < 0.2, true)
    io.writefile(slot, string.format("12345\ng %d 4\n", os.time() - 70))
    check("a grant older than the window adds no load", read_grants(stamp_pool), 0)

    local env_script = path.join(base, "env.lua")
    io.writefile(env_script, "print(os.getenv('XMAKE_MAX_JOBS'))\n")
    local nested = os.iorunv(os.programfile(), {"l", "-P", path.directory(os.scriptdir()), path.join(os.scriptdir(), "budget.lua"),
        "run", "--", os.programfile(), "l", "-P", base, env_script}, {envs = {REVENANT_BUDGET_HELD = "3", REVENANT_BUDGET_POOL = pool}}):match("(%d+)")
    check("a command under a budget takes its parent's tokens without a pool", nested, "3")
    check("and holds no slot of its own", held_slots(pool), 0)

    local started_anyway = false
    try { function ()
        os.iorunv(os.programfile(), {"l", "-P", path.directory(os.scriptdir()), path.join(os.scriptdir(), "budget.lua"), "run", "--", "/usr/bin/true"},
            {envs = {REVENANT_BUDGET_DISK_GB = "100000000", REVENANT_BUDGET_POOL = pool, REVENANT_BUDGET_HELD = ""}})
        started_anyway = true
    end, catch { function () end } }
    check("a volume below the floor starts nothing", started_anyway, false)
    check("and an empty pool stays empty below the floor", held_slots(pool), 0)

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
    local granted_journal = io.readfile(journal_path(fresh)) or ""
    check("the grant journals the class, tokens and seconds with the waiting process", granted_journal:find("class normal", 1, true) ~= nil
          and granted_journal:find("tokens 1", 1, true) ~= nil and granted_journal:find("wait ", 1, true) ~= nil
          and granted_journal:find("pid " .. tostring(os.getpid()), 1, true) ~= nil, true)
    local test_project = path.directory(os.scriptdir())
    local test_script = path.join(os.scriptdir(), "budget.lua")
    record_wait(fresh, "critical", 2, 4, {pid = os.getpid(), worktree = test_project, command = "/usr/bin/true", at = os.time()})
    local waited_seconds, waited_entries, waited_lines = wait_summary(fresh)
    check("the summary adds up a day's waits by holder", waited_entries == 2 and waited_seconds == 4 and #waited_lines == 2, true)
    local status_with_wait = os.iorunv(os.programfile(), {"l", "-P", test_project, test_script, "status"}, {envs = {REVENANT_BUDGET_POOL = fresh}})
    check("status prints the sum of waits and who waited", status_with_wait:find("waited    ", 1, true) ~= nil
          and status_with_wait:find("/usr/bin/true", 1, true) ~= nil, true)
    check("and the re-check happens without a fixed patience wait", calls >= 3 and elapsed < 10000, true)
    release_locks(granted)

    local multi_pool = path.join(base, "multi")
    local multi = acquire(multi_pool, "normal", 4, 4, function () return test_reading(0, 1, 11000) end, 1)
    check("a four-token request gets four slots", #multi, 4)
    local stamped = read_grants(multi_pool)
    check("four granted slots count as four tokens, not sixteen", stamped >= 3.9 and stamped <= 4.001, true)
    release_locks(multi)

    local keep_pool = path.join(base, "keep")
    os.mkdir(keep_pool)
    io.writefile(slot_path(keep_pool, 1), string.format("111\ng %d 2\n", os.time()))
    local free_keep = snapshot_slots(keep_pool, os.cpuinfo("ncpu"))
    release_locks(free_keep)
    check("sampling a free slot keeps its grant stamp", read_grants(keep_pool) >= 1.9, true)

    local short_calls = 0
    local short_error
    try { function ()
        acquire(path.join(base, "short"), "normal", 2, 4, function ()
            short_calls = short_calls + 1
            if short_calls > 5 then
                raise("stopped")
            end
            return test_reading(50, 1, 100)
        end, 1)
    end, catch { function (raised) short_error = tostring(raised) end } }
    check("a memory-short empty pool waits instead of granting a degraded minimum", short_error ~= nil and short_calls > 5, true)

    local short_pool = path.join(base, "short-held")
    os.mkdir(short_pool)
    local short_blocker = io.openlock(slot_path(short_pool, 1))
    short_blocker:trylock()
    local held_short_calls = 0
    local held_short_error
    try { function ()
        acquire(short_pool, "normal", 2, 4, function ()
            held_short_calls = held_short_calls + 1
            if held_short_calls > 5 then
                raise("stopped")
            end
            return test_reading(0, 1, 100)
        end, 1)
    end, catch { function (raised) held_short_error = tostring(raised) end } }
    short_blocker:unlock()
    short_blocker:close()
    check("a non-empty pool with a memory shortfall waits and starts nothing", held_short_error ~= nil and held_short_calls > 5, true)

    local full_grant = acquire(path.join(base, "fullmin"), "normal", 4, 4, function () return test_reading(50, 1, 11000) end, 1)
    check("an empty pool under load grants the full minimum when memory fits", #full_grant, 4)
    release_locks(full_grant)

    local guarantee_pool = path.join(base, "guarantee")
    local guarantee_queue = path.join(guarantee_pool, "queue")
    os.mkdir(guarantee_queue)
    local function waiting_ticket(queue, name, need)
        local file = path.join(queue, name)
        local lock = io.openlock(file)
        lock:trylock()
        io.writefile(file, tostring(need))
        return {name = name, file = file, lock = lock}
    end
    local older = waiting_ticket(guarantee_queue, "1-0000000000001-00000001.ticket", 4)
    local older_calls = 0
    local function under_load()
        older_calls = older_calls + 1
        if older_calls == 4 then
            leave(older)
        end
        return test_reading(50, 1, 11000)
    end
    local guaranteed = acquire(guarantee_pool, "normal", 4, 4, under_load, 1)
    check("an empty pool grants the oldest ticket its minimum under outside load", #guaranteed, 4)
    check("the guarantee waits for the older ticket to leave", older_calls >= 4, true)
    local stamped = read_grants(guarantee_pool)
    check("four guaranteed slots count as four tokens", stamped >= 3.9 and stamped <= 4.001, true)
    local blocked_calls = 0
    local blocked_error
    try { function ()
        acquire(guarantee_pool, "normal", 4, 4, function ()
            blocked_calls = blocked_calls + 1
            if blocked_calls > 5 then
                raise("stopped")
            end
            return test_reading(50, 1, 11000)
        end, 1)
    end, catch { function (raised) blocked_error = tostring(raised) end } }
    check("a second ticket cannot take the guarantee while the pool is held", blocked_error ~= nil and blocked_calls > 5, true)
    release_locks(guaranteed)

    local order_pool = path.join(base, "order")
    local order_queue = path.join(order_pool, "queue")
    os.mkdir(order_queue)
    local older_critical = waiting_ticket(order_queue, "1-0000000000001-00000001.ticket", 6)
    local younger_calls = 0
    local younger_error
    try { function ()
        acquire(order_pool, "background", 2, 2, function ()
            younger_calls = younger_calls + 1
            if younger_calls > 5 then
                raise("stopped")
            end
            return test_reading(50, 1, 20000)
        end, 1)
    end, catch { function (raised) younger_error = tostring(raised) end } }
    check("a younger ticket cannot take the guarantee past an older large one", younger_error ~= nil and younger_calls > 5, true)
    check("and it leaves no grant stamp", (io.readfile(slot_path(order_pool, 1)) or ""):match("g %d+ %d+") == nil, true)
    leave(older_critical)
    local older_grant = acquire(order_pool, "critical", 6, 6, function () return test_reading(50, 1, 20000) end, 1)
    check("the older critical ticket then gets its six tokens", #older_grant, 6)
    release_locks(older_grant)

    local backfill_pool = path.join(base, "backfill")
    local backfill_queue = path.join(backfill_pool, "queue")
    os.mkdir(backfill_queue)
    local starved = waiting_ticket(backfill_queue, "1-0000000000001-00000001.ticket", 6)
    local backfill_grant = acquire(backfill_pool, "normal", 2, 2, function () return test_reading(50, 1, 5120) end, 1)
    check("a ticket whose minimum fits memory backfills past a memory-starved older one", #backfill_grant, 2)
    release_locks(backfill_grant)
    leave(starved)
    local starved_grant = acquire(backfill_pool, "critical", 6, 6, function () return test_reading(50, 1, 20000) end, 1)
    check("the older ticket then gets its six tokens when headroom allows", #starved_grant, 6)
    release_locks(starved_grant)

    local fair_pool = path.join(base, "fair")
    local fair_queue = path.join(fair_pool, "queue")
    os.mkdir(fair_queue)
    local function overloaded()
        return test_reading(50, 1, 20000)
    end
    local fair_first_name = "2-0000000000001-00000001.ticket"
    local function clear_other_tickets()
        for _, file in ipairs(os.files(path.join(fair_queue, "*.ticket"))) do
            if path.filename(file) ~= fair_first_name then
                os.tryrm(file)
            end
        end
    end
    local function polls_without_grant(class, minimum, reading_fn)
        local calls = 0
        local grant
        try { function ()
            grant = acquire(fair_pool, class, minimum, minimum, function ()
                calls = calls + 1
                if calls > 5 then
                    raise("stopped")
                end
                return reading_fn()
            end, 1)
        end, catch { function () end } }
        clear_other_tickets()
        return grant or {}
    end
    local function waits_without_grant(class, minimum)
        return #polls_without_grant(class, minimum, overloaded) == 0
    end
    local fair_holder = acquire(fair_pool, "normal", 1, 1, overloaded, 1)
    check("a request for one token gets it under outside load with one holder", #fair_holder, 1)
    local fair_first = waiting_ticket(fair_queue, fair_first_name, 2)
    check("a request for one token does not overtake an older one for two under outside load", waits_without_grant("normal", 1), true)
    check("and a request of the background class does not either", waits_without_grant("background", 1), true)
    local critical_grant = acquire(fair_pool, "critical", 1, 1, overloaded, 1)
    check("a critical request is not held back by an older normal one", #critical_grant, 1)
    release_locks(critical_grant)
    local function pressed()
        return test_reading(50, 2, 20000)
    end
    local pressed_grant = polls_without_grant("normal", 1, pressed)
    check("under memory pressure an older request for two tokens does not hold back one for one", #pressed_grant, 1)
    release_locks(pressed_grant)
    local function short_of_memory()
        return test_reading(50, 1, 100)
    end
    local short_grant = polls_without_grant("normal", 1, short_of_memory)
    check("with less free memory than the reserve an older request for two tokens does not hold back one for one", #short_grant, 1)
    release_locks(short_grant)
    leave(fair_first)
    local after_grant = acquire(fair_pool, "normal", 1, 1, overloaded, 1)
    check("the request for one token goes once the older one is gone", #after_grant, 1)
    release_locks(after_grant)
    release_locks(fair_holder)
    local drain_holder = acquire(fair_pool, "normal", 1, 1, overloaded, 1)
    local drain_calls = 0
    local drained = acquire(fair_pool, "normal", 2, 2, function ()
        drain_calls = drain_calls + 1
        if drain_calls == 3 then
            release_locks(drain_holder)
        end
        return overloaded()
    end, 1)
    check("a request for two tokens waits for its holder and then starts under outside load", #drained, 2)
    check("and it did wait for the holder", drain_calls >= 3, true)
    release_locks(drained)

    local age_pool = path.join(base, "age")
    local age_queue = path.join(age_pool, "queue")
    os.mkdir(age_queue)
    local age_holder = acquire(age_pool, "normal", 1, 1, overloaded, 1)
    local aged_name = "2-0000000000001-00000001.ticket"
    local aged_ticket = waiting_ticket(age_queue, aged_name, 2)
    local function polls_in_age_pool(class, minimum)
        local calls = 0
        local grant
        try { function ()
            grant = acquire(age_pool, class, minimum, minimum, function ()
                calls = calls + 1
                if calls > 5 then
                    raise("stopped")
                end
                return overloaded()
            end, 1)
        end, catch { function () end } }
        local markers = #os.files(path.join(age_queue, "aged-*.ticket"))
        for _, file in ipairs(os.files(path.join(age_queue, "*.ticket"))) do
            if not path.filename(file):find(aged_name, 1, true) then
                os.tryrm(file)
            end
        end
        return grant or {}, markers
    end
    local young_critical = polls_in_age_pool("critical", 1)
    check("a critical request passes an older normal one that has not aged", #young_critical, 1)
    release_locks(young_critical)
    io.writefile(aged_path(age_pool, aged_name), "2")
    local listed = waiters(age_pool)
    check("listing the queue shows the aged ticket once", #listed, 1)
    check("and does not take its marker for a ticket without a holder", os.isfile(aged_path(age_pool, aged_name)), true)
    local held_critical = polls_in_age_pool("critical", 1)
    check("a critical request waits behind an older normal one that has aged", #held_critical, 0)
    local held_background = polls_in_age_pool("background", 1)
    check("and so does one of the background class", #held_background, 0)
    leave(aged_ticket)
    check("the marker of an aged ticket is gone when the ticket leaves", os.isfile(aged_path(age_pool, aged_name)), false)
    os.setenv("REVENANT_BUDGET_AGING_S", "0")
    local _, marked = polls_in_age_pool("normal", 2)
    os.setenv("REVENANT_BUDGET_AGING_S", "")
    check("a request that waited longer than the aging time marks its ticket aged", marked, 1)
    release_locks(age_holder)

    local dead_pool = path.join(base, "deadholder")
    os.mkdir(dead_pool)
    io.writefile(slot_path(dead_pool, 1), string.format("99999\ng %d 2\n", os.time() - 10))
    local dead_grant = acquire(dead_pool, "normal", 3, 3, function () return test_reading(55, 1, 11000) end, 1)
    check("a dead holder's slot and stamp do not stop the guarantee", #dead_grant, 3)
    release_locks(dead_grant)

    local holder_script = path.join(base, "holder.lua")
    io.writefile(holder_script, "function main(file)\n local lock = io.openlock(file)\n lock:trylock()\n io.writefile(file, tostring(os.getpid()))\n os.sleep(120000)\nend\n")
    local log = path.join(base, "holder.log")
    local holder = process.openv(os.programfile(), {"l", holder_script, slot_path(pool, 1)}, {outpath = log, errpath = log})
    local deadline = os.mclock() + 30000
    while held_slots(pool) < 1 and os.mclock() < deadline do
        os.sleep(500)
    end
    check("a running command holds the tokens it was granted", held_slots(pool), 1)
    holder:kill()
    deadline = os.mclock() + 10000
    while held_slots(pool) > 0 and os.mclock() < deadline do
        os.sleep(200)
    end
    check("a holder killed with SIGKILL releases its tokens", held_slots(pool), 0)

    do
        local project = path.absolute(path.directory(os.scriptdir()))
        local script = path.join(os.scriptdir(), "budget.lua")
        local who_pool = path.join(base, "whopool")
        os.mkdir(who_pool)
        local who_log = path.join(base, "who.log")
        local who_holder = process.openv(os.programfile(), {"l", "-P", project, script, "run", "--class", "normal", "--jobs", "1", "--min", "1", "--", "/bin/sleep", "40"},
            {outpath = who_log, errpath = who_log, envs = {"REVENANT_BUDGET_POOL=" .. who_pool, no_floor}})
        deadline = os.mclock() + 30000
        while not (holders(who_pool)[1] and holders(who_pool)[1].command == "/bin/sleep 40") and os.mclock() < deadline do
            os.sleep(300)
        end
        local named = holders(who_pool)
        check("a held token is named: one holder", #named, 1)
        check("by the pid of the budget process that holds it", named[1] ~= nil and named[1].pid ~= nil and process_command(named[1].pid):find("budget.lua", 1, true) ~= nil, true)
        check("by its worktree", named[1] and path.absolute(named[1].worktree), project)
        check("and by its command", named[1] and named[1].command, "/bin/sleep 40")
        local holder_text = holder_lines(who_pool, "")[1] or ""
        check("the line for a holder has its pid, worktree and command", holder_text:find("pid " .. tostring(named[1] and named[1].pid), 1, true) ~= nil
              and holder_text:find(project, 1, true) ~= nil and holder_text:find("/bin/sleep 40", 1, true) ~= nil, true)
        local shown = os.iorunv(os.programfile(), {"l", "-P", project, script, "status"}, {envs = {REVENANT_BUDGET_POOL = who_pool}})
        check("status names the holder", shown:find("pid " .. tostring(named[1] and named[1].pid) .. " holds 1 token(s)", 1, true) ~= nil and shown:find("/bin/sleep 40", 1, true) ~= nil, true)

        local everything = tostring(math.max(1, os.cpuinfo("ncpu") - RESERVE_CORES))
        local waiter_log = path.join(base, "waiter.log")
        local who_waiter = process.openv(os.programfile(), {"l", "-P", project, script, "run", "--class", "critical", "--jobs", everything, "--min", everything, "--", "/usr/bin/true"},
            {outpath = waiter_log, errpath = waiter_log, envs = {"REVENANT_BUDGET_POOL=" .. who_pool, no_floor}})
        deadline = os.mclock() + 30000
        while #waiters(who_pool) < 1 and os.mclock() < deadline do
            os.sleep(300)
        end
        local waiting = waiters(who_pool)
        check("a request that waits has a ticket with a live holder", #waiting, 1)
        check("whose class is the request's", waiting[1] and waiting[1].class, "critical")
        check("whose pid is the budget process that waits", waiting[1] ~= nil and waiting[1].pid ~= nil and process_command(waiting[1].pid):find("budget.lua", 1, true) ~= nil, true)
        check("whose command is the one it will run", waiting[1] and waiting[1].command, "/usr/bin/true")
        local waiting_line = waiter_lines(who_pool, "")[1] or ""
        check("the line for a waiter has its pid, class, worktree and command", waiting_line:find("pid " .. tostring(waiting[1] and waiting[1].pid), 1, true) ~= nil
              and waiting_line:find("critical class", 1, true) ~= nil and waiting_line:find(project, 1, true) ~= nil and waiting_line:find("/usr/bin/true", 1, true) ~= nil, true)
        deadline = os.mclock() + 30000
        while not (io.readfile(waiter_log) or ""):find("held by:", 1, true) and os.mclock() < deadline do
            os.sleep(300)
        end
        local announced = io.readfile(waiter_log) or ""
        check("a request that waits has said so in its log while it still waits, naming the holder's pid and command", announced:find("budget: waiting for", 1, true) ~= nil
              and announced:find("pid " .. tostring(named[1] and named[1].pid) .. " holds", 1, true) ~= nil and announced:find("/bin/sleep 40", 1, true) ~= nil, true)
        who_waiter:kill()
        who_holder:kill()
        deadline = os.mclock() + 10000
        while (#waiters(who_pool) > 0 or held_slots(who_pool) > 0) and os.mclock() < deadline do
            os.sleep(200)
        end
        check("a waiter that was killed leaves no ticket in the list", #waiters(who_pool), 0)
        check("and a holder that was killed no token", #holders(who_pool), 0)
        local sized = enqueue(who_pool, 2, 6, {pid = os.getpid(), worktree = project, command = "x", at = os.time()})
        check("a ticket that names its holder still carries the tokens it needs", ahead_of(who_pool, "9-9999999999999-99999999.ticket", 1), false)
        check("and blocks a later request that fits it", ahead_of(who_pool, "9-9999999999999-99999999.ticket", 6), true)
        leave(sized)

        local function matching(command)
            local listing = try { function () return os.iorunv(PS, {"-ax", "-o", "pid=,command="}) end } or ""
            local pids = {}
            for line in listing:gmatch("[^\n]+") do
                local pid, text = line:match("^%s*(%d+)%s+(.-)%s*$")
                if text == command then
                    table.insert(pids, tonumber(pid))
                end
            end
            return pids
        end
        local function alive(pid)
            return process_command(pid) ~= ""
        end
        local orphan_pool = path.join(base, "orphanpool")
        os.mkdir(orphan_pool)
        local sleeping = "/bin/sleep 4711"
        local parent_log = path.join(base, "parent.log")
        local parent = process.openv("/bin/sh", {"-c", '"$0" l -P "$1" "$2" run --class normal --jobs 1 --min 1 -- /bin/sleep 4711; true', os.programfile(), project, script},
            {outpath = parent_log, errpath = parent_log, envs = {"REVENANT_BUDGET_POOL=" .. orphan_pool, no_floor}})
        deadline = os.mclock() + 30000
        while (held_slots(orphan_pool) < 1 or #matching(sleeping) < 1) and os.mclock() < deadline do
            os.sleep(300)
        end
        local orphan_holders = holders(orphan_pool)
        local budget_pid = orphan_holders[1] and orphan_holders[1].pid
        local shell_pid = budget_pid and parent_of(budget_pid)
        check("a run under a parent shell holds its token and runs its command", held_slots(orphan_pool) == 1 and #matching(sleeping) == 1 and shell_pid ~= nil and shell_pid > 1, true)
        local command_pids = matching(sleeping)
        if shell_pid and shell_pid > 1 then
            try { function () os.iorunv("/bin/kill", {"-9", tostring(shell_pid)}) end }
        end
        deadline = os.mclock() + 20000
        while (held_slots(orphan_pool) > 0 or #matching(sleeping) > 0 or (budget_pid and alive(budget_pid))) and os.mclock() < deadline do
            os.sleep(300)
        end
        local tokens_left, budget_alive, commands_left, holders_left = held_slots(orphan_pool), budget_pid ~= nil and alive(budget_pid), #matching(sleeping), #holders(orphan_pool)
        for _, pid in ipairs(command_pids) do
            try { function () os.iorunv("/bin/kill", {"-9", tostring(pid)}) end }
        end
        if budget_pid then
            try { function () os.iorunv("/bin/kill", {"-9", tostring(budget_pid)}) end }
        end
        parent:close()
        check("a parent killed with SIGKILL leaves no token held by its budget run", tokens_left, 0)
        check("nor the budget run itself", budget_alive, false)
        check("nor the command it ran", commands_left, 0)
        check("nor a holder in the list", holders_left, 0)
        local stops = {}
        local function read_stops()
            stops = {}
            for line in (io.readfile(journal_path(orphan_pool)) or ""):gmatch("[^\n]+") do
                if line:find("\tstopped ", 1, true) then
                    table.insert(stops, line)
                end
            end
        end
        deadline = os.mclock() + 30000
        read_stops()
        while #stops == 0 and os.mclock() < deadline do
            os.sleep(300)
            read_stops()
        end
        local stopped_sleep, stopped_run = "", ""
        for _, line in ipairs(stops) do
            if line:find("\t/bin/sleep 4711$") then
                stopped_sleep = line
            elseif line:find("\tpid " .. tostring(budget_pid) .. "\t", 1, true) then
                stopped_run = line
            end
        end
        local tail = "\tparent " .. tostring(shell_pid) .. "\trun " .. tostring(budget_pid) .. "\t"
        check("the watcher journaled the command it stopped, with the pid, the dead parent and the budget run, in the wait journal", stopped_sleep:find("^at %d+\tstopped TERM\tpid " .. tostring(command_pids[1]) .. tail:gsub("%p", "%%%0")) ~= nil
            and stopped_run:find("\tstopped TERM\t", 1, true) ~= nil and stopped_run:find(tail, 1, true) ~= nil, true)

        local now = os.time()
        local counted = path.join(base, "countpool")
        os.mkdir(counted)
        io.writefile(journal_path(counted), table.concat({
            string.format("at %d\tstopped TERM\tpid 11\tparent 4\trun 5\tone", now - 30),
            string.format("at %d\tstopped KILL\tpid 11\tparent 4\trun 5\tone", now - 28),
            string.format("at %d\tstopped TERM\tpid 12\tparent 4\trun 5\ttwo words", now - 20),
            string.format("at %d\tstopped TERM\tpid 13\tparent 4\trun 5\told", now - WAIT_DAY_S - 100),
            string.format("at %d\tstopped TERM\tpid x", now - 10),
            string.format("at %d\tclass normal\ttokens 1\twait 3\tpid 9\th %d\t/w\tcmd", now - 10, now - 10),
            "torn"}, "\n") .. "\n")
        local number, newest = stop_summary(counted)
        check("a process stopped by TERM and then KILL counts once, an old line and torn lines not at all", number, 2)
        check("the newest stop is the last whole line in the last day", newest ~= nil and newest:find(" 12 TERM two words", 1, true) ~= nil, true)
        local report_log = path.join(base, "report.log")
        local reporter = process.openv(os.programfile(), {"l", "-P", project, script, "status"},
            {outpath = report_log, errpath = report_log, envs = {"REVENANT_BUDGET_POOL=" .. counted, no_floor}})
        reporter:wait(30000)
        reporter:close()
        local report = io.readfile(report_log) or ""
        check("status prints the count of processes and survives a torn journal", report:find("stopped   2 process(es) by the watcher over the last 24 h; newest: ", 1, true) ~= nil, true)

        local held_pool = path.join(base, "heldpool")
        os.mkdir(held_pool)
        local lock = io.openlock(journal_path(held_pool) .. ".lock")
        lock:trylock()
        local late_log = path.join(base, "late.log")
        local late = process.openv(os.programfile(), {"l", "-P", project, script, "stopped", "TERM", "7", "8", "9 /bin/late"},
            {outpath = late_log, errpath = late_log, envs = {"REVENANT_BUDGET_POOL=" .. held_pool, no_floor}})
        os.sleep(2500)
        local early = os.isfile(journal_path(held_pool)) and io.readfile(journal_path(held_pool)) or nil
        lock:unlock()
        lock:close()
        late:wait(20000)
        late:close()
        check("a stop line waits for the journal lock and is neither written without it nor lost", early == nil and (io.readfile(journal_path(held_pool)) or ""):find("\tstopped TERM\tpid 9\tparent 7\trun 8\t/bin/late", 1, true) ~= nil, true)

        local broken_pool = path.join(base, "brokenpool")
        os.mkdir(broken_pool)
        local broken_log = path.join(base, "broken.log")
        local broken = process.openv("/bin/sh", {"-c", [[ "$0" l -P "$1" "$2" run --class normal --jobs 1 --min 1 -- /bin/sleep 4713; true ]], os.programfile(), project, script},
            {outpath = broken_log, errpath = broken_log, envs = {"REVENANT_BUDGET_POOL=" .. broken_pool, no_floor}})
        deadline = os.mclock() + 30000
        while (held_slots(broken_pool) < 1 or #matching("/bin/sleep 4713") < 1) and os.mclock() < deadline do
            os.sleep(300)
        end
        os.tryrm(journal_path(broken_pool))
        os.mkdir(journal_path(broken_pool))
        local broken_run = holders(broken_pool)[1]
        local broken_shell = broken_run and parent_of(broken_run.pid)
        local broken_pids = matching("/bin/sleep 4713")
        if broken_shell and broken_shell > 1 then
            try { function () os.iorunv("/bin/kill", {"-9", tostring(broken_shell)}) end }
        end
        local errors_file = path.join(broken_pool, "wait-journal.errors")
        deadline = os.mclock() + 30000
        while (not os.isfile(errors_file) or #matching("/bin/sleep 4713") > 0) and os.mclock() < deadline do
            os.sleep(300)
        end
        local broken_left = #matching("/bin/sleep 4713")
        for _, pid in ipairs(broken_pids) do
            try { function () os.iorunv("/bin/kill", {"-9", tostring(pid)}) end }
        end
        broken:close()
        local errors_text = os.isfile(errors_file) and io.readfile(errors_file) or ""
        check("a journal that cannot be written does not keep the watcher from stopping the command", broken_left, 0)
        check("and the failure is recorded beside the journal, naming the signal, the dead parent and the run", errors_text:find("stopped TERM parent " .. tostring(broken_shell) .. " run " .. tostring(broken_run and broken_run.pid) .. ": the journal write failed", 1, true) ~= nil, true)

        local unwritable = path.join(base, "unwritablepool")
        os.mkdir(path.join(unwritable, "wait-journal"))
        local unwritable_log = path.join(base, "unwritable.log")
        local unwritable_run = process.openv(os.programfile(), {"l", "-P", project, script, "run", "--class", "normal", "--jobs", "1", "--min", "1", "--", "/usr/bin/true"},
            {outpath = unwritable_log, errpath = unwritable_log, envs = {"REVENANT_BUDGET_POOL=" .. unwritable, no_floor}})
        local finished, unwritable_status = unwritable_run:wait(30000)
        unwritable_run:close()
        local unwritable_errors = path.join(unwritable, "wait-journal.errors")
        check("a run whose wait journal cannot be written still gets its token and runs its command", finished == 1 and unwritable_status == 0, true)
        check("and the failed write is on stderr and in wait-journal.errors", (io.readfile(unwritable_log) or ""):find("the journal write failed", 1, true) ~= nil
            and os.isfile(unwritable_errors) and io.readfile(unwritable_errors):find("granted 1 token(s) to pid", 1, true) ~= nil, true)

        local stubborn_pool = path.join(base, "stubbornpool")
        os.mkdir(stubborn_pool)
        local stubborn_log = path.join(base, "stubborn.log")
        local stubborn = process.openv("/bin/sh", {"-c", [[ "$0" l -P "$1" "$2" run --class normal --jobs 1 --min 1 -- /bin/sh -c 'trap "" TERM; exec /bin/sleep 4712'; true ]], os.programfile(), project, script},
            {outpath = stubborn_log, errpath = stubborn_log, envs = {"REVENANT_BUDGET_POOL=" .. stubborn_pool, no_floor}})
        deadline = os.mclock() + 30000
        while (held_slots(stubborn_pool) < 1 or #matching("/bin/sleep 4712") < 1) and os.mclock() < deadline do
            os.sleep(300)
        end
        local stubborn_run = holders(stubborn_pool)[1]
        local stubborn_shell = stubborn_run and parent_of(stubborn_run.pid)
        local stubborn_pids = matching("/bin/sleep 4712")
        if stubborn_shell and stubborn_shell > 1 then
            try { function () os.iorunv("/bin/kill", {"-9", tostring(stubborn_shell)}) end }
        end
        deadline = os.mclock() + 30000
        while (#matching("/bin/sleep 4712") > 0 or held_slots(stubborn_pool) > 0) and os.mclock() < deadline do
            os.sleep(300)
        end
        local stubborn_left = #matching("/bin/sleep 4712")
        for _, pid in ipairs(stubborn_pids) do
            try { function () os.iorunv("/bin/kill", {"-9", tostring(pid)}) end }
        end
        stubborn:close()
        local stubborn_journal = io.readfile(journal_path(stubborn_pool)) or ""
        check("a command that ignores TERM is ended by KILL two seconds later", stubborn_left, 0)
        check("and the journal has a TERM line and a KILL line for it", #stubborn_pids == 1 and stubborn_journal:find("\tstopped TERM\tpid " .. tostring(stubborn_pids[1]) .. "\t", 1, true) ~= nil
            and stubborn_journal:find("\tstopped KILL\tpid " .. tostring(stubborn_pids[1]) .. "\t", 1, true) ~= nil, true)
    end

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
    elseif command == "stopped" then
        record_stops(pool_folder(), args[1], args[2], args[3], args[4] or "")
    elseif command == "status" then
        status()
    elseif command == "test" then
        test_suite()
    else
        raise("usage: ./xmakew l -P . tools/budget.lua run [--class critical|normal|background] [--jobs N] [--min N] [--mb M] -- <command> [args...] | status | test")
    end
end
