-- complzss is the compression Apple wraps kernelcaches in. The container starts with a 24-byte header: the magic
-- "complzss", then the Adler-32 of the plain bytes, the plain size, the packed size and a version, all big-endian.
-- Zero padding follows, and the packed stream ends where the payload ends. The stream is the classic
-- LZSS: a 4096-byte window, first written at offset 4078 and filled with spaces, and flag bytes read least
-- significant bit first, where a set bit is a literal byte and a clear bit is a match. A match is two bytes: the low
-- twelve bits are the window offset, and the high nibble of the second byte is the length minus three.

local HEADER = 24
local WINDOW = 4096
local FILL = 0x20
local FIRST = WINDOW - 18
local CHUNK = 4096

function adler32(bytes)
    local byte = string.byte
    local a, b = 1, 0
    for first = 1, #bytes, CHUNK do
        for index = first, math.min(first + CHUNK - 1, #bytes) do
            a = a + byte(bytes, index)
            b = b + a
        end
        a, b = a % 65521, b % 65521
    end
    return (b << 16) | a
end

local function truncated()
    raise("the complzss stream ends inside a token")
end

local function lzss(source, plain_size)
    local byte = string.byte
    local window = {}
    for index = 0, WINDOW - 1 do
        window[index] = FILL
    end
    local at, total = FIRST, 0
    local buffer, count, parts = {}, 0, {}
    local function put(value)
        count = count + 1
        buffer[count] = value
        window[at] = value
        at = (at + 1) & (WINDOW - 1)
        total = total + 1
        if count == CHUNK then
            parts[#parts + 1] = string.char(table.unpack(buffer, 1, count))
            count = 0
        end
    end
    local pos, last = 1, #source
    local flags, bits = 0, 0
    while pos <= last do
        if bits == 0 then
            flags, bits, pos = byte(source, pos), 8, pos + 1
        end
        local literal = flags & 1 == 1
        flags, bits = flags >> 1, bits - 1
        if literal then
            if pos > last then
                truncated()
            end
            put(byte(source, pos))
            pos = pos + 1
        else
            if pos + 1 > last then
                truncated()
            end
            local low, high = byte(source, pos, pos + 1)
            pos = pos + 2
            local from = low | ((high & 0xF0) << 4)
            for step = 0, (high & 0x0F) + 2 do
                put(window[(from + step) & (WINDOW - 1)])
            end
        end
    end
    if count > 0 then
        parts[#parts + 1] = string.char(table.unpack(buffer, 1, count))
    end
    if total ~= plain_size then
        raise("the complzss stream decodes to %d bytes, not the %d its header names", total, plain_size)
    end
    return table.concat(parts)
end

-- unwrap returns the plain bytes of a complzss container, checked against its header.
function unwrap(bytes)
    if #bytes < HEADER or bytes:sub(1, 8) ~= "complzss" then
        raise("the bytes are not a complzss container (they start %q)", bytes:sub(1, 8))
    end
    local checksum, plain_size, packed_size, version = string.unpack(">I4I4I4I4", bytes, 9)
    if version ~= 1 then
        raise("the complzss container is version %d, and only version 1 is known", version)
    end
    if packed_size > #bytes - HEADER then
        raise("the complzss header names %d packed bytes, and the payload holds %d after its header", packed_size, #bytes - HEADER)
    end
    local first = #bytes - packed_size + 1
    if bytes:sub(HEADER + 1, first - 1):find("[^\0]") then
        raise("the bytes between the complzss header and its stream are not zero padding")
    end
    local plain = lzss(bytes:sub(first), plain_size)
    if adler32(plain) ~= checksum then
        raise("the complzss stream does not match the Adler-32 in its header")
    end
    return plain
end
