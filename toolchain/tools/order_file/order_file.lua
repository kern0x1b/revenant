local function fail(message)
    io.stderr:write("order_file.lua: " .. message .. "\n")
    os.exit(64)
end

local function usage()
    io.stderr:write("usage: ./xmakew l -P . toolchain/tools/order_file/order_file.lua --llvm-bin DIR [--image NAME] BLOCK-PROFILE BINARY OUTPUT\n")
    os.exit(64)
end

local function parse_arguments(arguments)
    local options = {}
    local positional = {}
    local index = 1
    while index <= #arguments do
        local argument = arguments[index]
        if argument == "--llvm-bin" or argument == "--image" then
            index = index + 1
            if arguments[index] == nil then
                usage()
            end
            if argument == "--llvm-bin" then
                options.llvm_bin = arguments[index]
            else
                options.image = arguments[index]
            end
        elseif argument:sub(1, 2) == "--" then
            usage()
        else
            table.insert(positional, argument)
        end
        index = index + 1
    end
    if #positional ~= 3 or not options.llvm_bin then
        usage()
    end
    options.profile, options.binary, options.output = positional[1], positional[2], positional[3]
    options.image = options.image or path.filename(options.binary)
    options.nm = path.join(options.llvm_bin, "llvm-nm")
    options.objdump = path.join(options.llvm_bin, "llvm-objdump")
    return options
end

local function each_line(text, visit)
    local at = 1
    while at <= #text do
        local stop = text:find("\n", at, true) or (#text + 1)
        visit(text:sub(at, stop - 1))
        at = stop + 1
    end
end

local function split_tabs(line)
    local fields = {}
    local at = 1
    while true do
        local stop = line:find("\t", at, true)
        if not stop then
            table.insert(fields, line:sub(at))
            return fields
        end
        table.insert(fields, line:sub(at, stop - 1))
        at = stop + 1
    end
end

local function text_symbols(program, binary)
    local symbols = {}
    each_line(os.iorunv(program, {"-n", binary}), function (line)
        local address, kind, name = line:match("^(%x+) (%a) (%S+)$")
        if address and (kind == "T" or kind == "t") then
            table.insert(symbols, {address = tonumber(address, 16), name = name})
        end
    end)
    table.sort(symbols, function (a, b)
        if a.address ~= b.address then
            return a.address < b.address
        end
        return a.name < b.name
    end)
    return symbols
end

local function text_base(program, binary)
    local base = nil
    local after_segname = false
    each_line(os.iorunv(program, {"--private-headers", binary}), function (line)
        if base then
            return
        end
        local address = after_segname and line:match("^%s*vmaddr%s+(0x%x+)")
        if address then
            base = tonumber(address)
        end
        after_segname = line:match("segname __TEXT$") ~= nil
    end)
    return base
end

local function containing(symbols, address)
    local low, high = 1, #symbols
    local found = nil
    while low <= high do
        local middle = (low + high) // 2
        if symbols[middle].address <= address then
            found = middle
            low = middle + 1
        else
            high = middle - 1
        end
    end
    return found and symbols[found] or nil
end

local function heat(options, symbols, base)
    local ticks = {}
    local header = true
    each_line(io.readfile(options.profile), function (line)
        if line == "" then
            return
        end
        local fields = split_tabs(line)
        if header then
            header = false
            if fields[1] ~= "pid" then
                fail(options.profile .. " is not a block profile table")
            end
            return
        end
        local image, offset, sampled = fields[12], fields[13], tonumber(fields[6])
        if path.filename(image or "") ~= options.image or not sampled then
            return
        end
        local symbol = containing(symbols, base + (tonumber(offset) or tonumber(offset, 16)))
        if symbol then
            ticks[symbol.name] = (ticks[symbol.name] or 0) + sampled
        end
    end)
    return ticks
end

function main(...)
    local options = parse_arguments({...})
    for _, file in ipairs({options.profile, options.binary}) do
        if not os.isfile(file) then
            fail(file .. " is not there")
        end
    end
    for _, tool in ipairs({options.nm, options.objdump}) do
        if not os.isfile(tool) then
            fail(tool .. " is not there: --llvm-bin must name the bin folder of the llvm package with its libraries config")
        end
    end
    local symbols = text_symbols(options.nm, options.binary)
    if #symbols == 0 then
        fail("no text symbols in " .. options.binary .. " from " .. options.nm)
    end
    local base = text_base(options.objdump, options.binary)
    if not base then
        fail("no __TEXT segment in " .. options.binary .. " from " .. options.objdump)
    end
    local ticks = heat(options, symbols, base)
    local names = {}
    for name in pairs(ticks) do
        table.insert(names, name)
    end
    table.sort(names, function (a, b)
        if ticks[a] ~= ticks[b] then
            return ticks[a] > ticks[b]
        end
        return a < b
    end)
    io.writefile(options.output, #names > 0 and (table.concat(names, "\n") .. "\n") or "")
    print(string.format("%d symbols with executed blocks, written to %s", #names, options.output))
end
