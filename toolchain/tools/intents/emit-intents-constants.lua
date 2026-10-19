import("core.base.json")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

local HEADER = [==[
#import <Intents/Intents.h>

// %d %s, the %s names first exported in that release, and nothing else: a name
// this file does not define is a name the corpus's gate asks for and the link cannot find, so the
// list below is the whole of this file's claim and the registry names each one of them.
//
// Every value was read out of the host's own Intents at runtime - dlsym over
// /System/Library/Frameworks/Intents.framework, the NSString *const dereferenced once - and the
// differential in tests/backports/host/intents/constants reads the same table out of two builds:
// Apple's framework on its own, and this file beside it in one binary with the names renamed.
//
// The object is split by the release each name first appears in, not by a version string:
// backports.lua's band() raises on an object mixing a name a band already exports with one it
// does not, and a single-band 6.1.3 gate cannot see it.  AVFoundation's metadata key-space
// objects are split the same way.
//
// The ledger's reason for every one of these, which is what this slice answers:
// "declared extern in the lifted headers and there is no such symbol in the built libraries or
// the 6.1.3 cache -- the port has to export it".
]==]

local function rung_of(text)
    local parts = {}
    for part in text:gmatch("[^%.]+") do
        table.insert(parts, math.tointeger(tonumber(part)))
    end
    return parts
end

local function rung_less(a, b)
    for index = 1, math.max(#a, #b) do
        if a[index] == nil then
            return true
        elseif b[index] == nil then
            return false
        elseif a[index] ~= b[index] then
            return a[index] < b[index]
        end
    end
    return false
end

local function rung_text(rung)
    local parts = {}
    for _, part in ipairs(rung) do
        table.insert(parts, tostring(part))
    end
    return table.concat(parts, ".")
end

local function rung_key(rung)
    local parts = {}
    for _, part in ipairs(rung) do
        table.insert(parts, tostring(part))
    end
    return table.concat(parts, "_")
end

local function read_ledger(file)
    local rows = {}
    local columns = nil
    for line in io.lines(file) do
        local cells = {}
        for cell in (line .. "\t"):gmatch("([^\t]*)\t") do
            table.insert(cells, cell)
        end
        if columns == nil then
            columns = cells
        elseif #cells > 0 and not (#cells == 1 and cells[1] == "") then
            local row = {}
            for index, name in ipairs(columns) do
                row[name] = cells[index] or ""
            end
            table.insert(rows, row)
        end
    end
    return rows
end

local function measured_rungs(path)
    local out = {}
    if path == nil then
        return out
    end
    for line in io.readfile(path, {encoding = "binary"}):gmatch("[^\n]+") do
        local cells = {}
        for cell in (line .. "\t"):gmatch("([^\t]*)\t") do
            table.insert(cells, cell)
        end
        if #cells == 3 and cells[2]:sub(1, 1) == "_" and cells[2] ~= "_MIXED-RELEASES" then
            out[cells[2]:sub(2)] = cells[3]
        elseif #cells == 2 and cells[1] ~= "symbol" then
            out[cells[1]] = cells[2]
        end
    end
    return out
end

function main(ledger, values_path, outdir, measured_path)
    local raw = io.readfile(ledger, {encoding = "binary"})
    if raw:find('"', 1, true) then
        raise("the ledger has a quote character in it, which this reader does not implement: %s", ledger)
    end
    local values = json.decode(io.readfile(values_path, {encoding = "binary"}))
    local measured = measured_rungs(measured_path)

    local wanted = {}
    for _, row in ipairs(read_ledger(ledger)) do
        if row.kind == "constant" and row.status == "missing" and row.needs:find("code", 1, true) then
            table.insert(wanted, row)
        end
    end

    local missing = {}
    for _, row in ipairs(wanted) do
        if values[row.api] == nil then
            table.insert(missing, row.api)
        end
    end
    if #missing > 0 then
        byteorder.sort(missing)
        for _, name in ipairs(missing) do
            print("refusing: " .. name .. " has no value in the host dump")
        end
        return 1
    end

    local by_rung, rungs = {}, {}
    for _, row in ipairs(wanted) do
        local rung = rung_of(measured[row.api] or row.introduced)
        local key = rung_key(rung)
        if by_rung[key] == nil then
            by_rung[key] = {rung = rung, rows = {}}
            table.insert(rungs, by_rung[key])
        end
        table.insert(by_rung[key].rows, row)
    end
    for index = 2, #rungs do
        local group = rungs[index]
        local at = index - 1
        while at >= 1 and rung_less(group.rung, rungs[at].rung) do
            rungs[at + 1] = rungs[at]
            at = at - 1
        end
        rungs[at + 1] = group
    end

    local written = {}
    for _, group in ipairs(rungs) do
        local rows = group.rows
        table.sort(rows, function(a, b) return byteorder.less(a.api, b.api) end)
        local name = "IntentsConstants" .. rung_key(group.rung) .. ".m"
        local body = {string.format(HEADER, #rows, "constants", rung_text(group.rung))}
        table.insert(body, "")
        for _, row in ipairs(rows) do
            local value = values[row.api]
            if value:find("\n", 1, true) or value:find('"', 1, true) then
                print(string.format("refusing: the value of %s has a quote or a newline in it: %q", row.api, value))
                return 1
            end
            table.insert(body, string.format('NSString *const %s = @"%s";', row.api, value))
        end
        io.writefile(path.join(outdir, name), table.concat(body, "\n") .. "\n", {encoding = "binary"})
        table.insert(written, {name = name, count = #rows, rung = rung_text(group.rung)})
    end

    local manifest_entries = {}
    for _, row in ipairs(wanted) do
        manifest_entries[row.api] = {introduced = row.introduced, rung = rung_text(rung_of(measured[row.api] or row.introduced))}
    end
    local manifest_path = path.join(os.scriptdir(), "constants.json")
    io.writefile(manifest_path, manifest_text(manifest_entries), {encoding = "binary"})
    print(string.format("  manifest %s (%d names)", manifest_path, #wanted))

    local total = 0
    for _, file in ipairs(written) do
        print(string.format("  %-28s %2d constants (first exported in %s)", file.name, file.count, file.rung))
        total = total + file.count
    end
    print(string.format("  %d files, %d constants", #written, total))
    return 0
end

function manifest_text(entries)
    local names = {}
    for name in pairs(entries) do
        table.insert(names, name)
    end
    byteorder.sort(names)
    local lines = {}
    for _, name in ipairs(names) do
        local entry = entries[name]
        table.insert(lines, string.format('    "%s": {\n      "introduced": "%s",\n      "rung": "%s"\n    }',
                                          name, entry.introduced, entry.rung))
    end
    local constants = "{}"
    if #lines > 0 then
        constants = "{\n" .. table.concat(lines, ",\n") .. "\n  }"
    end
    local note = "the extern Intents constants this package DEFINES and exports, with the release each first "
        .. "appears in; gen-registry.py reads this so a regeneration does not drop their rows"
    return "{\n  \"constants\": " .. constants .. ",\n  \"note\": \"" .. note .. "\",\n"
        .. "  \"source\": \"tools/intents/emit-intents-constants.lua\"\n}\n"
end
