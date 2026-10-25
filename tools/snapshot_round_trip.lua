-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local ALIGNMENT = 1048576

local USAGE = [[usage: ./xmakew l tools/snapshot_round_trip.lua --rootfs DIR [--emulator EMU] [--binary GUEST]
                                                             [--save-ticks N] [--ticks N] [--time-scale S]
                                                             [--work DIR]

Saves a snapshot at --save-ticks, boots the save's clone cold to --ticks, restores the saved
snapshot on a second clone to --ticks, and requires the cold and restored snapshots to be
identical. The save and the cold run share one clone and so one device key store: the key
store is random per device state, and the clone's dyld shared cache ctime is guest-visible,
so two clones of the same rootfs would not match byte for byte. Without --binary the guest
boots launchd. The check is skipped without --rootfs. --save-ticks and --ticks must be
multiples of 2^20 and --save-ticks below --ticks. Clones use cp -c, so this runs on macOS.]]

local flags = {
    ["--emulator"] = "emulator",
    ["--rootfs"] = "rootfs",
    ["--binary"] = "binary",
    ["--work"] = "work",
    ["--save-ticks"] = "save_ticks",
    ["--ticks"] = "ticks",
    ["--time-scale"] = "time_scale",
}

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
    options.save_ticks = tonumber(options.save_ticks)
    options.ticks = tonumber(options.ticks)
    if not tonumber(options.time_scale) then
        raise("--time-scale must be a number\n" .. USAGE)
    end
    if not options.save_ticks or not options.ticks or options.save_ticks <= 0 or
        options.save_ticks >= options.ticks or options.save_ticks % ALIGNMENT ~= 0 or
        options.ticks % ALIGNMENT ~= 0 then
        raise("--save-ticks and --ticks must be multiples of %d with --save-ticks below --ticks", ALIGNMENT)
    end
    return options
end

local function clone(source, directory)
    os.mkdir(directory)
    local status = os.execv("cp", {"-c", "-R", source, path.join(directory, "rootfs")}, {try = true})
    if status ~= 0 then
        raise("cannot clone %s into %s", source, directory)
    end
end

local function boot(options, directory, label, ticks, extra)
    local host_cache = path.join(directory, label .. "-host-cache")
    local tmp = path.join(directory, label .. "-tmp")
    local log = path.join(directory, label .. ".log")
    os.mkdir(host_cache)
    os.mkdir(tmp)
    local arguments = {"boot", "--rootfs", path.join(directory, "rootfs"), "--device", "iPhone4,1",
        "--host-cache", host_cache, "--display", "headless", "--gles-backend", "software",
        "--time-scale", options.time_scale, "--ticks", tostring(ticks), "--verbose"}
    if options.binary then
        table.join2(arguments, {"--binary", options.binary})
    end
    for _, argument in ipairs(extra) do
        arguments[#arguments + 1] = argument
    end
    local status = os.execv(options.emulator, arguments, {try = true, curdir = directory,
        envs = {TMPDIR = tmp}, stdout = log, stderr = log .. ".err"})
    if status ~= 0 then
        raise("%s exited with %s, see %s", label, tostring(status), log)
    end
    return log
end

local function require_marker(log, marker)
    local text = io.readfile(log)
    if not text:find(marker, 1, true) then
        raise("%s has no %s line", log, marker)
    end
end

local function compare(cold, restored)
    local left = io.readfile(cold)
    local right = io.readfile(restored)
    if #left ~= #right then
        raise("cold snapshot is %d bytes, restored is %d", #left, #right)
    end
    local differing, first = 0, nil
    for index = 1, #left do
        if string.byte(left, index) ~= string.byte(right, index) then
            differing = differing + 1
            first = first or (index - 1)
        end
    end
    if differing > 0 then
        raise("cold and restored snapshots differ in %d bytes, first at offset %d", differing, first)
    end
    print(string.format("round trip: cold and restored snapshots are identical, %d bytes", #left))
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
    if options.binary and not os.isfile(options.rootfs .. options.binary) then
        raise("%s has no guest binary %s", options.rootfs, options.binary)
    end

    local work = options.work
    if os.isdir(work) then
        os.execv("chmod", {"-R", "u+w", work}, {try = true})
        os.rm(work)
    end
    os.mkdir(work)

    local save = path.join(work, "save")
    clone(options.rootfs, save)
    local save_snapshot = path.join(save, "session.snap")
    boot(options, save, "save", options.save_ticks, {"--snapshot-out", save_snapshot})
    require_marker(path.join(save, "save.log"), "[snapshot] written")

    local cold_snapshot = path.join(save, "cold.snap")
    local cold_log = boot(options, save, "cold", options.ticks, {"--snapshot-out", cold_snapshot})
    require_marker(cold_log, "[snapshot] written")

    local restore = path.join(work, "restore")
    clone(options.rootfs, restore)
    local key_store = path.join(restore, ".emulator-device-state", "rootfs")
    os.mkdir(key_store)
    os.cp(path.join(save, ".emulator-device-state", "rootfs", "key-store-v1.key"), path.join(key_store, "key-store-v1.key"))
    local restored_snapshot = path.join(restore, "restored.snap")
    local restore_log = boot(options, restore, "restore", options.ticks,
        {"--snapshot-in", save_snapshot, "--snapshot-out", restored_snapshot})
    require_marker(restore_log, "[snapshot] restored")
    require_marker(restore_log, "[snapshot] written")

    compare(cold_snapshot, restored_snapshot)
end
