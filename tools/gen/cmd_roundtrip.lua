-- roundtrip: for each Swift module of the SDK, renders its skeleton from the full model, compiles it under its own name, dumps it with
-- the digester and compares that dump's model with the SDK's (swift_roundtrip.lua). Per module it prints one line, then its causes,
-- and writes the same text to --out/<F>/report.txt. Build products, never committed. --sdk is the SDK, --out the folder, --framework
-- runs one module. The digester and the compiler run through heavy.sh; --coordination names the corpus folder heavy.sh sits beside.
-- --headers (the generated headers tree, optional) gives each module's own ObjC part to its compile (swift_roundtrip.underlying_of).

local swift_model = import("swift_model", {anonymous = true})
local swift_canonical = import("swift_canonical", {anonymous = true})
local swift_render = import("swift_render", {anonymous = true})
local swift_roundtrip = import("swift_roundtrip", {anonymous = true})
local heavy_batch = import("heavy_batch", {anonymous = true})
local emit = import("emit", {anonymous = true})

-- The first part of one module's round trip: its model, rendered to its source. Returns the part the batches and the second part read, or nil
-- and the reason the SDK's model has none.
local function prepare(folder, out_dir, name, known, classes, public, headers)
    local sdk_rows, reason = swift_model.model(folder, name)
    if sdk_rows == nil then
        return nil, reason
    end
    local dir = path.join(out_dir, name)
    local module_dir = path.join(dir, "module")
    os.mkdir(module_dir)
    local source = path.join(dir, name .. ".swift")
    -- the generated file and its report spell the SDK's non-ASCII identifiers as the SDK does; they are never committed
    local identifiers = swift_model.non_ascii_identifiers(sdk_rows)
    emit.file(source, swift_render.render(sdk_rows, name, known, classes, public), identifiers)
    local underlying = headers and swift_roundtrip.underlying_of(headers, module_dir, name) or nil
    return {name = name, module_dir = module_dir, source = source, sdk_rows = sdk_rows, identifiers = identifiers,
            underlying = underlying}
end

-- The second part of one module's round trip, once its compile and dump have run in the batches: its result table.
local function finish(prep)
    local result = {identifiers = prep.identifiers}
    result.errors, result.first_error = swift_roundtrip.compile_result(prep.module_dir)
    local root, why = swift_roundtrip.dump_result(prep.module_dir)
    if root == nil then
        result.dump_reason = why
        return result
    end
    local our_rows = swift_model.rows(root, prep.name)
    if our_rows == nil then
        result.dump_reason = "the digester's dump holds no declaration of the module"
        return result
    end
    swift_model.annotate_async(our_rows)
    -- the dump of the compiled skeleton names its generic parameters canonically too (tau, depth, index), as the SDK's ABI dump does:
    -- its rows take the same spelling as the SDK's model, so the compare sees one spelling and the report stays ASCII
    our_rows = swift_canonical.rows(our_rows)
    result.compare = swift_roundtrip.compare(prep.sdk_rows, our_rows)
    for _, row in ipairs(prep.sdk_rows) do
        if swift_render.untyped(row) then
            result.untyped = (result.untyped or 0) + 1
        end
    end
    return result
end

-- Records one module's difference of one item under the key "swift <module> <item>", when the count is above zero.
local function measure(measured, name, item, count)
    if count > 0 then
        measured["swift " .. name .. " " .. item] = count
    end
end

-- The text of one module's result: its first line, then one line per cell that differs, the most frequent first.
local function report_of(name, result)
    local lines = {}
    local compiles = result.errors == 0 and "compiles" or ("does not compile: " .. result.errors .. " errors")
    local head = "roundtrip: " .. name .. " " .. compiles
    if result.first_error then
        head = head .. ", first: " .. result.first_error
    end
    table.insert(lines, head)
    if result.dump_reason then
        table.insert(lines, "  no dump: " .. result.dump_reason)
        return lines
    end
    local c = result.compare
    table.insert(lines, string.format("  sdk %d declarations, ours %d, equal %d, missing %d, extra %d, duplicate keys %d",
                                      c.sdk, c.ours, c.equal, #c.missing, c.extra, c.duplicates))
    table.insert(lines, string.format("  by design: %d rows, stored properties rendered computed (not a mismatch)", c.by_design))
    if result.untyped then
        table.insert(lines, string.format("  model gap: %d declarations with no type in the dump (the digester gives the "
                                          .. "error type; not rendered, so missing)", result.untyped))
    end
    local cells = {}
    for cell, count in pairs(c.causes) do
        table.insert(cells, {cell = cell, count = count})
    end
    table.sort(cells, function(a, b)
        if a.count ~= b.count then
            return a.count > b.count
        end
        return a.cell < b.cell
    end)
    for _, item in ipairs(cells) do
        table.insert(lines, string.format("  %s: %d rows (%s)", item.cell, item.count, c.examples[item.cell]))
    end
    for i, label in ipairs(c.missing) do
        if i > 5 then break end
        table.insert(lines, "  missing: " .. label)
    end
    return lines
end

-- Returns the exit status.
function run(args)
    assert(args.sdk, "--sdk (the SDK folder) is required")
    assert(args.out, "--out (the folder to write the code into) is required")
    local heavy = swift_model.heavy_path(args.coordination)
    assert(os.isfile(heavy), "no heavy.sh: " .. heavy)
    local all = swift_model.modules(args.sdk)
    local names = args.framework and {args.framework} or all
    local triple = swift_model.triple_of(args.sdk)
    local known = swift_model.module_set(args.sdk)
    local public = swift_model.public_modules(args.sdk)
    os.mkdir(args.out)
    local started = os.mclock()
    -- the digester's dumps of every module, run as one batch first: the superclass chains of every module are read from them, and each
    -- module's model is read from the same cache
    local folder = swift_model.prefetch(args.tree, heavy, args.sdk, triple, all)
    -- the superclass chains of every module, read first: a class's inherited conformances come from the module it inherits from
    local classes, no_model = swift_model.class_index(folder, all)
    for _, l in ipairs(no_model) do
        print("roundtrip: class index, no model: " .. l)
    end
    local compiled, dumped, equal, declarations, designed, gaps = 0, 0, 0, 0, 0, 0
    local unmeasured = 0
    -- the differences by key ("swift <module> <item>", the verify's known table's keys), each a count above zero
    local measured = {}
    -- every module is prepared (its source rendered), then the compiles run as one batch and the dumps as one batch, then each module is
    -- finished in turn. A module whose part fails (a batch that stopped before its job, a digester that aborts) is recorded as not
    -- measured, with the error, and the run goes on: the others are not lost to it
    local parts = {}
    for _, name in ipairs(names) do
        local entry = {name = name}
        try {
            function ()
                entry.prep, entry.reason = prepare(folder, args.out, name, known, classes, public, args.headers)
            end,
            catch {
                function (err)
                    entry.failure = tostring(err)
                end
            }
        }
        table.insert(parts, entry)
    end
    local compiles, dumps = {}, {}
    for _, entry in ipairs(parts) do
        if entry.prep then
            table.insert(compiles, swift_roundtrip.compile_item(triple, args.sdk, entry.prep.source, entry.prep.module_dir, entry.name,
                                                                 entry.prep.underlying))
        end
    end
    local left = heavy_batch.run(heavy, args.out, "compile", compiles, true)
    if left > 0 then
        print(string.format("roundtrip: the compile batch left %d module(s) without a status (the slot or the batch bound stopped it)", left))
    end
    for _, entry in ipairs(parts) do
        if entry.prep then
            table.insert(dumps, swift_roundtrip.dump_item(triple, args.sdk, entry.prep.module_dir, entry.name))
        end
    end
    left = heavy_batch.run(heavy, args.out, "dump", dumps, true)
    if left > 0 then
        print(string.format("roundtrip: the dump batch left %d module(s) without a status (the slot or the batch bound stopped it)", left))
    end
    for _, entry in ipairs(parts) do
        local name = entry.name
        local result, reason, failure = nil, entry.reason, entry.failure
        if entry.prep then
            try {
                function ()
                    result = finish(entry.prep)
                end,
                catch {
                    function (err)
                        failure = tostring(err)
                    end
                }
            }
        end
        local lines
        if failure then
            unmeasured = unmeasured + 1
            measure(measured, name, "not measured", 1)
            lines = {"roundtrip: " .. name .. " not measured: " .. failure}
        elseif result then
            lines = report_of(name, result)
            if result.errors == 0 then compiled = compiled + 1 end
            measure(measured, name, "compile errors", result.errors)
            if result.dump_reason then measure(measured, name, "no dump", 1) end
            if result.compare then
                dumped = dumped + 1
                equal = equal + result.compare.equal
                designed = designed + result.compare.by_design
                gaps = gaps + (result.untyped or 0)
                declarations = declarations + result.compare.sdk
                for cell, count in pairs(result.compare.causes) do measure(measured, name, cell, count) end
                measure(measured, name, "missing", #result.compare.missing)
                measure(measured, name, "extra", result.compare.extra)
                measure(measured, name, "duplicate keys", result.compare.duplicates)
            end
        else
            lines = {"roundtrip: " .. name .. " no model: " .. reason}
        end
        for _, l in ipairs(lines) do
            print(l)
        end
        emit.file(path.join(args.out, name, "report.txt"), table.concat(lines, "\n") .. "\n", result and result.identifiers)
    end
    local seconds = (os.mclock() - started) / 1000
    print(string.format("roundtrip: %d modules, %d compile, %d dumped, %d not measured, %d of %d declarations equal, "
                        .. "%d by design, %d model gaps, %.1fs", #names, compiled, dumped, unmeasured, equal, declarations,
                        designed, gaps, seconds))
    return 0, string.format("%d compile, %d dumped, %d not measured, %d of %d declarations equal, %d by design, %d model gaps",
                            compiled, dumped, unmeasured, equal, declarations, designed, gaps), measured
end
