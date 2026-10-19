import("core.base.socket")
import("core.base.bytes")

-- The emulator answers a debugger on a port with the protocol gdb speaks:
-- $<body>#<checksum of the body>, acknowledged with +. What charon asks of it
-- is small - where the guest stopped, its registers, the memory it can read -
-- and it asks it itself, because no debugger on an arm64 host talks to an
-- armv7 guest.
local function checksum(body)
    local total = 0
    for index = 1, #body do
        total = (total + body:byte(index)) % 256
    end
    return string.format("%02x", total)
end

-- The emulator opens the port as it starts, so a connection made a moment too
-- early is accepted by nothing and dies unread: the debugger is connected when
-- it has asked where the guest stopped and been answered, and not before.
function connect(port, opt)
    opt = opt or {}
    local deadline = os.mclock() + (opt.patience or 60) * 1000
    while true do
        local sock = socket.connect("127.0.0.1", port, {timeout = 1000})
        if sock then
            local connection = {sock = sock, held = "", buffer = bytes(65536), timeout = (opt.timeout or 300) * 1000, greeting = nil}
            connection.greeting = ask(connection, "?")
            if connection.greeting then
                return connection
            end
            sock:close()
        end
        if os.mclock() > deadline then
            raise("nothing answered the debugger on port %d after %d seconds", port, opt.patience or 60)
        end
    end
end

function close(connection)
    connection.sock:close()
end

local function receive(connection)
    while true do
        local packet = connection.held:match("^%+*%$(.-)#%x%x")
        if packet then
            connection.held = connection.held:gsub("^%+*%$.-#%x%x", "", 1)
            connection.sock:send("+", {block = true})
            return packet
        end
        local count, data = connection.sock:recv(connection.buffer, 65536, {block = false})
        if count and count > 0 then
            connection.held = connection.held .. data:str()
        elseif count == 0 then
            if connection.sock:wait(socket.EV_RECV, connection.timeout) ~= socket.EV_RECV then
                return nil
            end
        else
            return nil
        end
    end
end

function ask(connection, body)
    if connection.sock:send("$" .. body .. "#" .. checksum(body), {block = true}) < 0 then
        return nil
    end
    return receive(connection)
end

-- Sixteen registers and the flags, little endian, as the stub lays them out.
NAMES = {"r0", "r1", "r2", "r3", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12", "sp", "lr", "pc", "cpsr"}

-- The stub answers with the registers as one run of little endian words, and
-- what they are called is the order they come in.
function decode(answer)
    if not answer or answer:startswith("E") then
        return nil
    end
    local held = {}
    for index = 0, #answer // 8 - 1 do
        local word = answer:sub(index * 8 + 1, index * 8 + 8)
        held[index + 1] = tonumber(word:sub(7, 8) .. word:sub(5, 6) .. word:sub(3, 4) .. word:sub(1, 2), 16)
    end
    local named = {}
    for index, name in ipairs(NAMES) do
        named[name] = held[index]
    end
    named.held = held
    return named
end

function registers(connection)
    return decode(ask(connection, "g"))
end

function memory(connection, address, count)
    local answer = ask(connection, string.format("m%x,%x", address, count))
    if not answer or answer:startswith("E") or #answer < count * 2 then
        return nil
    end
    local raw = {}
    for index = 0, count - 1 do
        table.insert(raw, string.char(tonumber(answer:sub(index * 2 + 1, index * 2 + 2), 16)))
    end
    return table.concat(raw)
end

function word(connection, address)
    local raw = memory(connection, address, 4)
    return raw and string.unpack("<I4", raw) or nil
end

function text(connection, address, limit)
    local held = ""
    while #held < (limit or 256) do
        local raw = memory(connection, address + #held, 32)
        if not raw then
            break
        end
        held = held .. raw
        if held:find("%z") then
            break
        end
    end
    return (held:match("^([^%z]*)")) or ""
end

-- Where the guest is and how it got there. iOS keeps the frame pointer in r7
-- and a frame holds the one before it and the address to return to, so the
-- stack is walked by reading pairs of words until one does not read.
function chain(reader, held, limit)
    local walked = {{kind = "pc", address = held.pc}, {kind = "lr", address = held.lr}}
    local pointer, seen = held.r7, {}
    for _ = 1, limit or 64 do
        if not pointer or pointer == 0 or seen[pointer] then
            break
        end
        seen[pointer] = true
        local previous, returned = reader(pointer), reader(pointer + 4)
        if not previous or not returned or returned == 0 then
            break
        end
        table.insert(walked, {kind = "return", address = returned, frame = pointer})
        pointer = previous
    end
    return walked
end

function frames(connection, held, limit)
    return chain(function (address) return word(connection, address) end, held, limit)
end
