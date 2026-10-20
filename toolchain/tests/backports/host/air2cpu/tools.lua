local pyish = import("pyish", {rootdir = path.join(os.scriptdir(), "..", "..", "common"), anonymous = true})

local MAGIC = "\222\192\023\011"

local function read_binary(file)
    local handle = io.open(file, "rb")
    if not handle then
        raise(string.format("no such file: %s", file), 0)
    end
    local data = handle:read("a")
    handle:close()
    return data
end

local function write_binary(file, data)
    local handle = assert(io.open(file, "wb"))
    handle:write(data)
    handle:close()
end

function extract(metallib, out)
    local data = read_binary(metallib)
    os.mkdir(path.join(out, "air"))
    local offset, index, taken = 1, 0, nil
    while true do
        local at = data:find(MAGIC, offset, true)
        if not at then
            break
        end
        local _, _, start, size = string.unpack("<I4I4I4I4", data, at)
        local module = data:sub(at + start, at + start + size - 1)
        if taken == nil then
            taken = module
            write_binary(path.join(out, "air", "m0.bc"), module)
        end
        index = index + 1
        offset = at + 4
    end
    if taken == nil then
        io.stderr:write(string.format("extract: %s holds no bitcode record\n", metallib))
        os.exit(1)
    end
    print(string.format("extract: %d bitcode record(s), took the first (%d bytes)", index, #taken))
    return 0
end

local ADDRESS = "=%s*%(char %*%)([%w_]+)%s*%+%s*%(([^%)]*)%)%s*%*%s*([%w_]+)%s*;"

local function address_matches(text)
    local out = {}
    local pos = 1
    while true do
        local s, e, base, index, width = text:find(ADDRESS, pos)
        if not s then
            break
        end
        table.insert(out, {base = base, index = pyish.strip(index), width = width, whole = pyish.strip(text:sub(s, e))})
        pos = e + 1
    end
    return out
end

function addressing(file)
    local text = io.readfile(file)
    local matches = address_matches(text)
    local problems = {}
    for _, m in ipairs(matches) do
        if m.width:match("^%d+$") then
            if tonumber(m.width) == 0 then
                table.insert(problems, string.format("%s: an address of (char *)%s is computed with a ZERO element width", file, m.base))
            end
            if m.index:match("^%d+$") and tonumber(m.index) > 8 then
                table.insert(problems, string.format("%s: (char *)%s is indexed with a constant %s, which is a fixed offset where the kernel's own index belongs", file, m.base, m.index))
            end
        end
    end
    for _, m in ipairs(matches) do
        if not m.index:match("^%d+$") and m.index == m.base then
            table.insert(problems, string.format("%s: (char *)%s is indexed with ITSELF, which is the base left in the index: %s", file, m.base, m.whole:sub(1, 90)))
        end
    end
    local seen, unique = {}, {}
    for _, problem in ipairs(problems) do
        if not seen[problem] then
            seen[problem] = true
            table.insert(unique, problem)
        end
    end
    table.sort(unique)
    for _, line in ipairs(unique) do
        print("FAIL " .. line)
    end
    print(string.format("check-generated-addressing: %d address(es) read, %d problem(s)", #matches, #unique))
    return #unique > 0 and 1 or 0
end

local function kernels_in_source(file)
    local names = {}
    for line in pyish.lines_of(file) do
        local at = line:find("//", 1, true)
        local code = at and line:sub(1, at - 1) or line
        local where = code:find("kernel void", 1, true)
        if where then
            local after = code:sub(where + #"kernel void")
            local head = after:match("^[^(]*")
            table.insert(names, pyish.strip(head))
        end
    end
    return names
end

local function answers(file)
    local out, duplicates = {}, {}
    for line in pyish.lines_of(file) do
        if line:sub(1, 4) == "OUT " then
            local parts = pyish.split(line)
            if out[parts[2]] ~= nil then
                table.insert(duplicates, parts[2])
            end
            local values = {}
            for i = 3, #parts do
                table.insert(values, parts[i])
            end
            out[parts[2]] = values
        end
    end
    return out, duplicates
end

local function refusals(file)
    local out = {}
    for line in pyish.lines_of(file) do
        if line:find("REFUSED", 1, true) then
            table.insert(out, pyish.strip(line))
        end
    end
    return out
end

local function kernels_of(file)
    local names = {}
    for line in pyish.lines_of(file) do
        if line:find('{ "', 1, true) and line:find("air2cpu_", 1, true) then
            local first = line:find('"', 1, true)
            local second = line:find('"', first + 1, true)
            table.insert(names, second and line:sub(first + 1, second - 1) or "")
        end
    end
    return names
end

local function contains(list, value)
    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end

local function same_values(a, b)
    return pyish.same_list(a, b)
end

local function unique_sorted(list)
    local seen, out = {}, {}
    for _, item in ipairs(list) do
        if not seen[item] then
            seen[item] = true
            table.insert(out, item)
        end
    end
    table.sort(out)
    return out
end

function compare(oracle_path, port_path, refusal_path, table_path, source_path)
    local expected = source_path and kernels_in_source(source_path) or {}
    local theirs, their_duplicates = answers(oracle_path)
    local ours, our_duplicates = answers(port_path)
    local translatable = table_path and kernels_of(table_path) or {}
    local checks, failures = 0, 0
    for _, name in ipairs(unique_sorted(our_duplicates)) do
        print(string.format("FAIL the port's side answered for %s twice: a library can hold a specialised and a general copy of one kernel, and a harness that prints every function prints the name twice. The run is not a measurement of one answer", name))
        failures = failures + 1
    end
    for _, name in ipairs(unique_sorted(their_duplicates)) do
        print(string.format("FAIL Metal's side answered for %s twice, so the answer being compared is not one answer either", name))
        failures = failures + 1
    end
    if #pyish.sorted_keys(ours) == 0 then
        print("FAIL the port's side produced no answer at all: every kernel the tool translated is unaccounted for, which is a hang or a crash and not a match")
        failures = failures + 1
    end
    for _, name in ipairs(translatable) do
        if ours[name] == nil then
            print(string.format("FAIL %s was translated by the tool and the port did not answer for it", name))
            failures = failures + 1
        end
    end
    local theirs_names = pyish.sorted_keys(theirs)
    for _, name in ipairs(theirs_names) do
        local values = theirs[name]
        local mine = ours[name]
        checks = checks + 1
        if mine == nil then
            print(string.format("refused %-16s the port did not translate this kernel, so there is no answer to compare", name))
        elseif same_values(mine, values) then
            print(string.format("match   %-16s %d values agree with Metal", name, #values))
        else
            failures = failures + 1
            print(string.format("DIFFER  %-16s", name))
            for index = 1, math.min(#values, #mine) do
                if values[index] ~= mine[index] then
                    print(string.format("        [%d] Metal %s, the port %s", index - 1, values[index], mine[index]))
                end
            end
        end
    end
    if refusal_path then
        for _, line in ipairs(refusals(refusal_path)) do
            print("        " .. line)
        end
    end
    for _, name in ipairs(theirs_names) do
        if not contains(translatable, name) then
            print(string.format("FAIL %s: Metal answered for it and the tool REFUSED it, so this kernel is not under test; a refusal is the port's documented error, not a result", name))
            failures = failures + 1
        end
    end
    local control = {}
    for _, name in ipairs({"sumKernel", "indexKernel"}) do
        if theirs[name] ~= nil then
            table.insert(control, name)
        end
    end
    local any_translated = false
    for _, name in ipairs(control) do
        if contains(translatable, name) then
            any_translated = true
        end
    end
    if #control > 0 and not any_translated then
        print(string.format("FAIL the control kernel(s) %s are answered by Metal and are NOT in the generated table, so every refusal above is a parser failure and not a refusal", table.concat(control, ", ")))
        failures = failures + 1
    end
    if ours["positionKernel"] ~= nil and theirs["positionKernel"] ~= nil then
        local v = theirs["positionKernel"]
        if #v < 6 then
            raise("positionKernel answered with fewer than six values", 0)
        end
        print(string.format("dispatch as the kernel sees it, positionKernel: group (%s, %s, %s) threads-per-group %s threads-per-grid %s index-in-group %s",
            v[1], v[2], v[3], v[4], v[5], v[6]))
    end
    for _, name in ipairs(expected) do
        if theirs[name] == nil or ours[name] == nil then
            print(string.format("FAIL %s is a kernel in the source and NEITHER side answered for it: the library under test is stale, or the tool refused it, and a run that says nothing about a kernel in the tree is not a measurement of it", name))
            failures = failures + 1
        end
    end
    print(string.format("compare: %d kernel(s) in the source, %d answered by Metal, %d in the table, %d compared, %d differ",
        #expected, #theirs_names, #translatable, checks, failures))
    return (failures > 0 or checks == 0) and 1 or 0
end

local function split_lines(text)
    local out = {}
    local start = 1
    while true do
        local at = text:find("\n", start, true)
        if not at then
            table.insert(out, text:sub(start))
            break
        end
        table.insert(out, text:sub(start, at - 1))
        start = at + 1
    end
    return out
end

local function join(lines, first, last)
    local parts = {}
    for i = first, last do
        table.insert(parts, lines[i])
    end
    return table.concat(parts, "\n")
end

function split(source, out)
    local lines = split_lines(io.readfile(source))
    local starts = {}
    for index = 0, #lines - 1 do
        if lines[index + 1]:sub(1, 12) == "kernel void " then
            table.insert(starts, index)
        end
    end
    if #starts == 0 then
        raise("the fixture has no kernel", 0)
    end
    local prologue = join(lines, 1, starts[1])
    for number, index in ipairs(starts) do
        local last = number < #starts and starts[number + 1] or #lines
        local top = index
        while top > 0 and (lines[top]:sub(1, 2) == "//" or pyish.strip(lines[top]) == "") do
            top = top - 1
        end
        local name = lines[index + 1]:match("^kernel void ([%w_]+)")
        if name == nil then
            raise("a kernel declaration with no name", 0)
        end
        io.writefile(path.join(out, string.format("%02d-%s.metal", number - 1, name)),
            prologue .. "\n" .. join(lines, top + 1, last) .. "\n")
    end
    print(string.format("note %d kernels split out of the fixture", #starts))
    return 0
end

local function replace_all(text, old, new)
    local out, start = {}, 1
    while true do
        local s, e = text:find(old, start, true)
        if not s then
            break
        end
        out[#out + 1] = text:sub(start, s - 1) .. new
        start = e + 1
    end
    out[#out + 1] = text:sub(start)
    return table.concat(out)
end

local function first_index(text, needle)
    local s = text:find(needle, 1, true)
    if not s then
        raise(string.format("the marker is not in the source: %s", needle), 0)
    end
    return s
end

local MUTANT_START = "    for (unsigned i = start; i < node->getNumOperands(); i++) {\n"
local MUTANT_END = "        if (name == \"air.arg_name\")"
local MUTANT_SCAN = "    for (unsigned i = start; i + 1 < node->getNumOperands(); i += 2) {\n"
    .. "        auto *key = dyn_cast<MDString>(node->getOperand(i));\n"
    .. "        if (!key)\n"
    .. "            continue;\n"
    .. "        std::string name = key->getString().str();\n"
local MUTANT_ACCESS_OLD = "        const char *access = nullptr;"
local MUTANT_ACCESS_NEW = "        const char *access = nullptr;\n"
    .. "        if (metadata.access == \"air.read\") access = \"read-only\";\n"
    .. "        else if (metadata.access == \"air.write\") access = \"write-only\";\n"
    .. "        else if (metadata.access == \"air.read_write\") access = \"read-write\";"

function mutant(file)
    local source = io.readfile(file)
    local start = first_index(source, MUTANT_START)
    local finish = first_index(source, MUTANT_END)
    source = source:sub(1, start - 1) .. MUTANT_SCAN .. source:sub(finish)
    source = replace_all(source, MUTANT_ACCESS_OLD, MUTANT_ACCESS_NEW)
    io.writefile(file, source)
    return 0
end

function modules(source)
    local metallib = replace_all(source, ".metal", ".metallib")
    local prefix = source:sub(1, -7)
    local data = read_binary(metallib)
    local index, offset = 0, 1
    while true do
        local at = data:find(MAGIC, offset, true)
        if not at then
            break
        end
        local _, _, start, size = string.unpack("<I4I4I4I4", data, at)
        write_binary(string.format("%s.m%d.bc", prefix, index), data:sub(at + start, at + start + size - 1))
        index = index + 1
        offset = at + 4
    end
    print(string.format("%s: %d module(s)", source, index))
    return 0
end

function main(command, ...)
    if command == "mutant" then
        os.exit(mutant(...))
    elseif command == "modules" then
        os.exit(modules(...))
    end
    if command == "extract" then
        os.exit(extract(...))
    elseif command == "addressing" then
        os.exit(addressing(...))
    elseif command == "compare" then
        os.exit(compare(...))
    elseif command == "split" then
        os.exit(split(...))
    end
    io.stderr:write("usage: tools.lua extract <metallib> <out> | addressing <port.c> | compare <oracle.out> <port.out> <air2cpu.out> <port.c> <kernels.metal> | split <kernels.metal> <out>\n")
    os.exit(2)
end
