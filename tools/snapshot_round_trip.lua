-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local ALIGNMENT = 1048576

local snapshot = import("snapshot.decode", {rootdir = os.scriptdir()})

local USAGE = [==[usage: ./xmakew l tools/snapshot_round_trip.lua --rootfs DIR [--emulator EMU]
                                                             [--binary GUEST] [--guest FILE]
                                                             [--ios-build CODE]
                                                             [--save-ticks N[,N...]] [--ticks N]
                                                             [--time-scale S] [--work DIR]

For each save tick N, saves a snapshot at N, boots the save's clone cold to --ticks, restores the
saved snapshot on a second clone to --ticks, and requires the cold and restored snapshots to be
identical. The cold boot does not depend on N, so one cold boot serves every save tick. Each run
boots its own clone of the rootfs. The device key store is random per device state, so every run
takes the first save's key store. The guest sees the image's file times, not the clone's host
times, so every clone of one image is interchangeable.

Every save tick is compared before the run fails, so one failure does not hide another. A mismatch
names the first differing field of the two snapshots (tools/snapshot/decode.lua walks their layout),
and the timing table prints even when a round trip fails. The snapshots and timing files of every
run stay in --work.

--guest copies FILE into every clone at --binary, so a guest built apart from the rootfs runs in
it. --ios-build names the iOS build of a rootfs that carries no firmware metadata. Without
--binary the guest boots launchd. The check is skipped without --rootfs. The save ticks and
--ticks must be multiples of 2^20, and every save tick below --ticks. Clones use cp -c, so this
runs on macOS. Each boot is timed with /usr/bin/time: the cold boot runs from zero to --ticks,
each restored boot from its save tick to --ticks, and each save from zero to its tick.]==]

local flags = {
    ["--emulator"] = "emulator",
    ["--rootfs"] = "rootfs",
    ["--binary"] = "binary",
    ["--guest"] = "guest",
    ["--ios-build"] = "ios_build",
    ["--work"] = "work",
    ["--save-ticks"] = "save_ticks",
    ["--ticks"] = "ticks",
    ["--time-scale"] = "time_scale",
}

local function parse_ticks(text)
    local values = {}
    for item in text:gmatch("[^,]+") do
        local value = tonumber(item)
        if not value then
            raise("--save-ticks names %s, which is not a number\n%s", item, USAGE)
        end
        values[#values + 1] = value
    end
    return values
end

local function parse(...)
    local arguments = {...}
    local options = {
        emulator = path.join(os.projectdir(), "build", "macosx", "arm64", "release", "emulator"),
        work = path.join(os.projectdir(), ".cache", "scratch", "snapshot-round-trip"),
        save_ticks = "1048576",
        ticks = "2097152",
        time_scale = "10",
    }
    local index = 1
    while index <= #arguments do
        if arguments[index] == "help" or arguments[index] == "--help" then
            print(USAGE)
            return nil
        end
        local key = flags[arguments[index]]
        if not key then
            raise("unknown argument " .. tostring(arguments[index]) .. "\n" .. USAGE)
        end
        if arguments[index + 1] == nil then
            raise(arguments[index] .. " needs a value\n" .. USAGE)
        end
        options[key] = arguments[index + 1]
        index = index + 2
    end
    options.ticks = tonumber(options.ticks)
    options.save_ticks = parse_ticks(options.save_ticks)
    if not tonumber(options.time_scale) then
        raise("--time-scale must be a number\n" .. USAGE)
    end
    if options.guest and not options.binary then
        raise("--guest needs --binary, the path the guest runs at in the rootfs\n" .. USAGE)
    end
    options.emulator = path.absolute(options.emulator)
    options.work = path.absolute(options.work)
    if not options.ticks or options.ticks <= 0 or options.ticks % ALIGNMENT ~= 0 then
        raise("--ticks must be a multiple of %d\n%s", ALIGNMENT, USAGE)
    end
    for _, save in ipairs(options.save_ticks) do
        if save <= 0 or save >= options.ticks or save % ALIGNMENT ~= 0 then
            raise("every --save-ticks must be a multiple of %d below --ticks\n%s", ALIGNMENT, USAGE)
        end
    end
    return options
end

local function clone(options, source, directory)
    os.mkdir(directory)
    local status = os.execv("cp", {"-c", "-R", source, path.join(directory, "rootfs")}, {try = true})
    if status ~= 0 then
        raise("cannot clone %s into %s", source, directory)
    end
    if options.guest then
        local guest = path.join(directory, "rootfs") .. options.binary
        os.mkdir(path.directory(guest))
        os.cp(options.guest, guest)
        os.execv("chmod", {"755", guest})
    end
end

local function share_key_store(from, to)
    local key_store = path.join(to, ".emulator-device-state", "rootfs")
    os.mkdir(key_store)
    os.cp(path.join(from, ".emulator-device-state", "rootfs", "key-store-v1.key"), path.join(key_store, "key-store-v1.key"))
end

local function timing_of(file)
    local text = io.readfile(file) or ""
    local real, user, system = text:match("([%d%.]+) real%s+([%d%.]+) user%s+([%d%.]+) sys")
    if not real then
        raise("no timing in %s", file)
    end
    return {real = tonumber(real), cpu = tonumber(user) + tonumber(system)}
end

local function boot(options, directory, label, ticks, extra)
    local host_cache = path.join(directory, label .. "-host-cache")
    local tmp = path.join(directory, label .. "-tmp")
    local log = path.join(directory, label .. ".log")
    local timing = path.join(directory, label .. ".time")
    os.mkdir(host_cache)
    os.mkdir(tmp)
    local arguments = {"-l", "-o", timing, options.emulator, "boot", "--rootfs", path.join(directory, "rootfs"),
        "--device", "iPhone4,1", "--host-cache", host_cache, "--display", "headless", "--gles-backend", "software",
        "--time-scale", options.time_scale, "--ticks", tostring(ticks), "--verbose"}
    if options.binary then
        table.join2(arguments, {"--binary", options.binary})
    end
    if options.ios_build then
        table.join2(arguments, {"--ios-build", options.ios_build})
    end
    for _, argument in ipairs(extra) do
        arguments[#arguments + 1] = argument
    end
    local status = os.execv("/usr/bin/time", arguments, {try = true, curdir = directory,
        envs = {TMPDIR = tmp}, stdout = log, stderr = log .. ".err"})
    if status ~= 0 then
        local reason = io.readfile(log .. ".err") or ""
        raise("%s exited with %s running %s in %s, see %s and %s\n%s", label, tostring(status),
            options.emulator, directory, log, log .. ".err", reason:sub(-4000))
    end
    return log, timing_of(timing)
end

local function require_marker(log, marker)
    local text = io.readfile(log)
    if not text:find(marker, 1, true) then
        raise("%s has no %s line", log, marker)
    end
end

local function compare(cold, restored, report)
    local cold_bytes = io.readfile(cold, {encoding = "binary"})
    local restored_bytes = io.readfile(restored, {encoding = "binary"})
    local difference = snapshot.first_difference(cold_bytes, restored_bytes)
    if difference then
        local text = snapshot.describe(difference)
        io.writefile(report, text .. "\n", {encoding = "binary"})
        raise("cold and restored snapshots differ in %s, see %s: %s",
            difference.kind == "size" and "size" or "content", report, text)
    end
    return #cold_bytes
end

local function row(label, ticks, timing)
    return string.format("| %s | %d | %.1f | %.1f |", label, ticks, timing.real, timing.cpu)
end

local function save_round_trip(options, base, base_timing, cold_snapshot, index, save_tick, rows)
    local save = path.join(options.work, "save-" .. save_tick)
    local save_snapshot = path.join(save, "session.snap")
    local save_timing = base_timing
    if index > 1 then
        clone(options, options.rootfs, save)
        share_key_store(base, save)
        local save_log
        save_log, save_timing = boot(options, save, "save-" .. save_tick, save_tick,
            {"--snapshot-out", save_snapshot})
        require_marker(save_log, "[snapshot] written")
    end
    table.insert(rows, row("save, 0 to " .. save_tick, save_tick, save_timing))

    local restore = path.join(options.work, "restore-" .. save_tick)
    clone(options, options.rootfs, restore)
    share_key_store(base, restore)
    local restored_snapshot = path.join(restore, "restored.snap")
    local restore_log, restore_timing = boot(options, restore, "restore-" .. save_tick, options.ticks,
        {"--snapshot-in", save_snapshot, "--snapshot-out", restored_snapshot})
    require_marker(restore_log, "[snapshot] restored")
    require_marker(restore_log, "[snapshot] written")
    table.insert(rows, row("restored, " .. save_tick .. " to --ticks", options.ticks - save_tick, restore_timing))

    local size = compare(cold_snapshot, restored_snapshot, path.join(options.work, "compare-" .. save_tick .. ".txt"))
    print(string.format("round trip: save at %d, cold and restored snapshots at %d are identical, %d bytes",
        save_tick, options.ticks, size))
end

local function round_trips(options, rows, failures)
    local first_tick = options.save_ticks[1]
    local base = path.join(options.work, "save-" .. first_tick)
    clone(options, options.rootfs, base)
    local base_log, base_timing = boot(options, base, "save-" .. first_tick, first_tick,
        {"--snapshot-out", path.join(base, "session.snap")})
    require_marker(base_log, "[snapshot] written")

    local cold = path.join(options.work, "cold")
    clone(options, options.rootfs, cold)
    share_key_store(base, cold)
    local cold_snapshot = path.join(cold, "cold.snap")
    local cold_log, cold_timing = boot(options, cold, "cold", options.ticks, {"--snapshot-out", cold_snapshot})
    require_marker(cold_log, "[snapshot] written")
    table.insert(rows, row("cold, 0 to --ticks", options.ticks, cold_timing))

    for index, save_tick in ipairs(options.save_ticks) do
        try {
            function ()
                save_round_trip(options, base, base_timing, cold_snapshot, index, save_tick, rows)
            end,
            catch {
                function (errors)
                    table.insert(failures, string.format("save at %d: %s", save_tick, tostring(errors)))
                end
            }
        }
    end
end

function main(...)
    local options = parse(...)
    if not options then
        return
    end
    if not options.rootfs then
        print("skipped: pass --rootfs DIR, a root filesystem to boot")
        return
    end
    if not os.isfile(options.emulator) then
        raise("no emulator at %s, build it with ./xmakew build emulator", options.emulator)
    end
    if not os.isdir(options.rootfs) then
        raise("no root filesystem at %s", options.rootfs)
    end
    if options.guest and not os.isfile(options.guest) then
        raise("no guest at %s, build it first", options.guest)
    end
    if options.binary and not options.guest and not os.isfile(options.rootfs .. options.binary) then
        raise("%s has no guest binary %s", options.rootfs, options.binary)
    end

    local work = options.work
    if os.isdir(work) then
        os.execv("chmod", {"-R", "u+w", work}, {try = true})
        os.rm(work)
    end
    os.mkdir(work)

    local rows = {
        "| run | ticks | real s | cpu s |",
        "|---|---|---|---|",
    }
    local failures = {}
    try {
        function ()
            round_trips(options, rows, failures)
        end,
        catch {
            function (errors)
                table.insert(failures, tostring(errors))
            end
        }
    }
    print("")
    for _, line in ipairs(rows) do
        print(line)
    end
    if #failures > 0 then
        raise("%d round trip failure(s):\n%s", #failures, table.concat(failures, "\n"))
    end
end
