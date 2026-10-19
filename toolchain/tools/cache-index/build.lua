local MODULES = path.join(os.scriptdir(), "..", "..", "modules")
local dyld = import("apple.dyld", {rootdir = MODULES, anonymous = true})

local NAMES_SCRIPT = path.join(os.scriptdir(), "names.lua")

local BLOCK = 65536

local HEADER = "# charon-cache-index 2 format=2 order=byte release=%s arch=%s source=%s mtime=%d size=%d names=%d\n"

local USAGE = "usage: xmake l tools/cache-index/build.lua [--only RELEASE]... [--force] [--no-merge]"

local function index_dir()
    return path.join(os.getenv("CHARON_HOME") or path.join(os.getenv("HOME"), ".charon"), "cache-index")
end

local function index_file(release)
    return path.join(index_dir(), release .. ".names.gz")
end

local function fail(message)
    io.stderr:write(message, "\n")
    os.exit(1)
end

local function ends_with(text, suffix)
    return suffix == "" or text:sub(-#suffix) == suffix
end

local function gunzip(file)
    return os.iorunv("gzip", {"-dc", file})
end

local function body_of(text)
    return text:sub((text:find("\n", 1, true) or #text) + 1)
end

local function header_of(file)
    local first = try {function ()
        return os.iorunv("sh", {"-c", 'gzip -dc "$1" | head -n 1', "sh", file})
    end, catch {function () return nil end}}
    if not first then
        io.stdout:write(string.format("build.lua: %s does not read, so it will be rebuilt\n", file))
        return nil
    end
    local fields = {}
    for part in first:gmatch("%S+") do
        local key, value = part:match("^([^=]+)=(.*)$")
        if key then
            fields[key] = value
        end
    end
    return fields
end

local function stat_of(files)
    if #files == 0 then
        return 0, 0
    end
    local out = os.iorunv("stat", table.join({"-L", "-f", "%Fm %z"}, files))
    local newest, total = 0, 0
    for line in out:gmatch("[^\n]+") do
        local seconds, fraction, size = line:match("^(%d+)%.(%d+) (%d+)$")
        local nanos = tonumber(seconds) * 1000000000 + tonumber((fraction .. "000000000"):sub(1, 9))
        newest = math.max(newest, nanos)
        total = total + tonumber(size)
    end
    return newest, total
end

local function key_of(source)
    if os.isfile(source) then
        return stat_of({source})
    end
    return stat_of(os.files(path.join(source, "**")))
end

local function is_current(release, arch, source)
    local file = index_file(release)
    if not os.isfile(file) then
        return false
    end
    local fields = header_of(file)
    if not fields or fields.format ~= "2" or fields.arch ~= arch then
        return false
    end
    local mtime, size = key_of(source)
    return fields.mtime == tostring(mtime) and fields.size == tostring(size)
        and ends_with(fields.source or "", path.filename(source))
end

local function write_index(file, header_for, names_text)
    local raw = file .. ".raw"
    local sorted = file .. ".sorted"
    local partial = file .. ".partial"
    io.writefile(raw, names_text, {encoding = "binary"})
    os.iorunv("sh", {"-c", 'LC_ALL=C sort -u -o "$2" "$1"', "sh", raw, sorted})
    os.tryrm(raw)
    local count = tonumber(os.iorunv("sh", {"-c", 'wc -l < "$1"', "sh", sorted}):match("%d+"))
    io.writefile(partial, header_for(count), {encoding = "binary"})
    os.iorunv("sh", {"-c", 'cat "$1" >> "$2"', "sh", sorted, partial})
    os.tryrm(sorted)
    os.iorunv("gzip", {"-6", "-n", "-f", partial})
    os.mv(partial .. ".gz", file)
    return count
end

local function resorted(release, arch, source)
    local file = index_file(release)
    local fields = header_of(file) or {}
    local body = body_of(gunzip(file))
    local mtime, size = key_of(source)
    return write_index(file, function (count)
        return string.format(HEADER, release, arch, fields.source or source, mtime, size, count)
    end, body)
end

local function build_one(release, arch, source, force)
    if not force and is_current(release, arch, source) then
        return nil
    end
    local file = index_file(release)
    if not force and os.isfile(file) then
        local fields = header_of(file) or {}
        local mtime, size = key_of(source)
        if fields.mtime == tostring(mtime) and fields.size == tostring(size) then
            return resorted(release, arch, source), 0
        end
    end
    local mtime, size = key_of(source)
    local started = os.mclock()
    local names = os.iorunv("nice", {"-n", "19", "xmake", "l", NAMES_SCRIPT, source, arch})
    local elapsed = (os.mclock() - started) / 1000
    os.mkdir(index_dir())
    local count = write_index(file, function (names_count)
        return string.format(HEADER, release, arch, source, mtime, size, names_count)
    end, names)
    return count, elapsed
end

local function merge(full_ladder)
    local missing = {}
    for _, entry in ipairs(full_ladder) do
        if not os.isfile(index_file(entry.release)) then
            table.insert(missing, entry.release)
        end
    end
    if #missing > 0 then
        fail(string.format("build.lua: refusing to merge, %d of %d rung(s) have no index: %s\n"
            .. "  build them first (build.lua without --only), or the merged table would be a first-rung answer over a subset and every"
            .. " name in it would be keyed to the wrong rung.", #missing, #full_ladder, table.concat(missing, ", ")))
    end

    local first, keys = {}, {}
    for _, entry in ipairs(full_ladder) do
        local body = body_of(gunzip(index_file(entry.release)))
        local at = 1
        while at <= #body do
            local stop = body:find("\n", at, true) or (#body + 1)
            local name = body:sub(at, stop - 1)
            if name ~= "" and first[name] == nil then
                first[name] = entry.release
                table.insert(keys, name)
            end
            at = stop + 1
        end
    end
    local count = #keys

    local base = path.join(index_dir(), "first-rung.tsv.gz")
    local names_raw = base .. ".names.raw"
    local names_sorted = base .. ".names.sorted"
    io.writefile(names_raw, table.concat(keys, "\n") .. "\n", {encoding = "binary"})
    keys = nil
    os.iorunv("sh", {"-c", 'LC_ALL=C sort -u -o "$2" "$1"', "sh", names_raw, names_sorted})
    os.tryrm(names_raw)

    local partial = base .. ".partial"
    local block_raw = base .. ".block"
    io.writefile(partial, "", {encoding = "binary"})
    local offsets, batch, offset, first_name = {}, {}, 0, nil
    local function flush()
        io.writefile(block_raw, table.concat(batch), {encoding = "binary"})
        os.iorunv("gzip", {"-6", "-n", "-f", block_raw})
        os.iorunv("sh", {"-c", 'cat "$1" >> "$2"', "sh", block_raw .. ".gz", partial})
        os.tryrm(block_raw .. ".gz")
        batch = {}
    end
    for name in io.lines(names_sorted) do
        if #batch == 0 then
            first_name = name
            offset = os.filesize(partial)
        end
        table.insert(batch, string.format("%s\t%s\n", name, first[name]))
        if #batch == BLOCK then
            flush()
            table.insert(offsets, {offset, first_name})
        end
    end
    if #batch > 0 then
        flush()
        table.insert(offsets, {offset, first_name})
    end
    os.tryrm(names_sorted)
    local lines = {}
    for _, item in ipairs(offsets) do
        table.insert(lines, string.format("%d\t%s\n", item[1], item[2]))
    end
    io.writefile(base .. ".idx.partial", table.concat(lines), {encoding = "binary"})
    os.mv(partial, base)
    os.mv(base .. ".idx.partial", base .. ".idx")
    return count, os.filesize(base), #offsets
end

local function parse(args)
    local only, force, no_merge = {}, false, false
    local at = 1
    while at <= #args do
        local arg = args[at]
        if arg == "--only" then
            at = at + 1
            if args[at] == nil then
                fail(USAGE)
            end
            table.insert(only, args[at])
        elseif arg == "--force" then
            force = true
        elseif arg == "--no-merge" then
            no_merge = true
        else
            fail(USAGE .. "\nunknown argument " .. arg)
        end
        at = at + 1
    end
    return only, force, no_merge
end

function main(...)
    local only, force, no_merge = parse({...})
    local every = dyld.held_ladder({"armv7", "armv7s"})
    if #every == 0 then
        fail(string.format("build.lua: %s holds no release this port has a cache of", dyld.root()))
    end
    local rungs = every
    if #only > 0 then
        local wanted, found, absent = {}, {}, {}
        for _, release in ipairs(only) do
            wanted[release] = true
        end
        rungs = {}
        for _, entry in ipairs(every) do
            if wanted[entry.release] then
                table.insert(rungs, entry)
                found[entry.release] = true
            end
        end
        for _, release in ipairs(only) do
            if not found[release] then
                table.insert(absent, release)
            end
        end
        if #absent > 0 then
            fail("build.lua: no held release named " .. table.concat(absent, ", "))
        end
    end

    print(string.format("build.lua: %d rung(s), index in %s", #rungs, index_dir()))
    local started = os.mclock()
    local built, skipped, seconds = 0, 0, 0
    for _, entry in ipairs(rungs) do
        local count, took = build_one(entry.release, entry.architecture, entry.source, force)
        if count == nil then
            skipped = skipped + 1
            print(string.format("  %-8s %-6s current", entry.release, entry.architecture))
        else
            built = built + 1
            seconds = seconds + took
            local megabytes = os.isfile(entry.source) and os.filesize(entry.source) / 1048576 or 0
            print(string.format("  %-8s %-6s %8d names  %6.1fs  %5.0f MB", entry.release, entry.architecture, count, took, megabytes))
        end
    end
    print(string.format("build.lua: %d built, %d current, %.1fs of reading, %.1fs total", built, skipped, seconds,
        (os.mclock() - started) / 1000))
    if no_merge then
        return
    end
    local count, size, blocks = merge(every)
    print(string.format("build.lua: first-rung.tsv.gz holds %d names in %d block(s), %.1f MB", count, blocks, size / 1048576))
end
