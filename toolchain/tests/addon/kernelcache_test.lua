import("fixtures")

local KEY = "a374109c958957200f879f7b6ef34437fbde1a9f178b7c2412755cf9a3ed2d72"
local IV = "8a2c03ef8a0e45947780cdde01be40fb"
local OTHER_KEY = string.rep("11", 32)
local MACH_O = "\206\250\237\254"

local function literals(plain)
    local parts = {}
    for first = 1, #plain, 8 do
        local chunk = plain:sub(first, first + 7)
        table.insert(parts, string.char((1 << #chunk) - 1) .. chunk)
    end
    return table.concat(parts)
end

local function container(complzss, plain, stream)
    local header = "complzss" .. string.pack(">I4I4I4I4", complzss.adler32(plain), #plain, #stream, 1)
    return header .. string.rep("\0", 384 - #header) .. stream
end

local function openssl(mode, key, input, output)
    os.vrunv("openssl", {"enc", mode, "-aes-256-cbc", "-K", key, "-iv", IV, "-nopad", "-in", input, "-out", output})
end

local function encrypt(bytes, key)
    local padded = bytes .. string.rep("\0", (16 - #bytes % 16) % 16)
    local input, output = os.tmpfile(), os.tmpfile()
    io.writefile(input, padded, {encoding = "binary"})
    openssl("-e", key, input, output)
    local encrypted = io.readfile(output, {encoding = "binary"})
    os.tryrm(input)
    os.tryrm(output)
    return encrypted
end

local function img3(encrypted, size)
    local total = 20 + 32 + 12 + #encrypted
    return "3gmI" .. string.pack("<I4I4I4", total, total - 20, 0) .. "krnl"
        .. string.pack("<c4I4I4", "EPYT", 32, 4) .. "krnl" .. string.rep("\0", 16)
        .. string.pack("<c4I4I4", "ATAD", 12 + #encrypted, size) .. encrypted
end

function failures(opt)
    local found = {}
    local firmware = import("apple.firmware", {rootdir = opt.modules, anonymous = true})
    local complzss = import("apple.complzss", {rootdir = opt.modules, anonymous = true})
    local img3_format = import("apple.img3", {rootdir = opt.modules, anonymous = true})
    local folder = fixtures.scratch()

    if complzss.adler32("Wikipedia") ~= 0x11E60398 then
        table.insert(found, "the Adler-32 of Wikipedia is not 0x11E60398")
    end

    local page = "{{Keys\n | Kernelcache         = kernelcache.release.n94\n | KernelcacheIV       = " .. IV ..
                 "\n | KernelcacheKey      = " .. KEY .. "\n}}"
    local key, iv = firmware.kernelcache_keys_in(page, "kernelcache.release.n94")
    if key ~= KEY or iv ~= IV then
        table.insert(found, "the Keys page of a kernelcache yields its key and IV")
    end
    if firmware.kernelcache_keys_in(page, "kernelcache.release.s5l8950x") ~= nil then
        table.insert(found, "a Keys page for another kernelcache yields no key")
    end
    if firmware.kernelcache_keys_in(page:gsub("KernelcacheIV.-\n", ""), "kernelcache.release.n94") ~= nil then
        table.insert(found, "a Keys page without an IV yields no key")
    end

    local stream = "\255ABCDEFGH" .. "\254\238\240" .. "xyzwvut"
    local expected = "ABCDEFGHABCxyzwvut"
    if complzss.unwrap(container(complzss, expected, stream)) ~= expected then
        table.insert(found, "a stream of literals and a match decodes to its plain bytes")
    end
    local varied = {}
    local state = 1
    for index = 1, 10000 do
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        varied[index] = string.char((state >> 16) & 0xFF)
    end
    local long = table.concat(varied)
    if complzss.unwrap(container(complzss, long, literals(long))) ~= long then
        table.insert(found, "10000 bytes that wrap the 4096-byte window decode back to themselves")
    end

    local refusals = {
        ["a container that is not complzss"] = "XXXXXXXX" .. string.rep("\0", 16) .. stream,
        ["a container with a wrong Adler-32"] = container(complzss, expected, stream):gsub("^complzss.", "complzss\1"),
        ["a stream that ends inside a match"] = container(complzss, expected, "\254\238"),
        ["a stream whose plain size is wrong"] = container(complzss, expected .. "!", stream),
        ["padding that is not zero"] = (container(complzss, expected, stream):gsub("\0", "\1", 1)),
    }
    for name, bytes in pairs(refusals) do
        if fixtures.refusal(function () complzss.unwrap(bytes) end) == nil then
            table.insert(found, name .. " is refused")
        end
    end

    local encrypted = encrypt(container(complzss, expected, stream), KEY)
    local payload, size = img3_format.data(img3(encrypted, #container(complzss, expected, stream)))
    if payload ~= encrypted or size ~= #container(complzss, expected, stream) then
        table.insert(found, "the DATA payload of an IMG3 is found with its unpadded size")
    end
    local decrypted = img3_format.decrypt(payload, KEY, IV):sub(1, size)
    if complzss.unwrap(decrypted) ~= expected then
        table.insert(found, "an IMG3 DATA payload decrypts with the published key and IV, then decompresses")
    end
    if fixtures.refusal(function () img3_format.data("not an IMG3 container") end) == nil then
        table.insert(found, "bytes that are not IMG3 are refused")
    end

    local plain_kernel = MACH_O .. string.rep("kernel", 40)
    local image = path.join(folder, "kernelcache.release.n94")
    local output = path.join(folder, "kernel.macho")
    local plain_container = container(complzss, plain_kernel, literals(plain_kernel))
    io.writefile(image, img3(encrypt(plain_container, KEY), #plain_container), {encoding = "binary"})
    firmware.decode_kernelcache(image, KEY, IV, output)
    if io.readfile(output, {encoding = "binary"}) ~= plain_kernel then
        table.insert(found, "decoding an IMG3 kernelcache writes the Mach-O kernel it holds")
    end

    os.tryrm(output)
    local refused = fixtures.refusal(function () firmware.decode_kernelcache(image, OTHER_KEY, IV, output) end)
    if refused == nil or os.isfile(output) or os.isfile(output .. ".partial") then
        table.insert(found, "a kernelcache decrypted with another key is refused, and no kernel is left: " .. tostring(refused))
    end

    os.tryrm(folder)
    return found
end
