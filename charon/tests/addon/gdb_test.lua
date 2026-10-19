import("fixtures")

local function word_of(value)
    local held = ""
    for shift = 0, 24, 8 do
        held = held .. string.format("%02x", (value >> shift) & 0xff)
    end
    return held
end

function failures(opt)
    local gdb = import("gdb", {rootdir = opt.modules, anonymous = true})
    local found = {}

    -- The registers come as one run of little endian words in the order they
    -- are named, and an error where the guest cannot be read is not a register.
    local answer = ""
    for index = 1, 17 do
        answer = answer .. word_of(index == 16 and 0x3314dfe8 or index * 0x10)
    end
    local held = gdb.decode(answer)
    if not held or held.r0 ~= 0x10 or held.r7 ~= 0x80 or held.pc ~= 0x3314dfe8 or held.cpsr ~= 0x110 then
        table.insert(found, "the registers are read in the order they are named, and were read as " ..
                            (held and string.format("r0=0x%x r7=0x%x pc=0x%x", held.r0, held.r7, held.pc) or "nothing"))
    end
    if gdb.decode("E01") ~= nil or gdb.decode(nil) ~= nil then
        table.insert(found, "a guest that cannot be read has no registers")
    end

    -- iOS keeps the frame pointer in r7, and a frame holds the one before it
    -- and where to return to, so the stack is a chain until a frame does not
    -- read - which is where the walk stops rather than inventing a caller.
    local memory = {[0x1000] = 0x1020, [0x1004] = 0xaaaa, [0x1020] = 0x1040, [0x1024] = 0xbbbb, [0x1040] = 0, [0x1044] = 0xcccc}
    local walked = gdb.chain(function (address) return memory[address] end, {pc = 0x1111, lr = 0x2222, r7 = 0x1000})
    local told = {}
    for _, frame in ipairs(walked) do
        table.insert(told, string.format("%s:0x%x", frame.kind, frame.address))
    end
    if table.concat(told, " ") ~= "pc:0x1111 lr:0x2222 return:0xaaaa return:0xbbbb return:0xcccc" then
        table.insert(found, "the frames are the chain r7 holds: " .. table.concat(told, " "))
    end
    local looping = {[0x2000] = 0x2000, [0x2004] = 0xdddd}
    walked = gdb.chain(function (address) return looping[address] end, {pc = 1, lr = 2, r7 = 0x2000})
    if #walked ~= 3 then
        table.insert(found, string.format("a frame that points at itself ends the walk, not %d frames", #walked))
    end
    walked = gdb.chain(function () return nil end, {pc = 1, lr = 2, r7 = 0x3000})
    if #walked ~= 2 then
        table.insert(found, "a frame that cannot be read ends the walk after the registers")
    end
    return found
end
