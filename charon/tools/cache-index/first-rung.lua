-- xmake l tools/cache-index/first-rung.lua [--stdin] [NAME...]
-- xmake l tools/cache-index/first-rung.lua --rungs NAME...
-- xmake l tools/cache-index/first-rung.lua --self-test
--
-- The first held rung of a name, answered from the index tools/cache-index/build.lua writes instead of from 15 caches.
--
-- Prints one TSV line per name:  name<TAB>first held rung, or name<TAB>NONE for a name no held release carries. Names come from the
-- command line, or from stdin one per line when none are given. Blank lines and # comments are skipped, so a list file reads directly.
--
-- THE POINT OF THIS TOOL: the same question answered the way it was answered before, which reads 24.6 GB per name (6 ms per MB, so
-- ~148 s a name on an idle machine). This reads one gz file of a few MB, decompresses one block of it, and binary searches. See README.md.
--
-- WHAT "FIRST" MEANS: the ladder is dyld.held_ladder({"armv7","armv7s"}) in modules/apple/dyld.lua, oldest first. The answer is the OLDEST
-- held release that carries the name, because that is the release a port of it must support. It is NOT the release that introduced the
-- name: a symbol exported in 4.0, lost in 4.3 and back from 5.0 reads 4.0, and a release between two that carry it may lack it. That is the
-- condition tools/release-split.lua refuses a file over, and the reason this tool sits beside it.
--
-- NEGATIVE ANSWERS ARE ANSWERS: a name no held release carries prints NONE. A nonsense name is the control the self-test uses, and it is
-- also what a misspelt name, a framework this port does not carry, and a name that arrived after 18.0 all look like.
--
-- NAMES ARE BYTES, and the order is BYTE order (byteorder.less): Lua's own < on strings follows the locale, and the table is searched by
-- bytes, so the two must agree everywhere.

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

-- The whole of a gz file, decompressed. gzip(1) is the decompressor the repository already shells out to (modules/debian.lua,
-- modules/apple/firmware.lua), and it reads a multi-member file to its end, so a block is decompressed from its own bytes only.
local function gunzip(file)
    return os.iorunv("gzip", {"-dc", file})
end

-- The rows of a text, one per line, without the newline. The last line is kept even without a newline.
local function each_line(text, visit)
    local at = 1
    while at <= #text do
        local stop = text:find("\n", at, true) or (#text + 1)
        visit(text:sub(at, stop - 1))
        at = stop + 1
    end
end

-- The merged first-rung table, read in BLOCKS so a lookup costs one block and not the table. The table is written as independent gzip
-- MEMBERS of BLOCK names each, and <table>.idx holds each member's byte offset and its first name. A lookup binary searches the index
-- (in memory), then decompresses exactly the one member that can hold the name. A member is bounded by the next offset, so its bytes are
-- handed to gzip alone and nothing after it is read.

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
    -- BYTES: a block's first name is bytes, and decoding it to compare against a decoded query is how two orders came to disagree.
    each_line(io.readfile(index, {encoding = "binary"}), function (line)
        local offset, first = line:match("^(%d+)\t(.+)$")
        if first then
            table.insert(self.offsets, tonumber(offset))
            table.insert(self.firsts, first)
        end
    end)
    return self
end

-- The rows of ONE member: names and rungs, in the order the file holds them. Held for the next few lookups, since consecutive names land
-- in the same block.
local function table_block(self, index)
    if self.cached ~= index then
        local start = self.offsets[index]
        local stop = self.offsets[index + 1] or self.size
        local text = os.iorunv("sh", {"-c", 'tail -c +"$2" "$1" | head -c "$3" | gzip -dc', "sh", self.path,
            tostring(start + 1), tostring(stop - start)})
        local names, rungs = {}, {}
        each_line(text, function (line)
            -- the LAST tab separates the rung: a name can contain a tab (a C string with one in it does), a rung never can.
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
    -- bisect_right over the block firsts: the last block whose first name is not after the query
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
    -- bisect_left inside the block
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

-- Every name and its rung, for a self-test that has to see the whole table. The slow path; only the self-test takes it.
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

-- The names of a rung's per-release index, as a set of bytes: the header line is skipped, and a line that is only whitespace is not a
-- name (292 of them in the cache of 6.1.3, every one of which strings -a reports as part of a longer run).
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

-- The names of stdin, one per line: the line verbatim less its newline, and a line that is empty or starts a comment is skipped.
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
    -- try returns the function's value, or nil when it raised (no terminal makes `test -t 0` fail)
    local result = try {function () return os.iorunv("sh", {"-c", "test -t 0 && printf tty"}) end,
        catch {function () return nil end}}
    return result == "tty"
end

-- The first rung of each name in `wanted` (a set of names), found by reading every rung's own index in ladder order: the answer the
-- merged table must give for it. A name no rung carries is absent from the result.
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

    -- EVERY check goes through table_get(table_file, ), the code the tool answers with, and the walk is compared against it.
    local function check(label, name, expected)
        local got = table_get(table_file, name)
        checks = checks + 1
        local mark = got == expected and "ok  " or "FAIL"
        if got ~= expected then
            table.insert(failures, label)
        end
        print(string.format("%s %-34s expected %-6s got %s", mark, label, expected, got))
    end

    -- The positive control is 3.0, MEASURED: the name is in the Foundation of iPhone OS 3.0 as a NUL-delimited symbol-table string, which
    -- strings(1) does not read (README.md, "The 3.0 vs 3.1.3 disagreement"). A control asserting 4.3 would assert the old blind spot.
    check("positive control: _NSFileSize", "_NSFileSize", "3.0")
    check("positive control: NSFileSize", "NSFileSize", "3.0")
    -- A later-rung class, measured the same way, so the control is not a fact about 3.0 alone.
    check("positive control: a later-rung class", "MTKTextureLoader", "9.0")
    -- A name two rungs carry answers the OLDER one. PKShippingMethod is a defined, external symbol of PassKitCore in the 8.0 cache and
    -- in the 11.0 cache too (both measured with dyld.lua), and the SDK says API_AVAILABLE(ios(8.0)). A tool that answered the newest
    -- carrier, or the release a header names later, would fail here.
    check("positive control: the oldest of two carriers", "PKShippingMethod", "8.0")
    -- A name no 10.x index carries and the 11.0 index does: CIQRCodeDescriptor is absent from 9.3.6 to 10.3.4 and present from 11.0,
    -- and the SDK says NS_CLASS_AVAILABLE(10_13, 11_0). A tool that answered a rung before the name exists would fail here.
    check("positive control: first carried after 10.x", "CIQRCodeDescriptor", "11.0")
    -- A name no release has must answer NONE, or a tool that answered a rung for everything would pass the positives alone.
    check("negative control: a nonsense name", "CharonNoSuchNameEverExisted", "NONE")
    -- The bare and mangled spellings of one class must both be present: names.lua emits both from the same class name.
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
    -- Every rung in the table must be one the ladder holds, so an answer cannot name a release that is not there.
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
    -- get() against the whole-table walk, on every block's first name and a name from every 16th block, plus 200 names from the table.
    local probes = {}
    for index = 1, #table_file.firsts, 16 do
        table.insert(probes, table_file.firsts[index])
    end
    math.randomseed(1)
    for _ = 1, math.min(200, #all_names) do
        table.insert(probes, all_names[math.random(#all_names)])
    end
    -- the controls go through the same comparisons, so the scan below checks them too
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
    -- The same names against the rungs' OWN indexes, scanned in ladder order: the table was merged from those files, so a wrong first
    -- rung in the merge, the blocks or the lookup shows here and not only where the table is compared with itself.
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
    -- Answered in SORTED order and printed back in the order asked: the table is blocks of consecutive names, so sorted lookups walk each
    -- block once, and a name asked twice is answered once.
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
            -- the rest are names, even when they start with a dash
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
