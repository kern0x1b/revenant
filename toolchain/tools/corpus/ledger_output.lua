local HERE = os.scriptdir()
local byteorder = import("byteorder", {rootdir = path.join(HERE, "..", "..", "modules"), anonymous = true})
local ledger_inputs = import("ledger_inputs", {rootdir = HERE, anonymous = true})
local ledger_classify = import("ledger_classify", {rootdir = HERE, anonymous = true})

local TOOL = "api-ledger.lua"
local WALK = "surface_walk.lua"
local VALUES = "const-values.lua"
local TARGET = ledger_classify.target()

local Counter = {}

function counter()
    local made = {counts = {}, order = {}}
    for name, method in pairs(Counter) do
        made[name] = method
    end
    return made
end

function Counter:add(key, count)
    if self.counts[key] == nil then
        self.counts[key] = 0
        table.insert(self.order, key)
    end
    self.counts[key] = self.counts[key] + (count or 1)
end

function Counter:set(key, count)
    if self.counts[key] == nil then
        table.insert(self.order, key)
    end
    self.counts[key] = count
end

function Counter:get(key)
    return self.counts[key] or 0
end

function Counter:pop(key)
    local count = self.counts[key]
    if count == nil then
        return 0
    end
    self.counts[key] = nil
    for index, held in ipairs(self.order) do
        if held == key then
            table.remove(self.order, index)
            break
        end
    end
    return count
end

function Counter:total()
    local sum = 0
    for _, key in ipairs(self.order) do
        sum = sum + self.counts[key]
    end
    return sum
end

function Counter:size()
    return #self.order
end

function Counter:items()
    local out = {}
    for _, key in ipairs(self.order) do
        table.insert(out, {key, self.counts[key]})
    end
    return out
end

function stable_sort(list, less)
    local indexed = {}
    for index, item in ipairs(list) do
        indexed[index] = {item, index}
    end
    table.sort(indexed, function (a, b)
        if less(a[1], b[1]) then
            return true
        end
        if less(b[1], a[1]) then
            return false
        end
        return a[2] < b[2]
    end)
    for index, pair in ipairs(indexed) do
        list[index] = pair[1]
    end
    return list
end

function Counter:most_common()
    return stable_sort(self:items(), function (a, b)
        return a[2] > b[2]
    end)
end

local function round_half_even(value)
    local floor = math.floor(value)
    local fraction = value - floor
    if fraction > 0.5 or (fraction == 0.5 and floor % 2 == 1) then
        return floor + 1
    end
    return floor
end

local function sorted_strings(list)
    byteorder.sort(list)
    return list
end

local function file_name(framework)
    return (framework:gsub("/", "_"))
end

local function plain_replace(text, old, new)
    local out, from = {}, 1
    while true do
        local at = text:find(old, from, true)
        if not at then
            table.insert(out, text:sub(from))
            return table.concat(out)
        end
        table.insert(out, text:sub(from, at - 1))
        table.insert(out, new)
        from = at + #old
    end
end

function write_todo(file, entries, release)
    local order = {missing = 0, undecided = 1, unmeasured = 2}
    local todo = {}
    for _, entry in ipairs(entries) do
        if entry[2] ~= "implemented" then
            table.insert(todo, entry)
        end
    end
    stable_sort(todo, function (a, b)
        local x, y = order[a[2]] or 9, order[b[2]] or 9
        if x ~= y then
            return x < y
        end
        if a[1].kind ~= b[1].kind then
            return byteorder.less(a[1].kind, b[1].kind)
        end
        return byteorder.less(a[1].api, b[1].api)
    end)
    local lines = {"kind\tlang\tapi\tintroduced\theader-introduced\tstatus\tneeds\treason\n"}
    for _, entry in ipairs(todo) do
        local row, status, reason, introduced, needs = entry[1], entry[2], entry[3], entry[4], entry[5]
        table.insert(lines, table.concat({row.kind, row.lang, row.api, row.introduced or "", ledger_classify.show_introduced(introduced), status,
                                          ledger_classify.what_this_row_needs(status, introduced, release, needs), reason}, "\t") .. "\n")
    end
    io.writefile(file, table.concat(lines))
end

function write_output(results, args, elapsed, indexes, walked, header_seconds, swift)
    local release = args.release
    local by_framework, framework_order = {}, {}
    local totals = counter()
    local by_kind = {}
    local needs_totals = counter()
    for _, entry in ipairs(results) do
        local row, status = entry[1], entry[2]
        if by_framework[row.framework] == nil then
            by_framework[row.framework] = {}
            table.insert(framework_order, row.framework)
        end
        table.insert(by_framework[row.framework], entry)
        totals:add(status)
        local kind = row.lang .. "/" .. row.kind
        by_kind[kind] = by_kind[kind] or counter()
        by_kind[kind]:add(status)
        needs_totals:add(ledger_classify.what_this_row_needs(status, entry[4], release, entry[5]))
    end
    local frameworks = sorted_strings(table.copy(framework_order))
    local written = 0
    for _, framework in ipairs(frameworks) do
        written = written + 1
        write_todo(path.join(args.out, file_name(framework) .. ".tsv"), by_framework[framework], release)
    end

    local not_ios = totals:pop("not-ios")
    local not_ios_by_fw = counter()
    local not_ios_rows = {}
    local by_framework_all = {}
    for _, framework in ipairs(framework_order) do
        local entries = by_framework[framework]
        by_framework_all[framework] = entries
        local kept, gone = {}, {}
        for _, entry in ipairs(entries) do
            if entry[2] ~= "not-ios" then
                table.insert(kept, entry)
            else
                table.insert(gone, {entry[1], entry[2]})
            end
        end
        by_framework[framework] = kept
        not_ios_by_fw:set(framework, #gone)
        not_ios_rows[framework] = gone
    end
    local total = totals:total()
    local measured = total - totals:get("unmeasured")
    local indexed = {}
    for framework in pairs(indexes) do
        table.insert(indexed, framework)
    end
    sorted_strings(indexed)

    local out = {}
    local function write(text)
        table.insert(out, text)
    end
    write(string.format("# API ledger -- measured status of the SDK 26.2 surface at iOS %s\n\n", release))
    write(string.format("Every row of `coordination/corpus/sdk-26.2-surface.tsv` (%d rows, %d frameworks) gets a status read from built artifacts. Nothing is read from the registry: the registry is what this checks.\n\n",
                        total, #framework_order))
    write(string.format("Run: **%.1f minutes** end to end (%d s) over %d jobs, of which the header pass over %d frameworks took %.1f s -- %d walked from scratch, %d read from the per-framework cache. The cache is keyed by the SDK, the target and the overlay's mtime, so a run over inputs already walked costs only the two cache reads (the release's dyld cache and the built libraries, a few seconds) and a run over a new lift overlay pays the walk again.\n\n",
                        elapsed / 60.0, round_half_even(elapsed), args.jobs, #indexed, header_seconds, walked, #indexed - walked))
    write("Three kinds of status, and they are not all measured the same way. **`implemented` and `missing` are measured from built artifacts** -- a build of main's libraries, the release's own caches, the armv7 Swift modules -- and nothing else. **`decided` is a decision somebody took and recorded**: a registry entry that says `absent`, `inert` or `ignored`, with the reason it was taken, in the row. It is kept as its own status and its own column precisely because it is not a measurement, and it is the only status in this file that rests on a registry. `header-ok` is the generated-unit test: a translation unit naming the row compiles for the release.\n\n")
    write("| what | where |\n| --- | --- |\n")
    write(string.format("| built %s libraries | `%s` |\n", release, ledger_inputs.short(args.gate)))
    local tree = ledger_inputs.built_tree(args.gate)
    if tree and tree ~= "" then
        write(string.format("| the tree those libraries were built from | %s |\n", tree))
    end
    write(string.format("| the release's own cache | `%s` |\n", ledger_inputs.short(args.release_cache)))
    write(string.format("| real 26.2 SDK | `%s` |\n", plain_replace(ledger_inputs.short((args.sdk:gsub("/+$", ""))), "$HOME/.agent-work/sdk-26.2/", "")))
    write(string.format("| lift overlay | `%s` (mtime %d) |\n", path.filename(args.vfs), os.mtime(args.vfs)))
    write(string.format("| header target | `%s` |\n", TARGET))
    write(string.format("| tool | `toolchain/tools/corpus/%s`, header walk by `tools/corpus/%s` |\n\n", TOOL, WALK))
    write(string.format("Reproduce (the per-framework header walk is cached under `--cache-dir`, keyed by the SDK, the target and the overlay's mtime, so the first run over new inputs is the expensive one and every run after it is cheap):\n\n```\n%s build \\\n  --surface %s \\\n  --gate %s \\\n  --release %s --release-cache %s \\\n  --sdk %s \\\n  --vfs %s \\\n  --cache-dir <dir> --out <dir> --jobs %d\n```\n\n",
                        TOOL, ledger_inputs.short(args.surface), ledger_inputs.short(args.gate), release, ledger_inputs.short(args.release_cache),
                        ledger_inputs.short(args.sdk), ledger_inputs.short(args.vfs), args.jobs))
    write(string.format("## What each status means\n\n- **implemented** -- a built apple-backports dylib of the %s gate carries it, or the release's own %s cache does: the class/method/property is in its ObjC metadata, or the linker symbol is exported. A row the release already ships counts -- it works on the release.\n- **declared** -- a Swift package's own registry records the row `implemented` and no built armv7 module for it was found on this machine to check it against. It counts as not missing, and `needs=build` is what is left: build the module and let the pass read it. Objective-C rows never read a registry, so this is the only status that rests on one.\n- **header-ok** -- header-only (a type, an enum case, a `static`/`inline` function), declared in the lifted headers with no iOS availability gating it past %s. No code is needed once the lift has lowered it.\n- **missing** -- measured as not there: no class, no selector, no symbol; or a declaration the lift still marks `API_AVAILABLE(ios(>6.1))`; or an `extern` constant or function with no symbol anywhere, which the port has to export.\n- **undecided** -- the tool cannot place the row and says why. Never a guess.\n- **unmeasured** -- Swift-only row, and no Swift pass was given.\n\n",
                        release, release, release))
    write("## Totals\n\n| status | rows |\n| --- | --- |\n")
    for _, pair in ipairs(totals:most_common()) do
        write(string.format("| %s | %d |\n", pair[1], pair[2]))
    end
    write(string.format("| **total** | **%d** |\n\n", total))
    write(string.format("Every row is placed by a measurement: **%d** of %d carry a status this run decided, and the %d that do not are `undecided` with the reason in their row.\n\n",
                        measured, total, totals:get("undecided")))
    write(string.format("**%d rows leave the denominator**: the SDK marks them `API_UNAVAILABLE(ios)`, so they are tvOS's or visionOS's declarations and there is no iOS API in them to implement. The surface keeps them (it is one file, and the %d rows of it are the whole corpus every other band works from), so they are named here rather than deleted. The denominator below is %d.\n\n",
                        not_ios, total + not_ios, total))
    if not_ios_by_fw:size() > 0 then
        local holding = {}
        for _, pair in ipairs(stable_sort(not_ios_by_fw:items(), function (a, b) return a[2] > b[2] end)) do
            table.insert(holding, string.format("%s %d", pair[1], pair[2]))
        end
        write(string.format("Frameworks holding them: %s.\n\n", table.concat(holding, ", ")))
    end
    write(string.format("## What each row needs\n\nA row is not only done or not: `needs` in the per-framework todo files says what has to happen. `lift` means the declaration is there and the generated unit that names it compiles for %s, but the lifted header still carries `API_AVAILABLE(ios(>6.1))` -- the lift band lowers it, no code is needed.\n\n| needs | rows |\n| --- | --- |\n",
                        release))
    for _, pair in ipairs(needs_totals:most_common()) do
        write(string.format("| %s | %d |\n", pair[1], pair[2]))
    end
    write("\n")
    local per_fw = {}
    local status_set = {}
    for _, key in ipairs(totals.order) do
        status_set[key] = true
    end
    for _, counters in pairs(by_kind) do
        for _, key in ipairs(counters.order) do
            status_set[key] = true
        end
    end
    for framework, entries in pairs(by_framework_all) do
        local counts = counter()
        for _, entry in ipairs(entries) do
            counts:add(entry[2])
            status_set[entry[2]] = true
        end
        per_fw[framework] = counts
    end
    local statuses = sorted_strings(table.keys(status_set))
    local dashes = {}
    for _ in ipairs(statuses) do
        table.insert(dashes, "---")
    end
    local function cells(counts)
        local values = {}
        for _, status in ipairs(statuses) do
            table.insert(values, tostring(counts:get(status)))
        end
        return table.concat(values, " | ")
    end
    write(string.format("## By kind\n\n| kind | %s | total |\n| --- | %s | --- |\n", table.concat(statuses, " | "), table.concat(dashes, " | ")))
    for _, kind in ipairs(sorted_strings(table.keys(by_kind))) do
        write(string.format("| %s | %s | %d |\n", kind, cells(by_kind[kind]), by_kind[kind]:total()))
    end
    write(string.format("\n## By framework\n\n| framework | rows | %s | todo file |\n| --- | --- | %s | --- |\n", table.concat(statuses, " | "), table.concat(dashes, " | ")))
    for _, framework in ipairs(frameworks) do
        local counts = per_fw[framework]
        write(string.format("| %s | %d | %s | `%s` |\n", framework, counts:total(), cells(counts), file_name(framework) .. ".tsv"))
    end
    local empty = {}
    for _, framework in ipairs(frameworks) do
        local all = true
        for _, entry in ipairs(by_framework[framework]) do
            if entry[2] ~= "implemented" then
                all = false
                break
            end
        end
        if all then
            table.insert(empty, framework)
        end
    end
    local unreadable, partial = {}, {}
    for _, framework in ipairs(indexed) do
        local index = indexes[framework]
        if index.error ~= nil then
            table.insert(unreadable, framework)
        end
        if index.failed and #index.failed > 0 then
            table.insert(partial, string.format("%s (%d headers)", framework, #index.failed))
        end
    end
    write("\n## Caveats, and what this run does not measure\n\n")
    if #unreadable > 0 then
        write(string.format("- %d frameworks the header walk could not read at all, so every row of theirs is `undecided`: %s.\n", #unreadable,
                            table.concat(unreadable, ", ")))
    end
    if #empty > 0 then
        write(string.format("- %d frameworks have no row left to do (%s); their todo file exists and is empty, which is the whole of their status.\n",
                            #empty, table.concat(empty, ", ")))
    end
    if #partial > 0 then
        write(string.format("- %d frameworks where clang rejected at least one header, so the walk fell back to one translation unit per header; their counts are lower bounds, not complete: %s.\n",
                            #partial, table.concat(partial, "; ")))
    end
    local lifted_all = ledger_inputs.lifted_frameworks(args.vfs)
    local lifted, lifted_indexed = 0, 0
    for _, framework in ipairs(framework_order) do
        if lifted_all[framework] then
            lifted = lifted + 1
        end
    end
    for _, framework in ipairs(indexed) do
        if lifted_all[framework] and by_framework[framework] then
            lifted_indexed = lifted_indexed + 1
        end
    end
    write(string.format("- The lift's header tree holds %d of the %d frameworks walked, so for the other %d a post-%s declaration still carries its original `API_AVAILABLE`. Naming such a declaration compiles all the same, so those rows are `header-ok` with `needs=lift`, not `missing`: the lift band lowers them, no code is involved.\n",
                        lifted, #indexed, #indexed - lifted_indexed, release))
    write("- A selector name is stored by apple.objc with a leading `-` for instance *and* class methods, so a method row's `+`/`-` is not verified, only its selector name.\n")
    write(string.format("- The surface was built at `arm64-apple-ios26.2`; the header walk reads `%s`. A row the 26.2 headers declare but this target does not is a version-gated `#if` in the header (e.g. `OS_LOG_TARGET_HAS_10_13_FEATURES`) or a 64-bit-only declaration: lowering an availability cannot bring it back, so it is `undecided` with `needs=declare`, never counted as done.\n",
                        TARGET))
    if swift and ledger_classify.has_any(swift.registries) then
        local by_package = {}
        local sum = 0
        for _, value in pairs(swift.registries) do
            if value[1] == "implemented" then
                by_package[value[2]] = (by_package[value[2]] or 0) + 1
                sum = sum + 1
            end
        end
        local parts = {}
        for _, package in ipairs(sorted_strings(table.keys(by_package))) do
            table.insert(parts, string.format("%s %d", package, by_package[package]))
        end
        write(string.format("- Swift rows are also placed from a Swift package's own registry, which is where a Swift package records what it implements: %d `implemented` entries over %s. A row no built module for is `declared` rather than `implemented`, and `needs=build`.\n",
                            sum, #parts > 0 and table.concat(parts, ", ") or "none"))
    end
    if swift then
        local groups, keys = {}, {}
        for _, module in ipairs(sorted_strings(table.keys(swift.sources))) do
            local source = swift.sources[module]
            local function field(name, default)
                local value = source[name]
                if value == nil then
                    return default
                end
                return tostring(value)
            end
            local key = {field("package", ""), field("backports", "?"), field("recipe", "")}
            local joined = table.concat(key, "\0")
            if groups[joined] == nil then
                groups[joined] = {key = key, modules = {}}
                table.insert(keys, joined)
            end
            table.insert(groups[joined].modules, module)
        end
        stable_sort(keys, function (a, b)
            local x, y = groups[a].key, groups[b].key
            for index = 1, 3 do
                if x[index] ~= y[index] then
                    return byteorder.less(x[index], y[index])
                end
            end
            return false
        end)
        for _, joined in ipairs(keys) do
            local group = groups[joined]
            local package, backports, recipe = group.key[1], group.key[2], group.key[3]
            local shown = {}
            for index = 1, math.min(8, #group.modules) do
                table.insert(shown, group.modules[index])
            end
            local names = table.concat(shown, ", ") .. (#group.modules > 8 and ", ..." or "")
            if recipe ~= "" then
                write(string.format("- %d module(s) read from `%s` (`backports = %s`, recipe `%s`): %s. The store holds more than one build of that package, so this is the one that was measured.\n",
                                    #group.modules, ledger_inputs.short(package), backports, recipe, names))
            else
                write(string.format("- %d module(s) read from `%s`, a build tree with no installed-package manifest beside it, so which build of it this is cannot be read off the file system: %s.\n",
                                    #group.modules, ledger_inputs.short(package), names))
            end
        end
        write(string.format("- A Swift row is `implemented` when its qualified name is declared by a module the port builds for `%s`, read with `%s`. That is evidence the runtime *declares* the API and that the module's own dylib stands beside it -- it is not evidence that a body returns the right answer, which is the generated call test's job. Matching is by exact qualified name and kind, not by signature.\n",
                            swift.target, path.filename(swift.digester)))
        write("- A Swift row of a framework no built module stands for is `undecided`, not `missing`: nothing on this machine can place it. That is most of the Swift surface, and it is the honest answer.\n")
    else
        write("- Swift rows are `unmeasured`: no Swift pass was given (--swift-modules), so no Swift number in this file means anything.\n")
    end
    write(string.format("- The `missing` constants that are declared `extern` are the exported ones; their real values, read out of dyld shared caches of real releases, are in `coordination/corpus/ledger/exported-constants.tsv` (`tools/corpus/%s` writes it and `EXPORTED-CONSTANTS.md` beside it).\n",
                        VALUES))
    local summary = path.join(args.out, "SUMMARY.md")
    io.writefile(summary, table.concat(out))
    if not_ios > 0 then
        local lines = {"api\tframework\treason\n"}
        for _, framework in ipairs(frameworks) do
            for _, pair in ipairs(not_ios_rows[framework]) do
                table.insert(lines, string.format("%s\t%s\t%s\n", pair[1].api, framework, pair[2]))
            end
        end
        io.writefile(path.join(args.out, "not-ios.tsv"), table.concat(lines))
    end
    return summary, written
end
