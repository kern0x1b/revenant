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
local GENERABLE = "generable"
local IMPLEMENTED = "implemented"

local function preamble(fw)
    return {
        layout.constants().MARK,
        "// Trace-only defaults: built only when REVENANT_TRACE_DEFAULTS is set; never shipped. One class per category,",
        "// and a class the release lacks, when every member is a stub, is one @implementation (presence = full surface).",
        "// A stub logs once `unimplemented: " .. fw .. " <selector>`, returns the zero of its type, and sets an NSError an NSError ** names.",
        "// Block parameters are not invoked. Members with an override or a hand implementation are not stubbed.",
        "#ifdef REVENANT_TRACE_DEFAULTS",
        "#import <" .. fw .. "/" .. fw .. ".h>",
        "#include <stdio.h>",
        "",
    }
end

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

local function inherited_reason(m, surface_methods, sdk_release)
    if not surface_methods[m.api] then
        return INHERITED_REASON
    end
    if nsobject.declared_unavailable(m.availability) then
        return nsobject.unavailable_reason(sdk_release)
    end
    return nil
end

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

local function class_lines(fw, cls, members, generated, lines, stub_rows, skipped)
    if generated then
        table.insert(lines, "@implementation " .. cls)
    else
        table.insert(lines, "@interface " .. cls .. " (RevenantTrace)")
        for _, m in ipairs(members) do
            table.insert(lines, stubs.signature(m) .. ";")
        end
        table.insert(lines, "@end")
        table.insert(lines, "@implementation " .. cls .. " (RevenantTrace)")
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

local function umbrella_of(tree, fw)
    local umbrellas = targets.umbrellas(tree)
    local names = {}
    for umbrella in pairs(umbrellas) do
        table.insert(names, umbrella)
    end
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

function class_property_apis(facts)
    local out = {}
    for _, m in ipairs(facts.members) do
        if m.kind == "property" and string.sub(m.api, 1, 2) == "+[" then
            out[m.alias] = m.api
        end
    end
    return out
end

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

local function trace_one(args, fw, sdk_release)
    local tree, corpus = args.tree, args.coordination
    local spec = snapshot.load(tree, fw)
    local facts = headers.shard_facts(tree, fw)
    local overridden = overrides_of(tree, fw, facts)
    local led6, release_missing = release_of(tree, corpus, args.ledger_rows, fw)
    local env = rule_env(tree, fw, facts, overridden, release_missing)
    local found, skipped = stubs.members(spec, env)
    local stub_keys = stub_keys_of(found)
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

function run(args)
    assert(args.coordination, "trace needs --coordination: the corpus folder")
    args.ledger_rows = args.ledger_rows or surface.ledger_6_1_3()
    assert(args.sdk, "trace needs --sdk: the iPhoneOS SDK whose release names the surface table")
    local sdk_release = sdk_info.discover(args.sdk).version
    local targets = args.all and gen.frameworks(args.tree) or {args.framework}
    for _, fw in ipairs(targets) do
        trace_one(args, fw, sdk_release)
    end
    return 0
end
