-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local snapshot = import("snapshot.decode", {rootdir = os.scriptdir()})

local HEADER_BYTES = 8 + 4 + (8 + 9) + (8 + 29) + 8 + 32 + 8
local ELAPSED_TICKS_OFFSET = 5 + 6 * 8 + 1 + 8 + 4 * 8

local function u32(value)
    return string.pack("<I4", value)
end

local function u64(value)
    return string.pack("<I8", value)
end

local function flag(value)
    return string.char(value and 1 or 0)
end

local function text(value)
    return u64(#value) .. value
end

local DEFAULT_SCHEDULER = {quantum = 4096, tick_ticks = 65536, processors = 1, elapsed_since_tick = 17,
    elapsed_ticks = 1048581, realtime = 1048581, external = true, tick = 3, next_enqueue = 9, runnable = 1,
    waiting = 0, active = 0}

local function snapshot_bytes(overrides)
    local scheduler = {}
    for name, value in pairs(DEFAULT_SCHEDULER) do
        scheduler[name] = value
    end
    for name, value in pairs(overrides or {}) do
        scheduler[name] = value
    end
    local remainder = overrides and overrides.remainder or 0
    local body = table.concat({
        flag(false), flag(false), flag(false), flag(false), flag(false),
        u64(0), u64(0), u64(1048576), u64(1048576), u64(1048576), u64(1),
        flag(false),
        u64(remainder),
        u64(scheduler.quantum), u64(scheduler.tick_ticks), u64(scheduler.processors),
        u64(scheduler.elapsed_since_tick), u64(scheduler.elapsed_ticks), u64(scheduler.realtime),
        flag(scheduler.external), u64(scheduler.tick), u64(scheduler.next_enqueue),
        u64(scheduler.runnable), u64(scheduler.waiting), u64(scheduler.active),
        u64(0),
        "trailing bytes that the decoder does not walk",
    })
    return table.concat({"REVSNAP\0", u32(1), text("iPhone4,1"), text("/usr/libexec/emulator-minimal"),
        u64(1048576), string.rep("\0", 32), u64(#body), body})
end

local function expect(condition, message)
    if not condition then
        raise("snapshot diff test failed: %s", message)
    end
end

local function test_identical()
    local cold = snapshot_bytes()
    expect(snapshot.first_difference(cold, snapshot_bytes()) == nil, "identical snapshots must not differ")
end

local function test_named_scheduler_field()
    local cold = snapshot_bytes()
    local restored = snapshot_bytes({elapsed_ticks = 1048584})
    local difference = snapshot.first_difference(cold, restored)
    expect(difference and difference.kind == "field", "a changed scheduler field must be reported as a field")
    expect(difference.owner == "scheduler" and difference.field == "elapsed_ticks",
        "the owner and field must name scheduler.elapsed_ticks, not " .. tostring(difference.owner)
        .. "." .. tostring(difference.field))
    expect(difference.offset == HEADER_BYTES + ELAPSED_TICKS_OFFSET,
        "the offset must be the file offset of elapsed_ticks, not " .. tostring(difference.offset))
    expect(difference.cold == "1048581" and difference.restored == "1048584",
        "the values must be the cold and restored elapsed ticks")
    expect(snapshot.describe(difference):find("elapsed_ticks", 1, true), "the description must name the field")
end

local function test_named_realtime_field()
    local cold = snapshot_bytes()
    local restored = snapshot_bytes({realtime = 1048600})
    local difference = snapshot.first_difference(cold, restored)
    expect(difference and difference.field == "realtime_clock_ticks",
        "a changed realtime clock must name scheduler.realtime_clock_ticks")
end

local function test_named_remainder_field()
    local cold = snapshot_bytes()
    local restored = snapshot_bytes({remainder = 200000000})
    local difference = snapshot.first_difference(cold, restored)
    expect(difference and difference.owner == "loop" and difference.field == "guest_time_remainder",
        "a changed guest time remainder must name loop.guest_time_remainder")
end

local function test_undecoded_tail()
    local cold = snapshot_bytes()
    local restored = cold:sub(1, -2) .. "Z"
    local difference = snapshot.first_difference(cold, restored)
    expect(difference and difference.kind == "undecoded", "a changed trailing byte must be reported as undecoded")
    expect(difference.offset == #cold - 1, "the undecoded offset must be the last byte")
    expect(difference.after == "scheduler.thread_count", "the undecoded region must follow scheduler.thread_count")
end

local function test_not_a_snapshot()
    local decoded = false
    try {
        function ()
            snapshot.decode("NOTSNAP" .. string.rep("\0", 200))
            decoded = true
        end,
        catch {
            function () end
        }
    }
    expect(not decoded, "a file without the snapshot magic must not decode")
end

function main(command)
    if command ~= "test" then
        raise("usage: ./xmakew l tools/snapshot_diff.lua test")
    end
    test_identical()
    test_named_scheduler_field()
    test_named_realtime_field()
    test_named_remainder_field()
    test_undecoded_tail()
    test_not_a_snapshot()
    print("snapshot diff: 6 decoder tests passed")
end
