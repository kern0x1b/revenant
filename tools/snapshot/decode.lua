-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local MAGIC = "REVSNAP\0"
local BOOL = "<I1"
local U32 = "<I4"
local U64 = "<I8"
local DIGEST_SIZE = 32

local LOOP_THREADS = {"last_serial_thread", "scheduler_handoff_thread", "display_urgent_thread",
    "display_urgent_receiver_thread", "display_yielded_thread"}
local LOOP_COUNTERS = {"display_inflight_callback_sequence", "diagnostic_display_yield_count", "remaining_ticks",
    "executed_ticks", "executed_ticks_since_catch_up", "interaction_generation"}
local SCHEDULER_SCALARS = {
    {"quantum_ticks", U64}, {"tick_ticks", U64}, {"processor_count", U64}, {"elapsed_since_tick", U64},
    {"elapsed_ticks", U64}, {"realtime_clock_ticks", U64}, {"external_realtime_clock", BOOL},
    {"tick", U64}, {"next_enqueue_sequence", U64}, {"runnable_count", U64}, {"waiting_count", U64},
    {"active_timeshare_count", U64},
}

local function new_reader(bytes)
    local reader = {data = bytes, position = 1, fields = {}}

    function reader:take(size, name)
        local last = self.position + size - 1
        if last > #self.data then
            raise("snapshot ends inside %s: it needs %d bytes at offset %d of %d", name, size, self.position - 1, #self.data)
        end
        local value = self.data:sub(self.position, last)
        self.position = last + 1
        return value
    end

    function reader:record(owner, name, kind, offset, size, value)
        table.insert(self.fields, {name = owner .. "." .. name, owner = owner, field = name, kind = kind,
            offset = offset, size = size, value = value})
    end

    function reader:number(owner, name, format)
        local offset = self.position - 1
        local size = string.packsize(format)
        local value = string.unpack(format, self:take(size, owner .. "." .. name))
        self:record(owner, name, "number", offset, size, value)
        return value
    end

    function reader:bytes(owner, name, size)
        local offset = self.position - 1
        local value = self:take(size, owner .. "." .. name)
        self:record(owner, name, "bytes", offset, size, value)
        return value
    end

    function reader:text(owner, name)
        local offset = self.position - 1
        local length = string.unpack(U64, self:take(8, owner .. "." .. name .. " length"))
        local value = self:take(length, owner .. "." .. name)
        self:record(owner, name, "text", offset, self.position - 1 - offset, value)
        return value
    end

    return reader
end

local function header(reader)
    local magic = reader:bytes("header", "magic", #MAGIC)
    if magic ~= MAGIC then
        raise("not a session snapshot: it starts with %q, not %q", magic, MAGIC)
    end
    reader:number("header", "version", U32)
    reader:text("header", "device")
    reader:text("header", "binary")
    reader:number("header", "ticks", U64)
    reader:bytes("header", "rootfs_manifest", DIGEST_SIZE)
    return reader:number("header", "body_size", U64)
end

local function optional_thread(reader, name)
    if reader:number("loop", name .. ".present", BOOL) ~= 0 then
        reader:number("loop", name .. ".process", U32)
        reader:number("loop", name .. ".thread", U32)
    end
end

local function body(reader)
    for _, name in ipairs(LOOP_THREADS) do
        optional_thread(reader, name)
    end
    for _, name in ipairs(LOOP_COUNTERS) do
        reader:number("loop", name, U64)
    end
    if reader:number("loop", "input_receiver_process.present", BOOL) ~= 0 then
        reader:number("loop", "input_receiver_process", U32)
    end
    for _, scalar in ipairs(SCHEDULER_SCALARS) do
        reader:number("scheduler", scalar[1], scalar[2])
    end
    reader:number("scheduler", "thread_count", U64)
end

function decode(bytes)
    local reader = new_reader(bytes)
    local body_size = header(reader)
    local remaining = #bytes - (reader.position - 1)
    if remaining ~= body_size then
        raise("snapshot body is %d bytes, its header says %d", remaining, body_size)
    end
    body(reader)
    return {fields = reader.fields, decoded_end = reader.position - 1}
end

local function show(field)
    if field.kind == "bytes" then
        return (field.value:gsub(".", function (character)
            return string.format("%02x", character:byte())
        end))
    end
    if field.kind == "text" then
        return string.format("%q", field.value)
    end
    return string.format("%d", field.value)
end

function first_difference(cold, restored)
    local left = decode(cold)
    local right = decode(restored)
    for index = 1, math.max(#left.fields, #right.fields) do
        local a, b = left.fields[index], right.fields[index]
        if not a or not b or a.name ~= b.name then
            return {kind = "layout", index = index, cold = a and a.name or "end of snapshot",
                restored = b and b.name or "end of snapshot"}
        end
        if a.value ~= b.value then
            return {kind = "field", owner = a.owner, field = a.field, offset = a.offset, size = a.size,
                cold = show(a), restored = show(b)}
        end
    end
    for position = left.decoded_end + 1, math.min(#cold, #restored) do
        if cold:byte(position) ~= restored:byte(position) then
            local last = left.fields[#left.fields]
            return {kind = "undecoded", offset = position - 1, after = last.name,
                cold = string.format("%02x", cold:byte(position)), restored = string.format("%02x", restored:byte(position))}
        end
    end
    if #cold ~= #restored then
        return {kind = "size", cold = #cold, restored = #restored}
    end
    return nil
end

function describe(difference)
    if difference.kind == "field" then
        return string.format("owner %s, field %s, file offset %d (%d bytes): cold %s, restored %s",
            difference.owner, difference.field, difference.offset, difference.size, difference.cold, difference.restored)
    end
    if difference.kind == "undecoded" then
        return string.format("no decoded field differs; the first differing byte is at file offset %d, after %s, "
            .. "in the part the decoder does not walk (scheduler thread records, next pid, allocations, memory, "
            .. "CPUs and kernel): cold 0x%s, restored 0x%s",
            difference.offset, difference.after, difference.cold, difference.restored)
    end
    if difference.kind == "size" then
        return string.format("the snapshots have different sizes: cold %d bytes, restored %d bytes",
            difference.cold, difference.restored)
    end
    return string.format("the snapshots lay out their fields differently at field %d: cold has %s, restored has %s",
        difference.index, difference.cold, difference.restored)
end
