local modules = path.join(os.scriptdir(), "..", "..", "..", "modules")
local dyld = import("apple.dyld", {rootdir = modules, anonymous = true})
local workspace = import("workspace", {rootdir = modules, anonymous = true})

local CPU_ARM64 = 0x0100000C
local SUBTYPES = {arm64 = 0, arm64e = 2}
local ENDING = {ret = true, retab = true, retaa = true, brk = true}

local function readable(cache, address, wanted)
    if cache.mapped(address, wanted) then
        return wanted
    end
    local low, high = 0, wanted
    while high - low > 1 do
        local middle = (low + high) // 2
        if cache.mapped(address, middle) then
            low = middle
        else
            high = middle
        end
    end
    return low
end

local function printable(cache, address)
    if address == 0 or not cache.mapped(address, 1) then
        return nil
    end
    local bytes = cache.read_address(address, readable(cache, address, 300))
    local finish = bytes:find("\0", 1, true)
    local text = finish and bytes:sub(1, finish - 1)
    if text and #text >= 2 and not text:find("[^\32-\126]") then
        return text
    end
end

local function quoted(text)
    local quote = (text:find("'", 1, true) and not text:find("\"", 1, true)) and "\"" or "'"
    local escaped = text:gsub("\\", "\\\\")
    if quote == "'" then
        escaped = escaped:gsub("'", "\\'")
    end
    return quote .. escaped .. quote
end

local function number(text)
    local digits = text and text:match("^#?0[xX](%x+)$")
    if digits then
        return tonumber(digits, 16)
    end
    digits = text and text:match("^#?(%x+)$")
    return digits and tonumber(digits, 16)
end

local function wrapped(code, address, architecture)
    local commands = 72 + 80
    local offset = 32 + commands
    return string.pack("<I4I4I4I4I4I4I4I4", 0xFEEDFACF, CPU_ARM64, SUBTYPES[architecture], 1, 1, commands, 0, 0)
        .. string.pack("<I4I4c16I8I8I8I8I4I4I4I4", 0x19, commands, "", address, #code, offset, #code, 7, 7, 1, 0)
        .. string.pack("<c16c16I8I8I4I4I4I4I4I4I4I4", "__text", "__TEXT", address, #code, offset, 2, 0, 0, 0x80000400, 0, 0, 0)
        .. code
end

local function listing(code, address, architecture)
    local folder = workspace.fresh("cache-disasm")
    local object = path.join(folder, "code.o")
    io.writefile(object, wrapped(code, address, architecture))
    local output, failure
    try {
        function ()
            output = os.iorunv("xcrun", {"llvm-objdump", "-d", "-z", "--no-show-raw-insn", "--no-leading-headers", "--print-imm-hex", object})
        end,
        catch {
            function (errors)
                failure = tostring(errors)
            end
        }
    }
    os.tryrm(folder)
    if failure then
        raise("xcrun llvm-objdump, from the Command Line Tools, could not disassemble 0x%x: %s", address, failure)
    end
    local instructions = {}
    for line in output:gmatch("[^\n]+") do
        local at, mnemonic, operands = line:match("^%s*(%x+):%s+(%S+)%s*(.-)%s*$")
        if at then
            operands = operands:gsub("%s*;.*$", ""):gsub("%s*<.*$", "")
            table.insert(instructions, {address = tonumber(at, 16), mnemonic = mnemonic, operands = operands})
        end
    end
    return instructions
end

local function annotate(cache, registers, instruction, word)
    local operands = instruction.operands
    if instruction.mnemonic == "adrp" then
        local register = operands:match("^(%w+),")
        local immediate = ((word >> 29) & 3) | (((word >> 5) & 0x7FFFF) << 2)
        if immediate >= 0x100000 then
            immediate = immediate - 0x200000
        end
        registers[register] = (instruction.address & ~0xFFF) + (immediate << 12)
        return ""
    end
    if instruction.mnemonic == "add" and operands:find("#", 1, true) then
        local parts = operands:split(",%s*")
        local base = parts[2] and registers[parts[2]]
        local added = number(parts[3])
        if #parts == 3 and base and added then
            local target = base + added
            registers[parts[1]] = target
            local text = printable(cache, target)
            return text and "; " .. quoted(text) or string.format("; 0x%x", target)
        end
    end
    if instruction.mnemonic == "ldr" and operands:find("[", 1, true) then
        local parts = operands:gsub("[%[%]]", ""):split(",%s*")
        local base = parts[2] and registers[parts[2]]
        local added = parts[3] and parts[3]:startswith("#") and number(parts[3])
        if #parts >= 3 and base and added and cache.mapped(base + added, 8) then
            local target = base + added
            local pointed = cache.pointer_at(target, true)
            local text = pointed ~= 0 and printable(cache, pointed)
            return string.format("; ptr at 0x%x -> %s", target, text and quoted(text) or string.format("0x%x", pointed))
        end
    end
    return ""
end

function disassemble(cachefile, start, limit)
    limit = limit or 400
    local cache = dyld.open_cache(cachefile)
    if not SUBTYPES[cache.architecture] then
        cache.close()
        raise("%s holds %s code: cache-disasm.lua reads arm64 and arm64e only", cachefile, cache.architecture)
    end
    local code = cache.read_address(start, readable(cache, start, limit * 4) & ~3)
    local lines, registers = {}, {}
    for count, instruction in ipairs(listing(code, start, cache.architecture)) do
        if instruction.mnemonic == "<unknown>" then
            break
        end
        local word = string.unpack("<I4", code, instruction.address - start + 1)
        table.insert(lines, string.format("0x%x:\t%s\t%s\t%s", instruction.address, instruction.mnemonic, instruction.operands,
                                          annotate(cache, registers, instruction, word)))
        if ENDING[instruction.mnemonic] or (instruction.mnemonic == "b" and count > 3) then
            break
        end
    end
    cache.close()
    return lines
end

function main(cachefile, address, instructions)
    local start = address and tonumber((address:gsub("^0[xX]", "")), 16)
    if not cachefile or not start then
        raise("usage: xmake l cache-disasm.lua <dyld_shared_cache> <address> [instructions]")
    end
    for _, line in ipairs(disassemble(cachefile, start, instructions and tonumber(instructions))) do
        io.write(line, "\n")
    end
end
