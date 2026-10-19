local common = import("values_common", {rootdir = os.scriptdir(), anonymous = true})
local runtime = import("runtime", {rootdir = path.join(os.scriptdir(), "..", "..", "modules", "gyb"), anonymous = true})

local STRING_TYPES = {"__CFString", "NSString", "CFStringRef", "NSConstantString"}
local SCALAR_WIDTHS = {["int"] = 4, ["unsigned int"] = 4, ["unsigned"] = 4, ["long"] = "p", ["unsigned long"] = "p",
                       ["long long"] = 8, ["unsigned long long"] = 8, ["short"] = 2, ["unsigned short"] = 2,
                       ["char"] = 1, ["signed char"] = 1, ["unsigned char"] = 1, ["float"] = 4, ["double"] = 8,
                       ["long double"] = 8, ["BOOL"] = 1, ["bool"] = 1, ["_Bool"] = 1, ["void *"] = "p",
                       ["int32_t"] = 4, ["uint32_t"] = 4, ["int64_t"] = 8, ["uint64_t"] = 8, ["int16_t"] = 2,
                       ["uint16_t"] = 2, ["int8_t"] = 1, ["uint8_t"] = 1, ["size_t"] = "p", ["ssize_t"] = "p",
                       ["ptrdiff_t"] = "p", ["intptr_t"] = "p", ["uintptr_t"] = "p", ["wchar_t"] = 4,
                       ["NSInteger"] = "p", ["NSUInteger"] = "p", ["CFIndex"] = "p", ["CFRunLoopRef"] = "p",
                       ["CFStringRef"] = "p", ["CFTypeID"] = "p", ["CFHashCode"] = "p", ["CFTypeRef"] = "p",
                       ["Boolean"] = 1, ["mach_port_t"] = 4, ["id"] = "p", ["Class"] = "p", ["SEL"] = "p", ["IMP"] = "p"}
local ABI_SIZED = {["CGFloat"] = "f",["NSInteger"] = "i", ["NSUInteger"] = "i", ["long"] = "i", ["unsigned long"] = "i",
                   ["size_t"] = "i", ["ssize_t"] = "i", ["CFIndex"] = "i", ["CFAbsoluteTime"] = "f", ["NSTimeInterval"] = "f",
                   ["ptrdiff_t"] = "i", ["intptr_t"] = "i", ["uintptr_t"] = "i", ["CFTypeID"] = "i", ["CFHashCode"] = "i",
                   ["mach_vm_size_t"] = "i", ["vm_size_t"] = "i", ["vm_offset_t"] = "i", ["kern_boottime_t"] = "i", ["id"] = "i",
                   ["Class"] = "i", ["SEL"] = "i", ["IMP"] = "i", ["Boolean"] = 1, ["BOOL"] = 1, ["dispatch_once_t"] = "i"}
local QUALIFIERS = {"const", "volatile", "restrict", "_Nonnull", "_Nullable", "_Null_unspecified", "__kindof",
                    "__unsafe_unretained", "strong", "weak", "atomic", "nonatomic", "readonly", "readwrite", "_Nullable_result"}

local ORACLE_SAMPLE = 8

function oracle_sample()
    return ORACLE_SAMPLE
end

function scalar_width(kind)
    return SCALAR_WIDTHS[kind]
end

function strip_type(text)
    for _, word in ipairs(QUALIFIERS) do
        text = text:gsub("%f[%w_]" .. word .. "%f[^%w_]", " ")
    end
    return table.concat(common.words(text), " ")
end

function resolve_type(declared, typedefs)
    local seen, current = {}, strip_type(declared)
    for _ = 1, 16 do
        if seen[current] then
            return current, false
        end
        seen[current] = true
        local following = typedefs[current]
        if following == nil or following == "" then
            return current, true
        end
        current = strip_type(following)
    end
    return current, false
end

local function names_a_string(resolved)
    for _, name in ipairs(STRING_TYPES) do
        if resolved:find(name .. "%s*%*") then
            return true
        end
    end
    return false
end

local function function_pointer(resolved)
    return resolved:match("^[%w_][%w_ ]*%([^)]*%)$") ~= nil
end

function classify(sugared, canonical, typedefs)
    local resolved = resolve_type(canonical, typedefs)
    if resolved == "" then
        return 0, false, false, canonical
    end
    local abi = ABI_SIZED[strip_type(sugared)] or ABI_SIZED[strip_type(canonical)]
    if abi ~= nil then
        if abi == 1 then
            return 1, false, false, resolved
        end
        if resolved:find("*", 1, true) then
            return "p", true, names_a_string(resolved), resolved
        end
        return "p", false, false, resolved
    end
    if resolved:find("*", 1, true) then
        return "p", true, names_a_string(resolved), resolved
    end
    if SCALAR_WIDTHS[resolved] ~= nil then
        return SCALAR_WIDTHS[resolved], false, false, resolved
    end
    if function_pointer(resolved) then
        return "p", true, false, resolved
    end
    return 0, false, false, resolved
end

function float32(u32)
    return string.unpack("<f", string.pack("<I4", u32 & 0xFFFFFFFF))
end

local function finite(value)
    return value == value and value ~= math.huge and value ~= -math.huge
end

function repr(value)
    if math.type(value) == "float" then
        return runtime.format_float_repr(value)
    end
    return runtime.to_repr(value)
end

local function python_hex(value)
    if math.type(value) == "integer" then
        return value < 0 and string.format("-0x%x", -value) or string.format("0x%x", value)
    end
    return tostring(value)
end

function sentinel_reason(ctype, declared, read_width, storage, u32, f64)
    if common.present(storage) and read_width > storage then
        return "read-too-wide", string.format("the symbol's own storage is %d bytes (the distance to the next export in the same image) and %d were read, so the value would be built from the bytes past its end",
                                              storage, read_width)
    end
    local kind = common.strip(ctype)
    if kind == "float" or kind == "double" or kind == "long double" then
        if not finite(f64) then
            return "read-sentinel", string.format("the bytes are not a finite %s (%s): a placeholder the release initialises, not a value to export", kind, python_hex(f64))
        end
        if declared:find("CGFloat", 1, true) or declared:find("NSTimeInterval", 1, true) or declared:find("CFAbsoluteTime", 1, true) then
            if not finite(float32(u32)) then
                return "read-sentinel", string.format("read at the cache's pointer width, and the low four bytes (0x%08x) are not a finite float, so a placeholder the release initialises is being read as a value",
                                                      u32 & 0xFFFFFFFF)
            end
        elseif kind == "float" and not finite(float32(u32)) then
            return "read-sentinel", string.format("the bytes are not a finite float (0x%08x): a placeholder the release initialises, not a value to export", u32 & 0xFFFFFFFF)
        end
    end
    return nil
end

function format_value(ctype, read_width, pointer, text, u32, u64, f64, hexed)
    if not common.present(hexed) or hexed == "-" then
        return "", string.format("the declared type is neither a scalar nor a pointer (%s): the symbol is at %s in this release, and no fixed-width read of it would be this constant's value",
                                 ctype, hexed)
    end
    if common.present(pointer) then
        if common.present(text) and text ~= "-" then
            return '"' .. text .. '"', "constant string"
        end
        return "", string.format("a function pointer or a pointer to something that is not a constant string: the release holds an address at %s, which is not a value the port can export -- it needs a real definition",
                                 (common.present(text) and text ~= "-") and text or hexed)
    end
    local kind = common.strip(ctype)
    if kind == "double" and read_width == 4 then
        return repr(float32(u32)), "CGFloat, 4 bytes in this cache"
    end
    if kind == "float" or kind == "double" or kind == "long double" then
        if kind == "float" and read_width == 4 then
            return repr(float32(u32)), "float"
        end
        return repr(f64), kind ~= "long double" and "double" or "long double, read as double"
    end
    if kind ~= "" and SCALAR_WIDTHS[kind] == nil then
        return hexed, string.format("raw bytes: the declared type is not a scalar this reads (%s)", kind)
    end
    if read_width == 8 then
        return tostring(u64), "64-bit integer"
    end
    if read_width == 1 or read_width == 2 or read_width == 4 then
        return tostring(u32), "integer"
    end
    return hexed, string.format("raw bytes: no width was read (%s)", kind)
end

function listing_line(name, width, pointer, text)
    return string.format("%s\t%s\t%s\t%s\n", name, tostring(width), pointer and "p" or "-", text and "s" or "-")
end

function parse_reader(output)
    local values, architecture = {}, ""
    for line in output:gmatch("[^\n]+") do
        local parts = common.split(line, "\t")
        if parts[1] == "#cache" then
            architecture = parts[2]
        elseif #parts >= 10 and parts[2] ~= "-" then
            local function number(field)
                return common.python_int(field) or 0
            end
            local storage = 0
            if #parts > 10 and parts[11] ~= "-" then
                storage = common.python_int(parts[11])
                if storage == nil then
                    raise("cache-value.lua wrote a storage column that is not an integer: %s", parts[11])
                end
            end
            values[parts[1]] = {install = parts[2], address = parts[3], hexed = parts[4], u32 = number(parts[5]), u64 = number(parts[6]),
                                f64 = number(parts[7]), pointer = parts[8], text = parts[9], width = number(parts[10]), storage = storage}
        end
    end
    return values, architecture
end

function read_cache(cachefile, symbols, scratch, revenant_root)
    local listing = path.join(scratch, "listing-" .. hash.uuid4() .. ".txt")
    local lines = {}
    for _, symbol in ipairs(symbols) do
        table.insert(lines, listing_line(symbol[1], symbol[2], symbol[3], symbol[4]))
    end
    io.writefile(listing, table.concat(lines))
    local out_file, err_file = listing .. ".out", listing .. ".err"
    local status, failure = os.execv(os.programfile(), {"l", path.join(os.scriptdir(), "cache-value.lua"), cachefile, listing},
                                     {try = true, curdir = revenant_root, envs = {REVENANT_ROOT = revenant_root}, stdout = out_file, stderr = err_file,
                                      timeout = 5400 * 1000})
    local output, errors = io.readfile(out_file) or "", io.readfile(err_file) or ""
    os.tryrm(listing)
    os.tryrm(out_file)
    os.tryrm(err_file)
    if status ~= 0 then
        raise("cache-value.lua failed on %s: %s", cachefile, (errors ~= "" and errors or tostring(failure)):sub(-3000))
    end
    return parse_reader(output)
end
