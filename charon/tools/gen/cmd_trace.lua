-- `trace`: the trace-only defaults of a framework, written into its build directory (trace/): the stubs of every declared member it
-- does not implement, one class per category (or one class object where the release lacks the class and every member is a stub),
-- the members left out with their reasons (skipped.tsv), one row per stub (stubs.tsv) and the class-object decisions (classes.tsv).
-- --all: every framework that has a snapshot. The stubs are compiled only with CHARON_TRACE_DEFAULTS and are never shipped.
-- The stubs read the typed fields of the declaration shards (design-foundation.md 5.7), not the header parser and not declaration text;
-- the corpus of ledgers and the surface table is --coordination (required).

local layout = import("layout", {anonymous = true})
local snapshot = import("spec", {anonymous = true})
local surface = import("surface", {anonymous = true})
local headers = import("headers", {anonymous = true})
local stubs = import("stubs", {anonymous = true})
local classes = import("classes", {anonymous = true})
local hand = import("hand", {anonymous = true})
local functions = import("functions", {anonymous = true})
local trace_files = import("trace_files", {anonymous = true})
local emit = import("emit", {anonymous = true})
local tsv = import("tsv", {anonymous = true})
local nsobject = import("nsobject", {anonymous = true})
local order = import("order", {anonymous = true})
local gen = import("cmd_gen", {anonymous = true})
local targets = import("targets", {anonymous = true})
local sdk_info = import("sdk", {anonymous = true})

local INHERITED_REASON = "init/new/copy the surface does not list: the inherited NSObject behaviour is what a call reaches"
-- The status of a C function the trace layer stubs.
local GENERABLE = "generable"
-- The status of a row the 6.1.3 release has: it is not stubbed.
local IMPLEMENTED = "implemented"

-- The first lines of a generated file: the mark, what the stubs are, and the import and the guard.
local function preamble(fw)
    return {
        layout.constants().MARK,
        "// Trace-only defaults: built only when CHARON_TRACE_DEFAULTS is set; never shipped. One class per category,",
        "// and a class the release lacks, when every member is a stub, is one @implementation (presence = full surface).",
        "// A stub logs once `unimplemented: " .. fw .. " <selector>`, returns the zero of its type, and sets an NSError an NSError ** names.",
        "// Block parameters are not invoked. Members with an override or a hand implementation are not stubbed.",
        "#ifdef CHARON_TRACE_DEFAULTS",
        "#import <" .. fw .. "/" .. fw .. ".h>",
        "#include <stdio.h>",
        "",
    }
end

-- Sorts a list of records in place by the order.less of their fields, in the order given (the first field that differs decides).
local function sort_by(list, fields)
    table.sort(list, function(a, b)
        for _, field in ipairs(fields) do
            if a[field] ~= b[field] then
                return order.less(a[field], b[field])
            end
        end
        return false
    end)
    return list
end

-- The stub rows, each {api, kind}, unique and sorted by api and then kind (sorted(set(stub_rows)) of tools/gen.py@52253c0650).
local function sorted_stub_rows(rows)
    local seen, out = {}, {}
    for _, row in ipairs(rows) do
        local key = row[1] .. "\t" .. row[2]
        if not seen[key] then
            seen[key] = true
            table.insert(out, row)
        end
    end
    return sort_by(out, {1, 2})
end

-- The reason an inherited selector is left out, or nil when its stub is kept: the surface does not list it, or the headers declare it
-- unavailable (an override the headers declare unavailable is not one the port needs: NSObject's behaviour is what a call reaches).
local function inherited_reason(m, surface_methods, sdk_release)
    if not surface_methods[m.api] then
        return INHERITED_REASON
    end
    if nsobject.declared_unavailable(m.availability) then
        return nsobject.unavailable_reason(sdk_release)
    end
    return nil
end

-- The members the spec names for one class, after the inherited selectors the surface does not list, or the headers declare unavailable,
-- are left out. Returns the classes in the order the spec names them, each with its members kept, and appends the members left out to skipped.
local function without_inherited(found, surface_methods, skipped, sdk_release)
    local kept_classes = {}
    for _, cls in ipairs(found.order) do
        local kept = {}
        for _, m in ipairs(found.members[cls]) do
            local reason = m.kind == "method" and nsobject.trace_inherited(m.selector) and inherited_reason(m, surface_methods, sdk_release)
            if reason then
                table.insert(skipped, {api = m.api, reason = reason})
            else
                table.insert(kept, m)
            end
        end
        if #kept > 0 then
            found.members[cls] = kept
            table.insert(kept_classes, cls)
        else
            found.members[cls] = nil
        end
    end
    found.order = kept_classes
end

-- The stub keys of the members: a method by its api, a property by the property it belongs to.
local function stub_keys_of(found)
    local keys = {}
    for _, cls in ipairs(found.order) do
        for _, m in ipairs(found.members[cls]) do
            if m.kind == "method" then
                keys[m.api] = true
            else
                keys[m.sign .. "[" .. cls .. " " .. m.name .. "]"] = true
            end
        end
    end
    return keys
end

-- The lines of one class: its declarations in a category when the release has the class, or its @implementation when generated,
-- then its stubs. Returns the number of stubs written; the rows of the stubs and the members left out are appended.
local function class_lines(fw, cls, members, generated, lines, stub_rows, skipped)
    if generated then
        table.insert(lines, "@implementation " .. cls)
    else
        table.insert(lines, "@interface " .. cls .. " (CharonTrace)")
        for _, m in ipairs(members) do
            table.insert(lines, stubs.signature(m) .. ";")
        end
        table.insert(lines, "@end")
        table.insert(lines, "@implementation " .. cls .. " (CharonTrace)")
    end
    local written = 0
    for _, m in ipairs(members) do
        table.insert(lines, stubs.stub_text(fw, m))
        written = written + 1
        local row = m.api
        if m.kind == "property-get" or m.kind == "property-set" then
            row = m.sign .. "[" .. cls .. " " .. m.name .. "]"
        end
        table.insert(stub_rows, {row, m.kind})
    end
    table.insert(lines, "@end")
    return written
end

-- The umbrella a nested target belongs to (Accelerate for Accelerate/vImage), or nil. The umbrella holds the C functions snapshot of its
-- nested targets, so a nested target is stubbed from it.
local function umbrella_of(tree, fw)
    local umbrellas = targets.umbrellas(tree)
    local names = {}
    for umbrella in pairs(umbrellas) do
        table.insert(names, umbrella)
    end
    -- byte order: a target named by two frameworks (the libc aliases of xlocale) has one umbrella, the same on every run
    table.sort(names, order.less)
    for _, umbrella in ipairs(names) do
        for _, target in ipairs(umbrellas[umbrella].targets) do
            if target == fw then
                return umbrella
            end
        end
    end
    return nil
end

-- The C functions of the snapshot the trace layer stubs, sorted by api. A framework with a snapshot of its own is stubbed from it. A nested
-- target with none (vImage, vecLib) takes the generable functions of its umbrella's snapshot that its own shard declares: the umbrella has
-- no trace folder (it has no shard), so a function the nested target declares is stubbed under that target, and a generable function no
-- nested target declares is left for the reconcile.
local function generable_functions(tree, fw)
    local own = functions.load(tree, fw)
    local has_own = false
    for _ in pairs(own) do
        has_own = true
        break
    end
    local owner = not has_own and umbrella_of(tree, fw) or nil
    local declared = owner and headers.shard_facts(tree, fw).functions or nil
    local rows = {}
    for _, row in pairs(owner and functions.load(tree, owner) or own) do
        if row.status == GENERABLE and (declared == nil or declared[row.api] ~= nil) then
            table.insert(rows, row)
        end
    end
    return sort_by(rows, {"api"})
end

-- The environment of the stub rule for one framework: the typed facts of its members by api, the functions by name, the typedef index and
-- the declared names (headers), the overrides, and the hand sources.
local function rule_env(tree, fw, facts, overridden, release_missing)
    local by_api = {}
    for _, m in ipairs(facts.members) do
        if by_api[m.api] == nil then
            by_api[m.api] = m
        end
    end
    return {
        members = by_api,
        functions = facts.functions,
        index = headers.typedef_index(tree, fw),
        declared = headers.declared_names(tree, fw),
        overridden = overridden,
        hand = hand.implementations(tree),
        hand_functions = hand.functions(tree),
        release_missing = release_missing,
    }
end

-- The 6.1.3 ledger rows of one framework (the folder --ledger-rows names, gen.lua ledger --rows), as the stub rule reads them: the
-- statuses of the rows the release lacks, and the same map as the release check (nil for a framework absent from 6.1.3, where every
-- member is missing and every member is stubbed). An implemented row is not listed, as ledger-w45 never listed one: it is neither checked
-- nor stubbed. A framework with no rows that is not absent is not checked: it lists no rows, so no member is stubbed.
local function release_of(tree, corpus, rows_dir, fw)
    if surface.has_ledger(corpus, rows_dir, fw) then
        local lacks = {}
        for k, status in pairs(surface.ledger_status(corpus, fw, rows_dir)) do
            if status ~= IMPLEMENTED then
                lacks[k] = status
            end
        end
        return lacks, lacks
    end
    if surface.absent_frameworks(tree)[fw] ~= nil then
        return {}, nil
    end
    return {}, {}
end

-- The class properties of a framework's shard, by the dotted name the ledgers and the registry give them (Cls.name): each one's api
-- (+[Cls name]). surface.canonical_member gives the instance form of a dotted name, so the class property is keyed through this map.
function class_property_apis(facts)
    local out = {}
    for _, m in ipairs(facts.members) do
        if m.kind == "property" and string.sub(m.api, 1, 2) == "+[" then
            out[m.alias] = m.api
        end
    end
    return out
end

-- The overrides of a framework: the canonical keys its registry rows cover, and for a class property the key of its class accessor
-- (both keys: the instance form is what surface.canonical_member names).
function overrides_of(tree, fw, facts)
    local class_props = class_property_apis(facts)
    local overridden = {}
    for canonical, found in pairs(surface.registry_entries(tree, fw)) do
        overridden[canonical] = true
        if found.entry.kind == "property" and class_props[found.entry.api] then
            overridden[class_props[found.entry.api]] = true
        end
    end
    return overridden
end

-- The surface rows with the key of each class property (canon, the api of its class accessor): the class decisions compare it with the
-- stub keys. A copy: the surface table is shared.
local function with_class_keys(rows, facts)
    local class_props = class_property_apis(facts)
    local out = {}
    for index, row in ipairs(rows) do
        local copy = {}
        for field, value in pairs(row) do
            copy[field] = value
        end
        if row.kind == "property" and class_props[row.api] then
            copy.canon = class_props[row.api]
        end
        out[index] = copy
    end
    return out
end

-- Writes the trace layer of one framework.
local function trace_one(args, fw, sdk_release)
    local tree, corpus = args.tree, args.coordination
    local spec = snapshot.load(tree, fw)
    local facts = headers.shard_facts(tree, fw)
    local overridden = overrides_of(tree, fw, facts)
    local led6, release_missing = release_of(tree, corpus, args.ledger_rows, fw)
    local env = rule_env(tree, fw, facts, overridden, release_missing)
    local found, skipped = stubs.members(spec, env)
    local stub_keys = stub_keys_of(found)
    -- the reasons the class decisions read: taken before the inherited-selector rule adds its own, as the oracle does
    local skip_reasons = {}
    for _, s in ipairs(skipped) do
        skip_reasons[s.api] = s.reason
    end
    local rows = with_class_keys(surface.surface_rows(tree, corpus, sdk_release, fw), facts)
    local surface_methods = {}
    for _, row in ipairs(rows) do
        if row.kind == "method" then
            surface_methods[surface.canonical_member(row.api, "method")] = true
        end
    end
    without_inherited(found, surface_methods, skipped, sdk_release)
    local decisions = {}
    if release_missing ~= nil then
        decisions = classes.decisions({
            tree = tree, fw = fw, spec = spec, stub_keys = stub_keys, overridden = overridden,
            surface = rows, led6 = led6, skip_reasons = skip_reasons, supers = facts.superclasses,
        })
    end
    local lines = preamble(fw)
    local stub_rows = {}
    local stubbed = 0
    local class_names = table.move(found.order, 1, #found.order, 1, {})
    table.sort(class_names, order.less)
    for _, cls in ipairs(class_names) do
        local generated = decisions[cls] ~= nil and decisions[cls].generated
        stubbed = stubbed + class_lines(fw, cls, found.members[cls], generated, lines, stub_rows, skipped)
    end
    for _, m in ipairs(stubs.functions(generable_functions(tree, fw), env, skipped)) do
        table.insert(lines, stubs.stub_text(fw, m))
        stubbed = stubbed + 1
        table.insert(stub_rows, {m.api .. "()", "function"})
    end
    table.insert(lines, "#endif")
    emit.file(trace_files.defaults_file(tree, fw), table.concat(lines, "\n") .. "\n")
    local skipped_rows = {}
    for _, s in ipairs(skipped) do
        table.insert(skipped_rows, {s.api, s.reason})
    end
    emit.file(trace_files.skipped_file(tree, fw), tsv.table_text({"api", "reason"}, skipped_rows))
    emit.file(trace_files.stubs_file(tree, fw), tsv.table_text({"api", "kind"}, sorted_stub_rows(stub_rows)))
    local class_rows = {}
    for cls, d in pairs(decisions) do
        table.insert(class_rows, {cls, d.generated and "yes" or "no", d.reason})
    end
    sort_by(class_rows, {1})
    emit.file(trace_files.classes_file(tree, fw), tsv.table_text({"class", "generated", "reason"}, class_rows))
    print(string.format("trace %s: %d stubs in %d classes, %d members left out (skipped.tsv)", fw, stubbed, #found.order, #skipped))
end

-- Returns the exit status.
function run(args)
    assert(args.coordination, "trace needs --coordination: the corpus folder")
    -- without --ledger-rows, the corpus's own 6.1.3 ledger is read (surface.ledger_6_1_3, as scope reads it); gen.lua ledger --rows writes another folder
    args.ledger_rows = args.ledger_rows or surface.ledger_6_1_3()
    assert(args.sdk, "trace needs --sdk: the iPhoneOS SDK whose release names the surface table")
    local sdk_release = sdk_info.discover(args.sdk).version
    local targets = args.all and gen.frameworks(args.tree) or {args.framework}
    for _, fw in ipairs(targets) do
        trace_one(args, fw, sdk_release)
    end
    return 0
end
