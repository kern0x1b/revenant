local emit = import("emit", {anonymous = true})
local surface_model = import("surface_model", {anonymous = true})
local sdk_info = import("sdk", {anonymous = true})
local ledger = import("ledger", {anonymous = true})

local function append(into, name, records)
    into[name] = into[name] or {}
    for _, record in ipairs(records) do
        table.insert(into[name], record)
    end
end

local function header_asker(args)
    if args.vfs == nil then
        return nil
    end
    local header_pass = import("header_pass", {anonymous = true})
    local project = import("project", {anonymous = true})
    local opts = {sdk = args.sdk, vfs = args.vfs, clang = project.clang(args), release = args.release or "6.1.3",
                  out = path.join(args.out, "header-pass")}
    local memo = {}
    return function(unit, records)
        if memo[unit] == nil then
            local rows = {}
            for _, record in ipairs(records) do
                table.insert(rows, {key = ledger.row_key(record), kind = record.kind, api = record.api})
            end
            memo[unit] = header_pass.decide(opts, unit, rows)
        end
        return memo[unit]
    end
end

local function write_rows(args, decls, facts, exported)
    assert(args.gate, "ledger --rows needs --gate: the gate's output folder, whose lib*Backports.dylib are the built libraries")
    local built, count = ledger.read_built(args.tree, args.gate)
    local all = ledger.merge(facts, built)
    local header_of = header_asker(args)
    local by_unit = {}
    local frameworks = table.keys(decls)
    table.sort(frameworks)
    for _, fw in ipairs(frameworks) do
        for _, record in ipairs(decls[fw]) do
            local unit = record.unit or record.claimed_by
            if unit then
                append(by_unit, unit, {record})
            end
        end
    end
    local unit_names = table.keys(by_unit)
    table.sort(unit_names)
    local files = {}
    for _, unit in ipairs(unit_names) do
        local records = by_unit[unit]
        local name = string.gsub(unit, "/", "_")
        append(files, name, records)
        local owner = string.match(unit, "^[^/]+")
        if owner ~= unit and by_unit[owner] ~= nil then
            append(files, owner, records)
        end
    end
    local own_rows = {}
    for _, unit in ipairs(unit_names) do
        for _, row in ipairs(ledger.rows_of(by_unit[unit], all, exported, header_of, nil)) do
            table.insert(own_rows, row)
        end
    end
    local twins = ledger.twins_of(own_rows)
    local names = table.keys(files)
    table.sort(names)
    os.mkdir(args.rows)
    local written = 0
    for _, name in ipairs(names) do
        if args.framework == nil or string.gsub(args.framework, "/", "_") == name then
            emit.file(path.join(args.rows, name .. ".tsv"), ledger.rows_text(ledger.rows_of(files[name], all, exported, header_of, twins)))
            written = written + 1
        end
    end
    local totals = {}
    local units = 0
    for unit, records in pairs(by_unit) do
        units = units + 1
        for _, row in ipairs(ledger.rows_of(records, all, exported, header_of, twins)) do
            totals[row.status] = (totals[row.status] or 0) + 1
        end
    end
    local parts = {}
    for _, status in ipairs(table.keys(totals)) do
        table.insert(parts, status .. " " .. totals[status])
    end
    table.sort(parts)
    print(string.format("ledger: %d files (%d units) over the cache and %d built libraries: %s", written, units, count,
                        table.concat(parts, ", ")))
end

function run(args)
    assert(args.out, "ledger needs --out: the folder framework-verdicts-<release>.tsv is written to")
    assert(args.sdk, "ledger needs --sdk: the iPhoneOS SDK whose declaration shards the model is read from")
    local release = args.release or "6.1.3"
    local sdk_release = sdk_info.discover(args.sdk).version
    local decls = surface_model.declarations(args.tree, sdk_release)
    local facts, cache, objc_text, export_text = ledger.read_release(args.tree, release)
    if args.dump then
        emit.file(path.join(args.dump, "objc-inventory-" .. release .. ".tsv"), objc_text)
        emit.file(path.join(args.dump, "exports-" .. release .. ".tsv"), export_text)
    end
    print(string.format("ledger: %s cache %s: %d classes, %d protocols, %d exported symbols", release, cache,
                        #table.keys(facts.classes), #table.keys(facts.protocols), #table.keys(facts.exports)))
    local tbd = import("tbd", {anonymous = true})
    local everywhere = nil
    local function exported()
        if everywhere == nil then
            everywhere = tbd.all_symbols(args.sdk)
        end
        return everywhere
    end
    local verdicts = ledger.verdicts(decls, facts, exported)
    local names = table.keys(verdicts)
    table.sort(names)
    local lines = {"framework\tverdict\tcheckable\tpresent\treason"}
    local counts, absent = {}, {}
    for _, fw in ipairs(names) do
        local v = verdicts[fw]
        counts[v.verdict] = (counts[v.verdict] or 0) + 1
        if v.verdict == "absent" then
            table.insert(absent, fw)
        end
        table.insert(lines, table.concat({fw, v.verdict, v.checkable, v.present, v.reason}, "\t"))
    end
    emit.file(path.join(args.out, "framework-verdicts-" .. release .. ".tsv"), table.concat(lines, "\n") .. "\n")
    print(string.format("ledger: %d frameworks: present %d, absent %d, undecided %d", #names, counts.present or 0, counts.absent or 0,
                        counts.undecided or 0))
    print("ledger: absent at " .. release .. ": " .. table.concat(absent, ", "))
    if args.rows then
        write_rows(args, decls, facts, exported)
    end
    return 0
end
