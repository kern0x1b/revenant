local bigint = import("bigint", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "..", "modules", "gyb"), anonymous = true})

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local ORDER_HEX = "FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC63FF51"

local function b64u_decode(text)
    local standard = text:gsub("%-", "+"):gsub("_", "/")
    standard = standard .. string.rep("=", (-#standard) % 4)
    local index = {}
    for i = 1, 64 do
        index[ALPHABET:byte(i)] = i - 1
    end
    local out, bits, count = {}, 0, 0
    for i = 1, #standard do
        local byte = standard:byte(i)
        if byte == 61 then
            break
        end
        local value = index[byte]
        if value == nil then
            raise("not base64url: " .. standard)
        end
        bits = ((bits << 6) | value) & 0xFFFFFF
        count = count + 6
        if count >= 8 then
            count = count - 8
            table.insert(out, string.char((bits >> count) & 0xFF))
        end
    end
    return table.concat(out)
end

local function hex_of(bytes)
    return (bytes:gsub(".", function(c)
        return string.format("%02X", c:byte())
    end))
end

local function der_int(value)
    local start = 1
    while start <= #value and value:byte(start) == 0 do
        start = start + 1
    end
    local body = value:sub(start)
    if body == "" then
        body = "\0"
    end
    if (body:byte(1) & 0x80) ~= 0 then
        body = "\0" .. body
    end
    return string.char(0x02, #body) .. body
end

local function quoted(path_text)
    return "'" .. path_text .. "'"
end

local function capture(work, command)
    local file = path.join(work, "openssl.out")
    os.execv("/bin/sh", {"-c", command .. " > " .. quoted(file) .. " 2>&1"}, {try = true})
    return io.readfile(file, {encoding = "binary"})
end

function main(work)
    local parts = {}
    for i = 0, 2 do
        table.insert(parts, io.readfile(path.join(work, "part" .. i .. ".txt"), {encoding = "binary"}):trim())
    end
    if #parts ~= 3 or parts[1] == "nil" then
        print("FAIL: mint returned no token")
        os.exit(1)
    end
    local header = b64u_decode(parts[1])
    local payload = b64u_decode(parts[2])
    local signature = b64u_decode(parts[3])
    print("header  : " .. header)
    print("payload : " .. payload)
    print("signature bytes: " .. #signature .. " (JOSE ES256 is the raw r || s, 64)")
    if #signature ~= 64 then
        print("FAIL: the signature part is not the raw pair")
        os.exit(1)
    end
    local s = bigint.parse(hex_of(signature:sub(33)), 16)
    local half = bigint.shr(bigint.parse(ORDER_HEX, 16), 1)
    if bigint.cmp(s, half) > 0 then
        print("FAIL: the signature is not low-s")
        os.exit(1)
    end
    local inner = der_int(signature:sub(1, 32)) .. der_int(signature:sub(33))
    io.writefile(path.join(work, "sig.der"), string.char(0x30, #inner) .. inner, {encoding = "binary"})
    io.writefile(path.join(work, "signing.txt"), parts[1] .. "." .. parts[2], {encoding = "binary"})
    local key = quoted(path.join(work, "key.pem"))
    local pub = quoted(path.join(work, "pub.pem"))
    capture(work, "openssl ec -in " .. key .. " -pubout -out " .. pub)
    local verified = capture(work, "openssl dgst -sha256 -verify " .. pub .. " -signature " .. quoted(path.join(work, "sig.der")) .. " " .. quoted(path.join(work, "signing.txt")))
    local line = verified:trim()
    print("OpenSSL  : " .. line)
    if not line:find("Verified OK", 1, true) then
        os.exit(1)
    end
end
