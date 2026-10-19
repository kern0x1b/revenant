local MODULES = path.join(os.scriptdir(), "..", "..", "modules")
local dyld = import("apple.dyld", {rootdir = MODULES, anonymous = true})
local byteorder = import("byteorder", {rootdir = MODULES, anonymous = true})

local MERGED = "first-rung.tsv.gz"

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

local function gunzip(file)
    return os.iorunv("gzip", {"-dc", file})
end

local function each_line(text, visit)
    local at = 1
    while at <= #text do
        local stop = text:find("\n", at, true) or (#text + 1)
        visit(text:sub(at, stop - 1))
        at = stop + 1
    end
end

local function open_table(file)
    local index = file .. ".idx"
    if not os.isfile(file) then
        fail("first-rung.lua: " .. file .. " is not there. Build it: xmake l tools/cache-index/build.lua")
    end
    if not os.isfile(index) then
        fail("first-rung.lua: " .. index .. " is not there, so " .. file .. " cannot be read in blocks. Rebuild both: "
            .. "xmake l tools/cache-index/build.lua")
    end
    local self = {path = file, size = os.filesize(file), offsets = {}, firsts = {}, cached = nil}
    each_line(io.readfile(index, {encoding = "binary"}), function (line)
        local offset, first = line:match("^(%d+)\t(.+)$")
        if first then
            table.insert(self.offsets, tonumber(offset))
            table.insert(self.firsts, first)
        end
    end)
    return self
end

local function table_block(self, index)
    if self.cached ~= index then
        local start = self.offsets[index]
        local stop = self.offsets[index + 1] or self.size
        local text = os.iorunv("sh", {"-c", 'tail -c +"$2" "$1" | head -c "$3" | gzip -dc', "sh", self.path,
            tostring(start + 1), tostring(stop - start)})
        local names, rungs = {}, {}
        each_line(text, function (line)
            local name, rung = line:match("^(.*)\t([^\t]*)$")
            if name and name ~= "" then
                table.insert(names, name)
                table.insert(rungs, rung)
            end
        end)
        self.cached, self.names, self.rungs = index, names, rungs
    end
    return self.names, self.rungs
end

local function table_get(self, name)
    local low, high = 1, #self.firsts
    while low <= high do
        local middle = (low + high) // 2
        if byteorder.less(name, self.firsts[middle]) then
            high = middle - 1
        else
            low = middle + 1
        end
    end
    local index = low - 1
    if index < 1 then
        return "NONE"
    end
    local names, rungs = table_block(self, index)
    low, high = 1, #names
    while low <= high do
        local middle = (low + high) // 2
        if byteorder.less(names[middle], name) then
            low = middle + 1
        else
            high = middle - 1
        end
    end
    if low <= #names and names[low] == name then
        return rungs[low]
    end
    return "NONE"
end

local function table_all(self)
    local names, rungs = {}, {}
    for index = 1, #self.offsets do
        local block_names, block_rungs = table_block(self, index)
        for at = 1, #block_names do
            table.insert(names, block_names[at])
            table.insert(rungs, block_rungs[at])
        end
    end
    return names, rungs
end

local function ladder_releases()
    local releases = {}
    for _, entry in ipairs(dyld.held_ladder({"armv7", "armv7s"})) do
        table.insert(releases, entry.release)
    end
    return releases
end

local function names_of(release)
    local held = {}
    local text = gunzip(index_file(release))
    local header_end = text:find("\n", 1, true) or #text
    each_line(text:sub(header_end + 1), function (line)
        if line:find("%S") then
            held[line] = true
        end
    end)
    return held
end

local function names_from_stdin(into)
    local text = io.stdin:read("a") or ""
    each_line(text, function (raw)
        local name = raw:gsub("\n+$", ""):gsub("\r+$", "")
        if name ~= "" and name:sub(1, 1) ~= "#" then
            table.insert(into, name)
        end
    end)
    return into
end

local function stdin_is_terminal()
    local result = try {function () return os.iorunv("sh", {"-c", "test -t 0 && printf tty"}) end,
        catch {function () return nil end}}
    return result == "tty"
end

local function scan_first_rungs(wanted, order)
    local answer = {}
    for _, release in ipairs(order) do
        each_line(gunzip(index_file(release)), function (line)
            if wanted[line] and answer[line] == nil then
                answer[line] = release
            end
        end)
    end
    return answer
end

local function self_test()
    local table_file = open_table(path.join(index_dir(), MERGED))
    local all_names, all_rungs = table_all(table_file)
    local have = {}
    for index, name in ipairs(all_names) do
        have[name] = all_rungs[index]
    end
    local failures, checks = {}, 0

    local function check(label, name, expected)
        local got = table_get(table_file, name)
        checks = checks + 1
        local mark = got == expected and "ok  " or "FAIL"
        if got ~= expected then
            table.insert(failures, label)
        end
        print(string.format("%s %-34s expected %-6s got %s", mark, label, expected, got))
    end

    check("positive control: _NSFileSize", "_NSFileSize", "3.0")
    check("positive control: NSFileSize", "NSFileSize", "3.0")
    check("positive control: a later-rung class", "MTKTextureLoader", "9.0")
    check("positive control: the oldest of two carriers", "PKShippingMethod", "8.0")
    check("positive control: first carried after 10.x", "CIQRCodeDescriptor", "11.0")
    check("negative control: a nonsense name", "CharonNoSuchNameEverExisted", "NONE")
    local spellings = 0
    for _, name in ipairs({"NSFileManager", "_OBJC_CLASS_$_NSFileManager"}) do
        if have[name] then
            spellings = spellings + 1
        end
    end
    checks = checks + 1
    if spellings ~= 2 then
        table.insert(failures, "both spellings")
    end
    print(string.format("%s %-34s", spellings == 2 and "ok  " or "FAIL", "both spellings present"))
    local ladder = ladder_releases()
    local held = {}
    for _, release in ipairs(ladder) do
        held[release] = true
    end
    local stray, stray_names = {}, {}
    for _, rung in ipairs(all_rungs) do
        if not held[rung] and not stray[rung] then
            stray[rung] = true
            table.insert(stray_names, rung)
        end
    end
    byteorder.sort(stray_names)
    checks = checks + 1
    if #stray_names > 0 then
        print("FAIL the table names rungs the ladder does not hold: " .. table.concat(stray_names, ", "))
        table.insert(failures, "stray rungs")
    else
        print(string.format("ok   every rung in the table is held (%d rungs)", #ladder))
    end
    local probes = {}
    for index = 1, #table_file.firsts, 16 do
        table.insert(probes, table_file.firsts[index])
    end
    math.randomseed(1)
    for _ = 1, math.min(200, #all_names) do
        table.insert(probes, all_names[math.random(#all_names)])
    end
    for _, name in ipairs({"_NSFileSize", "NSFileSize", "MTKTextureLoader", "PKShippingMethod", "CIQRCodeDescriptor"}) do
        table.insert(probes, name)
    end
    local disagreements = {}
    for _, name in ipairs(probes) do
        if table_get(table_file, name) ~= (have[name] or "NONE") then
            table.insert(disagreements, name)
        end
    end
    checks = checks + 1
    if #disagreements > 0 then
        table.insert(failures, "get() disagrees with the table walk")
        print(string.format("FAIL get() disagrees with the whole-table walk on %d of %d names", #disagreements, #probes))
    else
        print(string.format("ok   get() agrees with the whole-table walk on %d names", #probes))
    end
    local wanted = {}
    for _, name in ipairs(probes) do
        wanted[name] = true
    end
    local scanned = scan_first_rungs(wanted, ladder)
    local scan_disagreements = {}
    for _, name in ipairs(probes) do
        if table_get(table_file, name) ~= (scanned[name] or "NONE") then
            table.insert(scan_disagreements, name)
        end
    end
    checks = checks + 1
    if #scan_disagreements > 0 then
        table.insert(failures, "get() disagrees with the per-rung scan")
        print(string.format("FAIL get() disagrees with a scan of every rung's index on %d of %d names, e.g. %s",
            #scan_disagreements, #probes, scan_disagreements[1]))
    else
        print(string.format("ok   get() agrees with a scan of every rung's index on %d names", #probes))
    end
    print(string.format("self-test: checks=%d failures=%d", checks, #failures))
    if #failures > 0 then
        os.exit(1)
    end
end

local function rungs_of(names)
    local started = os.mclock()
    local order = ladder_releases()
    local held = {}
    for _, release in ipairs(order) do
        held[release] = names_of(release)
    end
    io.stderr:write(string.format("first-rung.lua: read %d per-release index(es) in %.2fs\n", #order,
        (os.mclock() - started) / 1000))
    for _, name in ipairs(names) do
        local found = {}
        for _, release in ipairs(order) do
            if held[release][name] then
                table.insert(found, release)
            end
        end
        io.write(name, "\t", #found > 0 and table.concat(found, ",") or "NONE", "\n")
    end
end

local function lookup(names, timing)
    local table_file = open_table(path.join(index_dir(), MERGED))
    local started = os.mclock()
    local sorted = {}
    local seen = {}
    for _, name in ipairs(names) do
        if not seen[name] then
            seen[name] = true
            table.insert(sorted, name)
        end
    end
    byteorder.sort(sorted)
    local answered = {}
    for _, name in ipairs(sorted) do
        answered[name] = table_get(table_file, name)
    end
    for _, name in ipairs(names) do
        io.write(name, "\t", answered[name], "\n")
    end
    if timing then
        io.stderr:write(string.format("first-rung.lua: %d name(s) in %.3fs\n", #names, (os.mclock() - started) / 1000))
    end
end

local USAGE = "usage: xmake l tools/cache-index/first-rung.lua [--stdin] [--timing] [NAME...] | --rungs NAME... | --self-test"

function main(...)
    local args = {...}
    local names, rungs = {}, {}
    local want_stdin, want_self_test, timing = false, false, false
    local at = 1
    while at <= #args do
        local arg = args[at]
        if arg == "--stdin" then
            want_stdin = true
        elseif arg == "--self-test" then
            want_self_test = true
        elseif arg == "--timing" then
            timing = true
        elseif arg == "--rungs" then
            at = at + 1
            if args[at] == nil then
                fail(USAGE)
            end
            table.insert(rungs, args[at])
        elseif arg:match("^%-%-rungs=") then
            table.insert(rungs, arg:sub(#"--rungs=" + 1))
        elseif arg == "--" then
            for index = at + 1, #args do
                table.insert(names, args[index])
            end
            break
        elseif arg:sub(1, 1) == "-" and #arg > 1 then
            fail(USAGE .. "\nunknown option " .. arg)
        else
            table.insert(names, arg)
        end
        at = at + 1
    end

    if want_self_test then
        self_test()
        return
    end
    if #rungs > 0 then
        rungs_of(rungs)
        return
    end
    if want_stdin or #names == 0 then
        if not want_stdin and stdin_is_terminal() then
            fail("first-rung.lua: give names as arguments, or on stdin")
        end
        names_from_stdin(names)
    end
    lookup(names, timing)
end
