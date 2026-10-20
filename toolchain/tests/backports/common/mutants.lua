local function read(file)
    local handle = io.open(file, "rb")
    if not handle then
        return nil
    end
    local text = handle:read("a")
    handle:close()
    return text
end

local function save(file, text)
    local handle = assert(io.open(file, "wb"))
    handle:write(text)
    handle:close()
end

local function chomp(text)
    if text:sub(-1) == "\n" then
        return text:sub(1, -2)
    end
    return text
end

function count(text, needle)
    if needle == "" then
        return #text + 1
    end
    local n, start = 0, 1
    while true do
        local s, e = text:find(needle, start, true)
        if not s then
            return n
        end
        n = n + 1
        start = e + 1
    end
end

function replace(text, old, new)
    local s, e = text:find(old, 1, true)
    return text:sub(1, s - 1) .. new .. text:sub(e + 1)
end

local commands = {}

function commands.once(file, old, new)
    local text = read(file)
    if not text then
        io.stderr:write(string.format("mutants.lua: %s cannot be read\n", file))
        os.exit(1)
    end
    local n = count(text, old)
    if n ~= 1 then
        io.stderr:write(string.format("the text to mutate is in %s %d times, and must be once\n", file, n))
        os.exit(1)
    end
    save(file, replace(text, old, new))
end

function commands.first(file, old, new)
    local text = read(file)
    if not text then
        io.stderr:write(string.format("mutants.lua: %s cannot be read\n", file))
        os.exit(1)
    end
    if count(text, old) == 0 then
        io.stderr:write(string.format("the text to mutate is not in %s\n", file))
        os.exit(1)
    end
    save(file, replace(text, old, new))
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

function commands.plant(folder, needle, replacement)
    local hits = 0
    for _, file in ipairs(os.files(path.join(folder, "*.h"))) do
        local text = read(file)
        local found = count(text, needle)
        if found > 0 then
            save(file, replace_all(text, needle, replacement))
            hits = hits + found
        end
    end
    if hits == 0 then
        io.stderr:write("PLANT: the needle is not in any of the copied headers, so nothing was planted\n")
        os.exit(1)
    end
    print(string.format("planted: replaced %d occurrence(s) of the needle", hits))
end

function commands.anchor(file, anchor_file, repl_file, copy, site)
    local anchor, repl, text = read(anchor_file), read(repl_file), read(file)
    if not anchor or not repl or not text then
        io.stderr:write(string.format("the mutant %s cannot read %s, %s or %s\n", site or anchor_file, file, anchor_file, repl_file))
        os.exit(1)
    end
    anchor, repl = chomp(anchor), chomp(repl)
    local n = count(text, anchor)
    if n ~= 1 then
        io.stderr:write(string.format("the anchor of %s occurs %d times in %s, and a mutation needs exactly one:\n",
            site or anchor_file, n, file))
        for line in (anchor .. "\n"):gmatch("(.-)\n") do
            io.stderr:write("  " .. line .. "\n")
        end
        os.exit(1)
    end
    if copy and copy ~= "" then
        save(copy, text)
    end
    save(file, replace(text, anchor, repl))
    print("mutated: " .. file)
end

function commands.anchors(folder, mutants, ...)
    local sites = {...}
    local width = 0
    for _, entry in ipairs(sites) do
        local site = entry:match(":(.+)$") or entry
        width = math.max(width, #site)
    end
    local bad = {}
    for _, entry in ipairs(sites) do
        local name, site = entry:match("^(.-):(.+)$")
        if not name then
            raise("a site is <file>:<site>, not %s", entry)
        end
        local label = site .. string.rep(" ", width - #site)
        local anchor = read(path.join(mutants, site .. ".anchor"))
        local text = read(path.join(folder, name))
        if not anchor then
            table.insert(bad, string.format("%s: no anchor file in %s", site, mutants))
            print(string.format("anchor check: %s NO ANCHOR FILE", label))
        elseif not text then
            table.insert(bad, string.format("%s: no source %s", site, path.join(folder, name)))
            print(string.format("anchor check: %s NO SOURCE", label))
        else
            local n = count(text, chomp(anchor))
            print(string.format("anchor check: %s %d occurrence(s) in %s", label, n, name))
            if n ~= 1 then
                table.insert(bad, string.format("%s occurs %d times in %s, and a mutation needs exactly one", site, n, name))
            end
        end
    end
    print(string.format("anchor check: %d sites compared, %d not resolving exactly once", #sites, #bad))
    for _, line in ipairs(bad) do
        io.stderr:write(line .. "\n")
    end
    if #bad > 0 then
        os.exit(1)
    end
end

local function class_span(text, cls)
    local needle = "@implementation " .. cls
    local start = 1
    while true do
        local s, e = text:find(needle, start, true)
        if not s then
            raise("no @implementation of %s", cls)
        end
        local after = text:sub(e + 1, e + 1)
        if after == "" or after == "\n" or after == " " or after == "\r" then
            local finish = text:find("\n@end", e, true)
            if not finish then
                raise("the @implementation of %s has no @end", cls)
            end
            return s, finish
        end
        start = e + 1
    end
end

local function nth_span(body, old, nth)
    local start, index = 1, 0
    while true do
        local s, e = body:find(old, start, true)
        if not s then
            return nil
        end
        index = index + 1
        if index == nth then
            return s, e
        end
        start = e + 1
    end
end

function commands.within(file, cls, old, new, nth)
    local text = read(file)
    if not text then
        io.stderr:write(string.format("mutants.lua: %s cannot be read\n", file))
        os.exit(1)
    end
    local i, finish = class_span(text, cls)
    local body = text:sub(i, finish - 1)
    local want = tonumber(nth or "1")
    local n = count(body, old)
    if n < want then
        io.stderr:write(string.format("the mutation must match at least %d place(s) in %s: '%s' appears %d\n", want, cls, old, n))
        os.exit(1)
    end
    local s, e = nth_span(body, old, want)
    save(file, text:sub(1, i - 1) .. body:sub(1, s - 1) .. new .. body:sub(e + 1) .. text:sub(finish))
end

function commands.all(file, old, new)
    local text = read(file)
    if not text then
        io.stderr:write(string.format("mutants.lua: %s cannot be read\n", file))
        os.exit(1)
    end
    save(file, replace_all(text, old, new))
end

function commands.constant(file, name, value)
    local text = read(file)
    if not text then
        io.stderr:write(string.format("mutants.lua: %s cannot be read\n", file))
        os.exit(1)
    end
    local out, pos, done = {}, 1, false
    while pos <= #text do
        local nl = text:find("\n", pos, true)
        local line = text:sub(pos, (nl or #text + 1) - 1)
        local ending = nl and "\n" or ""
        if not done then
            local prefix = line:match('^([%w_]+) const ' .. name .. ' = @"[^"]*";$')
            if prefix and (prefix == "NSErrorDomain" or prefix:match("^MTLCommonCounter")) then
                line = prefix .. " const " .. name .. ' = @"' .. value .. '";'
                done = true
            end
        end
        out[#out + 1] = line .. ending
        pos = (nl or #text) + 1
    end
    if not done then
        io.stderr:write(string.format("the mutation must match the constant it is mutating: %s\n", name))
        os.exit(1)
    end
    save(file, table.concat(out))
end

function commands.returns(file, cls, method, new)
    local text = read(file)
    if not text then
        io.stderr:write(string.format("mutants.lua: %s cannot be read\n", file))
        os.exit(1)
    end
    local i, finish = class_span(text, cls)
    local body = text:sub(i, finish - 1)
    local j = body:find(method, 1, true)
    if not j then
        io.stderr:write(string.format("the method %s is not in %s\n", method, cls))
        os.exit(1)
    end
    local k = body:find("\n}", j, true)
    if not k then
        io.stderr:write(string.format("the method %s of %s has no closing brace\n", method, cls))
        os.exit(1)
    end
    local seg = body:sub(j, k - 1)
    local s, e = seg:find("    return MTLBindingType[%w_]+;")
    if not s then
        io.stderr:write(string.format("no -type return in %s\n", cls))
        os.exit(1)
    end
    seg = seg:sub(1, s - 1) .. "    " .. new .. "   // MUTATION" .. seg:sub(e + 1)
    save(file, text:sub(1, i - 1) .. body:sub(1, j - 1) .. seg .. body:sub(k) .. text:sub(finish))
end

function main(command, ...)
    local run = commands[command or ""]
    if not run then
        io.stderr:write("usage: mutants.lua once <file> <from> <to> | first <file> <from> <to> | all <file> <from> <to> | within <file> <class> <from> <to> [nth] | constant <file> <name> <value> | returns <file> <class> <method> <statement> | plant <folder> <needle> <replacement> | anchor <file> <anchor> <repl> [copy] [site] | anchors <folder> <mutants> <file>:<site>...\n")
        os.exit(2)
    end
    run(...)
end
