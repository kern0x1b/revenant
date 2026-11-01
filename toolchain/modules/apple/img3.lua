local HEADER = 20
local ELEMENT = 12
local MAGIC = "3gmI"

function data(bytes)
    if bytes:sub(1, 4) ~= MAGIC then
        raise("the bytes are not an IMG3 container (they start %q)", bytes:sub(1, 4))
    end
    local at = HEADER + 1
    while at + ELEMENT - 1 <= #bytes do
        local tag, total, size = string.unpack("<c4I4I4", bytes, at)
        if total < ELEMENT or at + total - 1 > #bytes then
            raise("an IMG3 element at offset %d claims %d bytes, which the file does not hold", at - 1, total)
        end
        if tag == "ATAD" then
            if size > total - ELEMENT then
                raise("the IMG3 DATA element claims %d bytes in a payload of %d", size, total - ELEMENT)
            end
            return bytes:sub(at + ELEMENT, at + total - 1), size
        end
        at = at + total
    end
    raise("the IMG3 container holds no DATA element")
end

function decrypt(payload, key, iv)
    if not (key:match("^%x+$") and (#key == 32 or #key == 64)) then
        raise("the key is %d hex digits, and an AES key is 32 or 64", #key)
    end
    if not iv:match("^%x+$") or #iv ~= 32 then
        raise("the IV is %d hex digits, and an AES-CBC IV is 32", #iv)
    end
    if #payload % 16 ~= 0 then
        raise("the payload is %d bytes, which is not a whole number of AES blocks", #payload)
    end
    local input, output = os.tmpfile(), os.tmpfile()
    io.writefile(input, payload, {encoding = "binary"})
    os.vrunv("openssl", {"enc", "-d", "-aes-" .. (#key * 4) .. "-cbc", "-K", key, "-iv", iv, "-nopad", "-in", input, "-out", output})
    local plain = io.readfile(output, {encoding = "binary"})
    os.tryrm(input)
    os.tryrm(output)
    return plain
end
