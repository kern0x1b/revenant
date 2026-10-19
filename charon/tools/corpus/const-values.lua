import("core.base.json")

local common = import("values_common", {rootdir = os.scriptdir(), anonymous = true})
local values_const = import("values_const", {rootdir = os.scriptdir(), anonymous = true})
local tsv = import("tsv", {rootdir = os.scriptdir(), anonymous = true})
local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})
local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})

local OPTIONS = {
    {name = "index-dir", required = true},
    {name = "surface"},
    {name = "caches", required = true},
    {name = "out", required = true},
    {name = "oracle-cache", required = true},
    {name = "only"},
}

local note = common.note

local function load_surface(file)
    local rows, header = {}, nil
    for line in io.lines(file) do
        local fields = tsv.split(line)
        if not header then
            header = fields
        else
            local row = {}
            for index, name in ipairs(header) do
                row[name] = fields[index]
            end
            table.insert(rows, row)
        end
    end
    return rows
end

local function sorted_keys(map)
    return byteorder.keys(map)
end

local function sorted_list(items)
    local out = table.join(items)
    byteorder.sort(out)
    return out
end

local function minutes(started)
    return (os.mclock() - started) / 60000.0
end

local function exported_constants(rows, index_dir, only)
    if only then
        local allowed = {}
        for _, name in ipairs(common.split(only, ",")) do
            allowed[name] = true
        end
        local kept = {}
        for _, row in ipairs(rows) do
            if allowed[row.framework] then
                table.insert(kept, row)
            end
        end
        rows = kept
    end
    local wanted, frameworks = {}, {}
    local total = 0
    for _, row in ipairs(rows) do
        if row.lang == "objc" and row.kind == "constant" then
            if not wanted[row.framework] then
                wanted[row.framework] = {}
                table.insert(frameworks, row.framework)
            end
            if not wanted[row.framework][row.api] then
                wanted[row.framework][row.api] = true
                total = total + 1
            end
        end
    end
    local indexes, read = {}, 0
    for _, framework in ipairs(frameworks) do
        local file = path.join(index_dir, (framework:gsub("/", "_")) .. ".json")
        if os.exists(file) then
            local index, failure = json.loadfile(file)
            if index == nil then
                raise("const-values.lua: %s is not JSON: %s", file, tostring(failure))
            end
            indexes[framework] = index
            read = read + 1
        end
    end
    note(string.format("%d frameworks, %d constant rows, %d header indexes read", #frameworks, total, read))
    local constants = {}
    for _, framework in ipairs(frameworks) do
        local index = indexes[framework]
        if index and index.flags ~= nil then
            for name in pairs(wanted[framework]) do
                local flags = index.flags[name]
                if common.present(flags) then
                    local is_extern, is_static = flags[1], flags[2]
                    if is_extern or not is_static then
                        local width, pointer, text, resolved = values_const.classify(flags[4], flags[5], index.typedefs or {})
                        if constants[name] == nil then
                            constants[name] = {framework = framework, declared = flags[4], ctype = resolved, width = width, pointer = pointer, text = text}
                        end
                    end
                end
            end
        end
    end
    return constants
end

local function summarise_constants(constants)
    local fixed, abi, abi_pointer, opaque, total = 0, 0, 0, 0, 0
    for _, c in pairs(constants) do
        total = total + 1
        if not (c.width == "p" or (c.width == 0 and not c.pointer)) then
            fixed = fixed + 1
        end
        if c.width == "p" then
            abi = abi + 1
            if c.pointer then
                abi_pointer = abi_pointer + 1
            end
        end
        if c.width == 0 and not c.pointer then
            opaque = opaque + 1
        end
    end
    note(string.format("%d exported constants: %d read at the width their own type declares, %d a type whose size is the ABI's -- read at the cache's pointer size, %d of those a pointer -- and %d a type that is neither a scalar nor a pointer (a struct or an array), from which nothing is read",
                       total, fixed, abi, abi_pointer, opaque))
end

local function with_release(release, value)
    local out = table.copy(value)
    out.release = release
    return out
end

function main(...)
    local args = common.parse_args("const-values.lua", OPTIONS, {...})
    local started = os.mclock()
    local charon_root = os.getenv("CHARON_ROOT") or workspace.root()
    local scratch = workspace.fresh("const-values")
    local surface = args.surface or workspace.corpus("sdk-26.2-surface.tsv")

    local constants = exported_constants(load_surface(surface), args["index-dir"], args.only)
    summarise_constants(constants)

    local function symbols(names)
        local out = {}
        for _, name in ipairs(names) do
            local c = constants[name]
            table.insert(out, {name, c.width, c.pointer, c.text})
        end
        return out
    end

    local strings = {}
    for name, c in pairs(constants) do
        if c.pointer and c.text then
            table.insert(strings, name)
        end
    end
    byteorder.sort(strings)
    local reference = values_const.read_cache(args["oracle-cache"], symbols(strings), scratch, charon_root)
    local pairs_given = common.split(args.caches, ",")
    local release_of = {}
    for _, pair in ipairs(pairs_given) do
        if pair:find("=", 1, true) then
            local release, _, cachefile = common.partition(pair, "=")
            release_of[cachefile] = release
        end
    end
    local reference_release = release_of[common.realpath(args["oracle-cache"])] or args["oracle-cache"]
    local oracle = {}
    for name, value in pairs(reference) do
        if value.text == name then
            table.insert(oracle, name)
        end
    end
    byteorder.sort(oracle)
    if #oracle == 0 then
        note(string.format("no constant string in %s reads back as its own name, so the reader cannot be checked here; refusing to write values", args["oracle-cache"]))
        os.tryrm(scratch)
        raise("const-values.lua: no oracle on this machine. Re-run with --oracle-cache naming a cache the reader handles (a 32-bit one).")
    end
    local step = math.max(1, #oracle // values_const.oracle_sample())
    local sample = {}
    for index = 1, #oracle, step do
        if #sample < values_const.oracle_sample() then
            table.insert(sample, oracle[index])
        end
    end
    local function first_four()
        return table.concat(table.slice(sample, 1, 4), ", ") .. (#sample > 4 and ", ..." or "")
    end
    note(string.format("oracle: %d of %d constant strings read back as their own name on %s; %d of them are checked on every cache (%s)",
                       #oracle, #strings, args["oracle-cache"], #sample, first_four()))

    local resolved, searched, refused, differed = {}, {}, {}, {}
    local abi_set = {}
    for name, c in pairs(constants) do
        if c.width == "p" and not c.pointer then
            abi_set[name] = true
        end
    end
    local abi_reads = {}
    local verdicts, unchecked = {}, {}
    local oracle_symbols = {}
    for _, name in ipairs(oracle) do
        table.insert(oracle_symbols, {name, "p", true, true})
    end
    for _, pair in ipairs(pairs_given) do
        local release, _, cachefile = common.partition(pair, "=")
        if cachefile == "" or not os.exists(cachefile) then
            note(string.format("  %s: no cache at %s, skipped", release, cachefile))
            table.insert(searched, release)
        else
            local left, left_set = {}, {}
            for name in pairs(constants) do
                if resolved[name] == nil then
                    table.insert(left, name)
                    left_set[name] = true
                end
            end
            if #left == 0 then
                break
            end
            note(string.format("  %s: reading %d symbols from %s", release, #left, path.filename(cachefile)))
            local ask = table.copy(left_set)
            for name in pairs(abi_set) do
                ask[name] = true
            end
            local batch = symbols(sorted_keys(ask))
            local probe, abi = values_const.read_cache(cachefile, oracle_symbols, scratch, charon_root)
            local present = sorted_keys(probe)
            local agreed, agreed_set, changed, changed_count = {}, {}, {}, 0
            for _, name in ipairs(present) do
                if probe[name].text == reference[name].text then
                    table.insert(agreed, name)
                    agreed_set[name] = true
                end
            end
            for _, name in ipairs(present) do
                if not agreed_set[name] then
                    changed[name] = probe[name].text
                    changed_count = changed_count + 1
                end
            end
            if #present > 0 and #agreed == 0 then
                table.insert(refused, string.format("%s (%s: reproduces none of the %d checked constants it holds)", release, abi, #present))
                note(string.format("    %s (%s): the reader reproduces none of the %d checked constants it holds, so no value is taken from it", release, abi, #present))
                table.insert(searched, release)
            elseif #present == 0 then
                table.insert(unchecked, {release = release, cachefile = cachefile, batch = batch, abi = abi})
                note(string.format("    %s (%s): holds none of the %d checked constants -- unchecked for now, and it takes the verdict of a checked %s cache or none",
                                   release, abi, #oracle, abi))
                table.insert(searched, release)
            else
                note(string.format("    %s (%s): reader reproduces %d of the %d checked constants it holds%s", release, abi, #agreed, #present,
                                   changed_count > 0 and string.format(", %d differ from %s and are flagged", changed_count, path.filename(args["oracle-cache"])) or ""))
                if verdicts[abi] == nil then
                    verdicts[abi] = {release = release, agreed = #agreed, present = #present}
                end
                local values = values_const.read_cache(cachefile, batch, scratch, charon_root)
                local found = 0
                for _, name in ipairs(sorted_keys(values)) do
                    local value = values[name]
                    found = found + 1
                    if abi_set[name] then
                        abi_reads[name] = abi_reads[name] or {}
                        table.insert(abi_reads[name], {release = release, value = value})
                    end
                    if left_set[name] then
                        resolved[name] = with_release(release, value)
                    end
                end
                for name, text in pairs(changed) do
                    differed[name] = text
                end
                note(string.format("    %d of %d symbols are in this release", found, #left))
                table.insert(searched, release)
            end
        end
    end

    for _, pending in ipairs(unchecked) do
        local verdict = verdicts[pending.abi]
        if not verdict then
            table.insert(refused, string.format("%s (%s: unchecked, and no %s cache was checked to inherit from)", pending.release, pending.abi, pending.abi))
            note(string.format("    %s (%s): no %s cache was checked, so this one is refused", pending.release, pending.abi, pending.abi))
        else
            local values = values_const.read_cache(pending.cachefile, pending.batch, scratch, charon_root)
            local found = 0
            for name, value in pairs(values) do
                found = found + 1
                if resolved[name] == nil then
                    resolved[name] = with_release(pending.release, value)
                end
            end
            note(string.format("    %s (%s): takes %s's verdict (reproduced %d of %d checked constants) -- %d symbols",
                               pending.release, pending.abi, verdict.release, verdict.agreed, verdict.present, found))
        end
    end

    local agreed_with = {}
    local incomparable, other_width, differing, comparable = {}, {}, {}, {}
    for name, mine in pairs(resolved) do
        local row = abi_set[name] and constants[name] or nil
        if row and not values_const.sentinel_reason(row.ctype, row.declared, mine.width, mine.storage, mine.u32, mine.f64) then
            local mine_value = values_const.format_value(row.ctype, mine.width, mine.pointer, mine.text, mine.u32, mine.u64, mine.f64, mine.hexed)
            for _, read in ipairs(abi_reads[name] or {}) do
                local theirs = read.value
                if read.release ~= mine.release and common.present(theirs.hexed) and theirs.hexed ~= "-" then
                    if values_const.sentinel_reason(row.ctype, row.declared, theirs.width, theirs.storage, theirs.u32, theirs.f64) then
                        incomparable[name] = incomparable[name] or {}
                        table.insert(incomparable[name], read.release)
                    else
                        local other = values_const.format_value(row.ctype, theirs.width, theirs.pointer, theirs.text, theirs.u32, theirs.u64,
                                                                theirs.f64, theirs.hexed)
                        if theirs.width ~= mine.width then
                            other_width[name] = other_width[name] or {}
                            table.insert(other_width[name], read.release)
                        elseif other ~= "" and mine_value ~= "" then
                            comparable[name] = true
                            if other == mine_value then
                                agreed_with[name] = (agreed_with[name] or 0) + 1
                            else
                                differing[name] = differing[name] or {}
                                table.insert(differing[name], {release = read.release, other = other, mine = mine_value})
                            end
                        end
                    end
                end
            end
        end
    end
    local abi_total, uncorroborated = 0, {}
    for name in pairs(abi_set) do
        abi_total = abi_total + 1
        if resolved[name] ~= nil and (agreed_with[name] or 0) == 0 then
            table.insert(uncorroborated, name)
        end
    end
    byteorder.sort(uncorroborated)
    local differing_names = sorted_keys(differing)
    local differing_text = {}
    for index = 1, math.min(3, #differing_names) do
        local name = differing_names[index]
        local first = differing[name][1]
        table.insert(differing_text, string.format("%s %s != %s", name, first.mine, first.other))
    end
    note(string.format("ABI-width reads: %d in all, %d corroborated by a same-width reading in another cache. %d of the %d had a second reading at the same width that produced a value to compare with, so %d is the most any of them could reach on this machine. Of the rest: %d are only in releases of the other ABI, where the same type is a different width, and %d have a second reading whose own slot is narrower than the width read. %d disagreed where they could be compared (%s).",
                       abi_total, abi_total - #uncorroborated, common.count(comparable), abi_total,
                       math.max(common.count(comparable), abi_total - #uncorroborated), common.count(other_width),
                       common.count(incomparable), common.count(differing),
                       #differing_text > 0 and table.concat(differing_text, "; ") or "none"))

    os.mkdir(args.out)
    local file = path.join(args.out, "exported-constants.tsv")
    local kinds, kind_order = {}, {}
    local lines = {"framework\tapi\tc-type\tvalue\tfrom-release\tstatus\tdetail\tinstall\taddress\traw-bytes\tint32\tint64\tdouble\twidth\tstorage\tagreed-in-caches\n"}
    local read_count, none_count = 0, 0
    local names = sorted_keys(constants)
    for _, name in ipairs(names) do
        local c = constants[name]
        local value, detail, status
        local release, install, address, hexed, u32, u64, f64, read_width, storage = "", "", "", "", "", "", "", "", ""
        local hit = resolved[name]
        if hit then
            release, install, address, hexed = hit.release, hit.install, hit.address, hit.hexed
            u32, u64, f64, read_width, storage = hit.u32, hit.u64, hit.f64, hit.width, hit.storage
            if not common.present(hexed) or hexed == "-" then
                if common.present(read_width) and common.present(storage) and read_width > storage then
                    status = "read-too-wide"
                    detail = string.format("the symbol's own storage is %d bytes (the distance to the next export in the same image) and its type would be read at %d, so no value is read: this release stores it in less space than its type claims, and the bytes past its end belong to the next symbol",
                                           storage, read_width)
                else
                    status = "read"
                    detail = string.format("the declared type is neither a scalar nor a pointer (%s): the symbol is at %s in this release, and no fixed-width read of it would be this constant's value",
                                           c.ctype, address)
                end
                value = ""
            else
                value, detail = values_const.format_value(c.ctype, read_width, c.pointer, hit.text, u32, u64, f64, hexed)
                status = "read"
                local sentinel, why = values_const.sentinel_reason(c.ctype, c.declared, read_width, storage, u32, f64)
                if sentinel then
                    status = sentinel
                    detail = string.format("%s; %s, and the raw bytes are %s", detail, why, hexed)
                    value = hexed
                end
            end
            if differed[name] ~= nil then
                status = "read-changed"
                detail = detail .. string.format("; this release's value differs from the one %s measured for the same symbol (%s), so it is a real difference in the API and not this reader",
                                                 reference_release, values_const.repr(reference[name].text))
            end
        else
            value, detail, status = "", "no release on this machine has it", "no-release"
        end
        local key = status .. "\0" .. detail:match("^[^:]*")
        if kinds[key] == nil then
            kinds[key] = 0
            table.insert(kind_order, {key = key, status = status, detail = detail:match("^[^:]*")})
        end
        kinds[key] = kinds[key] + 1
        if status == "read" then
            read_count = read_count + 1
        elseif status == "no-release" then
            none_count = none_count + 1
        end
        local agreed = ""
        if abi_set[name] then
            agreed = tostring(agreed_with[name] or 0)
        end
        table.insert(lines, table.concat({c.framework, name, string.format("%s (declared %s)", c.ctype, c.declared), value, release, status, detail,
                                          install, address, hexed, tostring(u32), tostring(u64), f64 ~= "" and values_const.repr(f64) or "",
                                          tostring(read_width), tostring(storage), agreed}, "\t") .. "\n")
    end
    io.writefile(file, table.concat(lines))
    note(string.format("wrote %s (%d rows, %.1f minutes)", file, #names, minutes(started)))

    for index, entry in ipairs(kind_order) do
        entry.count = kinds[entry.key]
        entry.index = index
    end
    table.sort(kind_order, function (a, b)
        if a.count ~= b.count then
            return a.count > b.count
        end
        return a.index < b.index
    end)
    local differed_count = common.count(differed)
    local verdict_text = {}
    for _, abi in ipairs(sorted_keys(verdicts)) do
        local v = verdicts[abi]
        table.insert(verdict_text, string.format("%s <- %s (%d of %d)", abi, v.release, v.agreed, v.present))
    end
    local summary = path.join(args.out, "EXPORTED-CONSTANTS.md")
    local out = {}
    table.insert(out, "# Exported Objective-C constants, with the values real releases shipped\n\n")
    table.insert(out, string.format("%d of the surface's `constant` rows are exported variables -- declared as a top-level variable in the lifted header, not an enum case, which is a different node in the header and carries its value in the header already. Every value below was read out of a dyld shared cache of a real release that has the symbol, oldest release first, through `tools/corpus/cache-value.lua` over the project's own cache reader. **No value here is invented, and none is taken from a header comment or from the host framework.**\n\n",
                                    #names))
    table.insert(out, string.format("Run: %.1f minutes. Caches read, oldest first: %s.\n\n", minutes(started), table.concat(searched, ", ")))
    if #refused > 0 then
        table.insert(out, string.format("Caches **refused**: %s -- the reader did not reproduce the checked constants there, so no value is taken from them (a wrong slide or chain rule reads a neighbouring object, which is worse than no value). Those constants are reported `no-release` even though the release has them.\n\n",
                                        table.concat(refused, ", ")))
    end
    table.insert(out, "| | rows |\n| --- | --- |\n")
    table.insert(out, string.format("| value read from a release | %d |\n", read_count + differed_count))
    table.insert(out, string.format("| no release on this machine has it | %d |\n", none_count))
    if differed_count > 0 then
        table.insert(out, string.format("| of those, a value that differs from the reference release's for the same symbol | %d |\n", differed_count))
    end
    table.insert(out, "\n## How the value was read\n\n| kind | rows |\n| --- | --- |\n")
    for _, entry in ipairs(kind_order) do
        table.insert(out, string.format("| %s: %s | %d |\n", entry.status, entry.detail, entry.count))
    end
    table.insert(out, "\n## What this does not cover\n\n")
    table.insert(out, "- A constant no cache on this machine holds is reported `no-release`, not filled in. The releases searched are listed above; a constant introduced after the newest of them needs that release's IPSW fetched before its value can be read.\n")
    table.insert(out, string.format("- Before a single value is taken from a cache, the reader has to reproduce, there, the %d measured constants whose value is their own name (%s). **A cache that reproduces none of the checked constants it holds is refused outright** and its values are not used; one that disagrees on some is used, with the disagreeing constants flagged one by one (`read-changed`, both values in the row) rather than the release thrown away. A cache that holds none of the checked constants cannot be checked in its own right, so it takes the verdict of a checked cache of the same architecture -- the reader's 32-bit and 64-bit paths are different code -- and is refused when no same-architecture cache was checked. Per architecture: %s. The list is measured on the reference cache (%s), not written down here.\n",
                                    #oracle, first_four(), #verdict_text > 0 and table.concat(verdict_text, ", ") or "nothing was checked",
                                    path.filename(args["oracle-cache"])))
    table.insert(out, string.format("- A `CGFloat`, `CFAbsoluteTime` or `long` is read at the **cache's** pointer width, because the header walk runs at armv7 where `CGFloat` is a 4-byte float. Nothing in the self-naming oracle exercises that width -- it covers constant strings only -- so every such row is read again from each other cache that has the symbol, and counts as corroborated only when a same-width reading there gives the same value. %d of those %d rows are corroborated; **%d are not**, and they are named in the `agreed-in-caches` column: %s.\n",
                                    abi_total - #uncorroborated, abi_total, #uncorroborated,
                                    #uncorroborated > 0 and table.concat(uncorroborated, ", ") or "none"))
    table.insert(out, string.format("  - %d of the %d not corroborated have no same-width reading to compare with: the other release that carries the symbol is a different ABI, where the same type is a different width -- a `CGFloat` is four bytes in an armv7 release and eight in an arm64e one, which is the whole reason these rows are read at the cache's width.\n",
                                    common.count(other_width), #uncorroborated))
    local incomparable_names = sorted_keys(incomparable)
    if #incomparable_names > 0 then
        table.insert(out, string.format("  - %d could not be compared because in the other release the symbol's own slot is narrower than the width read: %s. That is a fact about the two releases, not a failure of the reading.\n",
                                        #incomparable_names, table.concat(table.slice(incomparable_names, 1, 12), ", ") .. (#incomparable_names > 12 and ", ..." or "")))
    end
    if #differing_names > 0 then
        local shown = {}
        for index = 1, math.min(6, #differing_names) do
            local name = differing_names[index]
            local first = differing[name][1]
            table.insert(shown, string.format("%s: %s reads %s", name, first.release, first.other))
        end
        table.insert(out, string.format("  - %d had a same-width reading in another cache that **disagrees**, which is the one case that would mean a width is being read wrongly: %s.\n",
                                        #differing_names, table.concat(shown, "; ")))
    end
    table.insert(out, "- A `float`/`double` whose bytes are not a finite value, or whose four-byte half is not a finite float while the resolved type is `float`, is reported `read-sentinel` with its raw bytes rather than as a value: a release that initialises a constant to a placeholder ships something the reader is faithful to and that is not the constant's value. A read wider than the symbol's own storage -- the distance to the next export in the same image, which is in the `storage` column -- is refused as `read-too-wide` rather than assembled from the bytes past the symbol.\n")
    table.insert(out, "- The read is by symbol name, so a constant a release re-exported under a stub is credited to the image the export trie names; the install column says which.\n")
    table.insert(out, "- A value whose declared type is neither a scalar nor a pointer (an array, a function pointer, a typedef these headers do not resolve) is written as its raw bytes with the type named, not interpreted.\n")
    io.writefile(summary, table.concat(out))
    note("wrote " .. summary)
    os.tryrm(scratch)
end
