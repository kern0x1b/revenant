-- `scope`: the scope of the surface, counted from the tables. For each framework and kind: how many surface rows there are, how many
-- the 6.1.3 and 4.3 ledgers list, and the state of each row (one state per row, by row_state); the work queue by demand; and the
-- reconciliation of the rows the scope calls generable with the stubs the trace layer wrote. Writes v-gen-scope.tsv, v-gen-scope.md,
-- v-gen-reconcile.tsv and v-gen-queue.tsv into --out, and prints the tie-out. The surface table and the ledgers are the corpus
-- (--coordination); the headers are read from --sdk. --swift-rendered names the folder swiftcode wrote the Swift skeletons' <module>.rendered
-- keys into: a Swift row a skeleton declares is a generated stub. The rules are top-level functions, so the test reads them without an SDK.

local layout = import("layout", {anonymous = true})
local snapshot = import("spec", {anonymous = true})
local surface = import("surface", {anonymous = true})
local functions = import("functions", {anonymous = true})
local protocols = import("protocols", {anonymous = true})
local trace = import("cmd_trace", {anonymous = true})
local trace_files = import("trace_files", {anonymous = true})
local headers = import("headers", {anonymous = true})
local coverage = import("coverage", {anonymous = true})
local strings = import("strings", {anonymous = true})
local nsobject = import("nsobject", {anonymous = true})
local swift_shard = import("swift_shard", {anonymous = true})
local emit = import("emit", {anonymous = true})
local order = import("order", {anonymous = true})
local targets = import("targets", {anonymous = true})
local sdk_info = import("sdk", {anonymous = true})
local project = import("project", {anonymous = true})

-- The ledgers the scope counts against: the 6.1.3 release (the members it lacks are the work) and the 4.3 release.
local LEDGER_6_1_3 = surface.ledger_6_1_3()
local LEDGER_4_3 = surface.ledger_4_3()
-- The kinds the scope counts. A surface row of any other kind is in the tie-out's total and in no state.
local SCOPE_KINDS = strings.set({"class", "method", "property", "constant", "function", "enum", "struct", "typealias", "protocol"})
-- The states that a generated stub answers (the trace layer's stub list is the one definition of generable).
local GENERABLE_STATES = strings.set({"generable stub", "C function: generable stub (trace layer)"})
-- The ledger status of a row the header parse covers with no symbol to generate.
local HEADER_OK = "header-ok"
-- The status of a C function the trace layer stubs.
local GENERABLE = "generable"
-- The state of a row the framework has no snapshot for, and of a Swift row (the spec is the ObjC headers).
local NO_SNAPSHOT = "no snapshot"
-- The state of a surface row the 6.1.3 ledger does not list. The ledger lists the rows it checked, so an unlisted row is not checked: it is
-- not implemented, and no state falls back to implemented for it.
local NOT_CHECKED = surface.not_checked_state()
-- The surface kind of each shard kind a C declaration is read as (the shard's kind column): an umbrella's row is matched to a nested
-- target's shard row of the same surface kind and name.
local SURFACE_KIND_OF_SHARD = {["function"] = "function", enumconst = "constant", var = "constant", enum = "enum", struct = "struct",
                               typedef = "typealias"}
-- The states of a Swift row, by its framework's Swift shard (swift_shard.lua): a declaration the shard names is a named gap (no Swift
-- generator yet); a row the shard does not name, or a framework with no shard, stays "no snapshot" with its reason.
-- The frameworks the markdown page lists by demand.
local TOP_RANKS = 60

-- The states that name a release: the surface's release (release) and the compile release of the protocol bodies (compile, 16.4). They are
-- built once per run here, and the prefixes of decided and queue_next are these texts, so no state names a release in a literal.
function states_of(release, compile)
    local SWIFT_RENDERED = "swift: rendered by the Swift skeleton (generated stub)"
    local SWIFT_DECLARED = "swift: declared in the " .. release .. " Swift shard (not generated: no Swift generator)"
    local SWIFT_NOT_NAMED = NO_SNAPSHOT .. ": the Swift shard names no declaration for this api"
    local SWIFT_NO_SHARD = NO_SNAPSHOT .. ": no Swift shard for the framework"
    -- The state of each protocol object, by the transcriber's status for its protocol.
    local PROTOCOL_STATES = {
        ["sdk16 body"] = "protocol object: generated from the " .. compile .. " body",
        transcribed = "protocol object: generated from the transcribed header",
        ["hand header"] = "protocol object: hand header (no generator)",
        refused = "protocol object: refused by the transcriber",
        missing = "protocol object: not in the " .. release .. " AST",
    }
    -- The decided states: the row is answered by the release, the registry, a stub, a generated constant or object, a hand implementation, or
    -- a recorded decision. Every other state is open, and queue_item() queues it: the state is its reason in the queue.
    local DECIDED_STATES = {
        "header-only (lift)", "overridden", "generable stub", "generable constant", "numeric (not a string object)",
        "owned by a live branch", "registry decision", "not declared for iOS", "hand implementation (no registry row)",
        "class object: generated", "class object: hand code covers it", "protocol object: generated from",
        "protocol member: in the " .. compile .. " body", "protocol member: in the transcribed protocol header", "protocol member: declared by a hand header",
        "C function: generable stub", SWIFT_RENDERED,
    }
    -- The open states the work queue lists: the prefix of a state, the kind of work and the next step. The first prefix that matches
    -- names the entry; a state no entry names is still queued, by queue_item()'s fallback.
    local QUEUE_NEXT = {
        {"protocol member: " .. release .. " only", "protocol member added after the " .. compile .. " body", "a registry decision: the protocol object is the " .. compile .. " body, so the member needs a transcribed or hand body for it"},
        {"protocol member: not in the " .. release .. " facts", "protocol member with no " .. release .. " fact", "read the header by hand; the member's owner is not the protocol the surface names"},
        {"framework skipped by the extractor", "member of a framework the extractor skips", "a decision on the framework: read its Swift interface or its headers (the reason in the state names what is missing)"},
        {NOT_CHECKED, "a row the 6.1.3 ledger does not list", "check the row against the 6.1.3 release: gen.lua ledger --rows writes a row for every declaration of the model, and the scope reads it with --ledger-rows"},
        {"absent at 6.1.3", "a row the 6.1.3 ledger does not list, in a framework absent from 6.1.3 (spec/framework-verdicts-6.1.3.tsv, verdict absent)", "the framework is absent from 6.1.3, so every row is work: the trace layer stubs it, and the Swift rows queue in the bucket"},
        {"not in the extractor's parse", "member the parse of a parsed framework does not declare", "read the framework's declaration for this member by hand (the parse holds none): decide per row"},
        {"class object: not generated", "class object with uncovered members", "cover each listed member with a stub or a registry decision, or leave the class out"},
        {"C function: exported by the " .. release .. " .tbd", "C function exported without a declaration", "find its declaration in the SDK (no header declares it): a decision on the name"},
        {"not stubbed: not stubbed by the trace layer", "row with no stub and no skip reason", "should be empty: a stub-layer defect"},
        {"init/new: not spelled", "init or new not spelled by the headers", "decide per class: implicit from NSObject, or unavailable by a macro"},
        {"not in the header parse (category or other)", "not in the header parse", "read the header by hand"},
        {"swift: declared in the " .. release .. " Swift shard", "Swift declaration with no Swift generator", "a Swift generator: the declaration is in the shard, and the row is a named gap until one exists"},
        {"no snapshot: the Swift shard names no declaration", "Swift row the Swift shard does not name", "read the module's Swift interface for the row: the digester dump does not name it (the swiftshard report gives the cause)"},
        {"no snapshot: no Swift shard", "framework with no Swift shard", "commit the framework's Swift shard (swiftshard), or decide the framework's scope"},
        {"needs a generator: ", "a generator for the kind is missing", "write the generator for the kind (enum, struct or typealias), or decide the row by hand"},
        {"no snapshot", "framework has no committed declaration shard", "commit the framework's declaration shard (spec/<F>/declarations.tsv), or decide the framework's scope"},
        {"protocol object: ", "protocol object not generated", "read the transcriber's status for the protocol in the state, and decide the object"},
        {"protocol member: ", "protocol member not generated", "read the protocol's status in the state, and decide the member"},
        {"C function: ", "C function not generable", "read the reason in the state, and decide the name"},
        {"not stubbed: ", "row the trace layer skips", "read the skip reason in the state, and decide the row"},
        {"not generated: ", "constant not generated", "read the value status in the state, and decide the constant"},
        {"class object: not a candidate", "class row missing with no member missing", "the class has no missing member to generate: decide the class row by hand"},
        {"class object: ", "class object not generated", "read the class state, and decide the class"},
    }
    return {
        swift_rendered = SWIFT_RENDERED, swift_declared = SWIFT_DECLARED, swift_not_named = SWIFT_NOT_NAMED,
        swift_no_shard = SWIFT_NO_SHARD,
        protocol = PROTOCOL_STATES, decided = DECIDED_STATES, queue_next = QUEUE_NEXT,
        init_new = "init/new: not spelled by the " .. release .. " headers (implicit, or unavailable by a macro)",
        member_no_fact = "protocol member: not in the " .. release .. " facts (gap)",
        member_release_only = "protocol member: " .. release .. " only, the " .. compile .. " body the protocol object is built from lacks it (gap)",
        member_in_compile = "protocol member: in the " .. compile .. " body (lifted protocol object)",
        not_in_ast = "not in the " .. release .. " AST",
        unavailable_reason = nsobject.unavailable_reason(release),
        unavailable_state = nsobject.unavailable_state(release),
    }
end

local function starts_with(text, prefix)
    return string.sub(text, 1, #prefix) == prefix
end

-- The integer a demand-apps cell names: int(value or 0) of the oracle, an empty or missing cell being 0.
local function number_of(value)
    if value == nil or value == "" then
        return 0
    end
    return assert(tonumber(value), "not a number in the surface table: " .. value)
end

-- The state of a protocol member, by the transcriber's facts for its protocol (protocol_member_state of tools/gen.py@52253c0650). proto: the
-- protocol records of the framework (protocols.records).
function protocol_member_state(owner, api, proto, states)
    local record = proto[owner]
    if record == nil then
        return "protocol member: protocol not in the transcriber's facts"
    end
    local kind = "method"
    if string.find(api, ".", 1, true) and not starts_with(api, "-[") and not starts_with(api, "+[") then
        kind = "property"
    end
    -- the selector: the canonical -[Owner selector] without its owner and its closing bracket
    local selector = (string.gsub(surface.canonical_member(api, kind), "^[%-%+]%[" .. owner .. " ", "", 1))
    selector = (string.gsub(selector, "%]$", ""))
    local member = nil
    for _, m in ipairs(record.members) do
        if m.selector == selector then
            member = m
            break
        end
    end
    if record.status == "sdk16 body" then
        if member == nil then
            return states.member_no_fact
        end
        if member.in16 == "no" then
            return states.member_release_only
        end
        return states.member_in_compile
    end
    if record.status == "transcribed" then
        if member then
            return "protocol member: in the transcribed protocol header"
        end
        return states.member_no_fact
    end
    if record.status == "hand header" then
        return "protocol member: declared by a hand header (no generator)"
    end
    return "protocol member: its protocol is " .. (record.status == "refused" and "refused by the transcriber" or states.not_in_ast)
end

-- The state of a class object, by the trace layer's decision for it (classes.tsv through trace_files.load_class_decisions).
local function class_state(api, ctx)
    local decision = ctx.class_decisions[api]
    if decision == nil then
        return "class object: not a candidate (no missing member rows in the header parse)"
    end
    if decision.generated then
        return "class object: generated (trace layer; every member a stub)"
    end
    if string.find(decision.reason, "own sources", 1, true) or string.find(decision.reason, "override", 1, true) then
        return "class object: hand code covers it (not generated)"
    end
    return "class object: not generated (a member uncovered, or the superclass is not in the release)"
end

-- The state of a C function (the functions snapshot, and the trace layer's generable status for it). A generable function the trace layer
-- left out reports the reason it recorded, as a method does (member_state).
local function function_state(api, ctx)
    local record = ctx.functions[api]
    if record == nil then
        return "C function: not in the functions snapshot"
    end
    if record.status == GENERABLE then
        local reason = ctx.stub_reason_of(api)
        if reason == nil then
            return "C function: generable stub (trace layer)"
        end
        if starts_with(reason, "override or hand implementation") then
            return "hand implementation (no registry row)"
        end
        return "C function: not stubbed: " .. reason
    end
    return "C function: " .. record.reasons
end

-- The state of a protocol object of an objc protocol row.
local function protocol_state(api, ctx)
    local record = ctx.proto[api]
    if record == nil then
        return "protocol object: not in the transcriber's list"
    end
    return assert(ctx.states.protocol[record.status], "unknown protocol status: " .. record.status)
end

-- The state of a method or property the spec holds: a stub of the trace layer (or the reason it has none), by the trace layer's skip
-- reasons. A row the spec does not hold is explained by the header parse's gap reason (ctx.gap_of).
local function member_state(kind, api, ctx)
    local r = ctx.spec_by_api[api]
    if r == nil then
        return ctx.gap_of and ctx.gap_of(api) or "not in the header parse (category or other)"
    end
    local key = surface.canonical_member(api, kind)
    local reason = nil
    if ctx.stub_keys ~= nil then
        if not ctx.stub_keys[key] then
            reason = ctx.stub_reason_of(key) or "not stubbed by the trace layer"
        end
    else
        reason = ctx.stub_reason_of(key)
    end
    if reason == nil then
        return "generable stub"
    end
    if reason == ctx.states.unavailable_reason then
        return ctx.states.unavailable_state
    end
    if starts_with(reason, "type not declared for iOS") then
        return "not declared for iOS"
    end
    if starts_with(reason, "override or hand implementation") then
        return "hand implementation (no registry row)"
    end
    return "not stubbed: " .. reason
end

-- The state of a constant: its owner and its value, from the spec row (nil when the spec holds no row for it).
local function constant_state(r)
    if r == nil then
        return "not in the header parse (category or other)"
    end
    if r.owned ~= "-" then
        if starts_with(r.owned, "registry:") then
            return "registry decision"
        end
        return "owned by a live branch"
    end
    if r.value_status == "found" and r.tbd == "exported" then
        return "generable constant"
    end
    if r.value_status == "numeric" then
        return "numeric (not a string object)"
    end
    local value = r.value_status
    if value == nil or value == "" then
        value = "-"
    end
    return "not generated: " .. value
end

-- The state of a Swift row the release and the registry do not answer: generated when the framework's Swift skeleton declares it (ctx.rendered,
-- the keys swiftcode wrote), else declared when the framework's Swift shard names it, else "no snapshot" with the reason (no shard for the
-- framework, or the shard names no such declaration). ctx.swift is the shard's index (nil with no shard).
function swift_state(kind, api, ctx)
    local key = surface.key(kind, swift_shard.canonical_api(api))
    if ctx.rendered[key] then
        return ctx.states.swift_rendered
    end
    if ctx.swift == nil then
        return ctx.states.swift_no_shard
    end
    if ctx.swift[key] then
        return ctx.states.swift_declared
    end
    return ctx.states.swift_not_named
end

-- The keys of the Swift rows a framework's skeleton declares: the <framework>.rendered file swiftcode wrote into dir (the sdk's swift
-- folder). No dir (no skeleton this run) or no file (the module is not rendered) is no key.
local function rendered_of(dir, fw)
    local keys = {}
    if dir == nil then
        return keys
    end
    local filepath = path.join(dir, fw .. ".rendered")
    if os.isfile(filepath) then
        for line in io.lines(filepath) do
            if line ~= "" then
                keys[line] = true
            end
        end
    end
    return keys
end

-- The one state a surface row is in, by the tables (scope_row_state of tools/gen.py@52253c0650). ctx: the framework's facts: led6 (the 6.1.3
-- ledger's statuses by surface.key), registry (the canonical keys a registry row covers), protocols (the objc protocol names), proto
-- (the protocol records), functions (the C function records), class_decisions (the classes.tsv decisions), spec_by_api (the spec
-- rows by api), stub_reason (the trace layer's skip reason by canonical key), stub_keys (the stub keys, or nil with no stubs file),
-- and gap_of (api -> the header parse's gap reason; nil when the framework has no snapshot).
function row_state(kind, api, lang, ctx)
    if ctx.registry[surface.canonical_member(api, kind)] then
        return "overridden"
    end
    local status = ctx.led6[surface.key(kind, api)]
    if status == nil then
        return ctx.unchecked
    end
    if status == HEADER_OK then
        return "header-only (lift): no symbol to generate"
    end
    if lang == "swift" then
        return swift_state(kind, api, ctx)
    end
    if kind == "class" then
        return class_state(api, ctx)
    end
    if kind == "function" and lang == "objc" then
        return function_state(api, ctx)
    end
    if kind == "protocol" and lang == "objc" then
        return protocol_state(api, ctx)
    end
    if kind ~= "method" and kind ~= "property" and kind ~= "constant" then
        return "needs a generator: " .. kind
    end
    if kind == "method" or kind == "property" then
        local owner = string.match(api, "^[%-%+]%[([A-Za-z0-9_]+)") or string.match(api, "^([A-Za-z0-9_]+)%.")
        if owner and ctx.protocols[owner] then
            return protocol_member_state(owner, api, ctx.proto, ctx.states)
        end
        return member_state(kind, api, ctx)
    end
    return constant_state(ctx.spec_by_api[api])
end

-- The gap reason of a method or property the spec does not hold: a bare init, new, copy, mutableCopy, dealloc or description is implicit
-- (NSObject's); a framework the extractor skips takes its reason from the extractor's list (skipped_reason, nil when it parses the
-- framework); any other member is one the parsed framework does not declare.
function gap_reason(api, skipped_reason, states)
    local sel
    if starts_with(api, "-[") or starts_with(api, "+[") then
        sel = string.sub(api, string.find(api, " ", 1, true) + 1, -2)
    else
        local dot = string.find(api, ".", 1, true)
        sel = dot and string.sub(api, dot + 1) or api
    end
    local name = string.match(sel, "^[^:]*")
    if nsobject.scope_implicit(name) then
        return states.init_new
    end
    if skipped_reason then
        return "framework skipped by the extractor: " .. skipped_reason
    end
    return "not in the extractor's parse (the framework is parsed and declares no such member)"
end

-- The work of a state: the kind of work and the next step of its queue entry, or nil when the state is decided. Every open state is
-- queued: a state no entry names gets the fallback entry, so no open state is left out of the queue.
function queue_item(state, states)
    for _, decided in ipairs(states.decided) do
        if starts_with(state, decided) then
            return nil
        end
    end
    for _, entry in ipairs(states.queue_next) do
        if starts_with(state, entry[1]) then
            return entry[2], entry[3]
        end
    end
    return "open state, no queue entry names it", "decide the row by hand: the state names what is missing"
end

-- Sorts the work queue by demand (sort key of tools/gen.py@52253c0650): a ranked row first, by rank; then the demand apps, most first; then the
-- framework and the api, in byte order. A row with the same key keeps the order the table gave it (seq).
function sort_queue(queued)
    table.sort(queued, function(a, b)
        if a.unranked ~= b.unranked then
            return not a.unranked
        end
        if a.rank ~= b.rank then
            return a.rank < b.rank
        end
        if a.apps ~= b.apps then
            return a.apps > b.apps
        end
        if a.fw ~= b.fw then
            return order.less(a.fw, b.fw)
        end
        if a.api ~= b.api then
            return order.less(a.api, b.api)
        end
        return a.seq < b.seq
    end)
    return queued
end

-- The tie-out: the surface rows against the rows of the state totals. Returns the markdown line and the console line.
function tie_out(surface_total, tied)
    local verdict = tied == surface_total and "tie" or "DO NOT TIE"
    return string.format("Tie-out: %d surface rows, %d rows in the state totals: %s.", surface_total, tied, verdict),
        string.format("tie-out: %d surface rows, %d in state totals", surface_total, tied)
end

-- The state totals in the order the page lists them: by count, most first; a tie keeps the order the states were first counted (the
-- stable sort of tools/gen.py@52253c0650). totals: state -> count; first_counted: the states in the order they were first counted.
function ranked_totals(totals, first_counted)
    local rows = {}
    for i, state in ipairs(first_counted) do
        table.insert(rows, {state = state, n = totals[state], first = i})
    end
    table.sort(rows, function(a, b)
        if a.n ~= b.n then
            return a.n > b.n
        end
        return a.first < b.first
    end)
    return rows
end

-- The skip reasons the trace layer recorded (recorded: api -> reason, as its skipped.tsv gives them), by the key the scope reads them by.
-- A class property is recorded by its class accessor (+[Cls name]); the surface names it by its dotted name, which keys as the instance
-- form (-[Cls name]), so the instance key is added beside it (the alias stub_keys takes). facts: the typed facts of the framework.
function reasons_by_key(recorded, facts)
    local out = {}
    for api, reason in pairs(recorded) do
        out[api] = reason
    end
    for _, api in pairs(trace.class_property_apis(facts)) do
        if recorded[api] ~= nil then
            out["-" .. string.sub(api, 2)] = recorded[api]
        end
    end
    return out
end

-- The facts one framework's rows are stated by (the fields row_state reads), from the ledgers, the registry, the trace layer's files and
-- the spec snapshot. Exported: the work list (worklist.lua) states its rows through this same context, so the two cannot drift. skipped
-- is the extractor's skip list (coverage.skipped), which a gap reads by framework.
function context_of(args, fw, rows, owner, states, skipped)
    local tree, corpus = args.tree, args.coordination
    local led6 = surface.ledger_status(corpus, owner, args.ledger_rows or LEDGER_6_1_3)
    local led43 = surface.ledger_status(corpus, owner, LEDGER_4_3)
    local snap = os.isfile(layout.shard_path(tree, fw))
    -- the registry's covered keys, as the trace layer keys them (a class property by its +[...] api); the registry is the owner's
    local registry = trace.overrides_of(tree, owner, headers.shard_facts(tree, fw))
    local stub_keys = trace_files.load_stub_keys(tree, fw)
    if stub_keys ~= nil then
        -- a class property's stub is keyed by its class accessor (+[Cls name]); the surface names it by its dotted name, which keys
        -- as the instance form, so the instance key is added beside it
        for _, api in pairs(trace.class_property_apis(headers.shard_facts(tree, fw))) do
            if stub_keys[api] then
                stub_keys["-" .. string.sub(api, 2)] = true
            end
        end
    end
    local ctx = {
        states = states, led6 = led6, led43 = led43, unchecked = surface.unlisted_state(tree, fw), snap = snap, registry = registry,
        stub_keys = stub_keys, swift = swift_shard.index(tree, fw), rendered = rendered_of(args.swift_rendered, fw),
        spec_by_api = {}, functions = {}, class_decisions = {}, proto = {}, protocols = {},
        stub_reason_of = function() return nil end,
    }
    if snap then
        ctx.proto = protocols.records(tree, fw)
        -- the C functions snapshot is the owner's: an umbrella's functions.tsv holds its nested targets' functions too (Accelerate)
        ctx.functions = functions.load(tree, owner)
        ctx.class_decisions = trace_files.load_class_decisions(tree, fw)
        local spec = snapshot.load(tree, fw)
        ctx.spec_by_api = snapshot.index(spec)
        -- the typed facts of the framework (headers.shard_facts), for the class properties among the recorded skip reasons: read only when one is read
        local parsed = nil
        local function facts_of()
            if parsed == nil then
                parsed = headers.shard_facts(tree, fw)
            end
            return parsed
        end
        -- the reason the trace layer recorded for a member it left out (skipped.tsv), read by a row no stub answers
        local reasons = nil
        ctx.stub_reason_of = function(key)
            if reasons == nil then
                reasons = reasons_by_key(trace_files.load_skip_reasons(tree, fw), facts_of())
            end
            return reasons[key]
        end
        ctx.gap_of = function(api)
            return gap_reason(api, skipped[fw], states)
        end
    end
    -- the protocol names the objc rows of the table name, and the protocols the snapshot holds
    for _, row in ipairs(rows) do
        if row.kind == "protocol" and row.lang == "objc" then
            ctx.protocols[row.api] = true
        end
    end
    for name in pairs(ctx.proto) do
        ctx.protocols[name] = true
    end
    return ctx
end

-- The tally of the run: the counts per framework and kind (in the order they were first counted), the generable keys per framework, the
-- queue, and the stub keys per framework.
local function new_tally()
    return {counts = {}, count_order = {}, generable = {}, queued = {}, stub_sets = {}, surface_total = 0, skipped = {}}
end

-- The count entry of a framework and kind, created on its first row.
local function count_of(tally, fw, kind)
    local key = fw .. "\t" .. kind
    local c = tally.counts[key]
    if c == nil then
        c = {fw = fw, kind = kind, surface = 0, demand_rows = 0, demand_apps = 0, missing_6_1_3 = 0, missing_4_3 = 0,
             states = {}, state_order = {}, unchecked = {objc = 0, swift = 0}}
        tally.counts[key] = c
        table.insert(tally.count_order, c)
    end
    return c
end

local function add_state(c, state)
    if c.states[state] == nil then
        c.states[state] = 0
        table.insert(c.state_order, state)
    end
    c.states[state] = c.states[state] + 1
end

-- The keys a nested target's shard declares, "surface kind<TAB>name" -> the target (a shard row's name is the last part of its usr). A
-- name two targets declare under one kind keeps the first target named; none does (Accelerate, measured).
function declared_by(tree, nested)
    local out = {}
    for _, target in ipairs(nested) do
        for _, r in ipairs(headers.shard_records(tree, target)) do
            local surface_kind = SURFACE_KIND_OF_SHARD[r.kind or ""]
            local name = string.match(r.usr or "", "([^@]+)$")
            if surface_kind ~= nil and name ~= nil then
                local k = surface_kind .. "\t" .. name
                if out[k] == nil then
                    out[k] = target
                end
            end
        end
    end
    return out
end

-- The groups the scope counts, in the order the surface table first names them: {fw, owner, rows}. An umbrella (no-shard.tsv names its
-- targets) has no shard of its own; its objc rows that a nested target's shard declares are counted under that target (its shard, its
-- stubs, its class facts), with the umbrella as the owner (its ledgers and its registry, which name its entries). A row no target
-- declares, and a Swift row, stay under the umbrella.
function counted_groups(tree, all)
    local groups, index = {}, {}
    local function group_of(fw, owner)
        if index[fw] == nil then
            table.insert(groups, {fw = fw, owner = owner, rows = {}})
            index[fw] = #groups
        end
        return groups[index[fw]]
    end
    local umbrellas = targets.umbrellas(tree)
    for _, fw in ipairs(all.order) do
        local umbrella = umbrellas[fw]
        local declared = umbrella and #umbrella.targets > 0 and declared_by(tree, umbrella.targets) or {}
        for _, row in ipairs(all.rows[fw]) do
            local target = nil
            if (row.lang or "objc") == "objc" then
                target = declared[(row.kind or "") .. "\t" .. (string.gsub(row.api or "", "%(%)$", ""))]
            end
            table.insert(group_of(target or fw, fw).rows, row)
        end
    end
    return groups
end

-- Counts the rows of one framework into the tally. owner is the framework whose ledgers and registry the rows are checked against (fw
-- itself when nil).
local function scope_rows(args, fw, rows, tally, owner, states)
    local ctx = context_of(args, fw, rows, owner or fw, states, tally.skipped)
    tally.stub_sets[fw] = ctx.stub_keys or {}
    for _, row in ipairs(rows) do
        local kind = row.kind
        if SCOPE_KINDS[kind] then
            local api = row.api
            local lang = row.lang or "objc"
            local state = (ctx.snap or lang == "swift") and row_state(kind, api, lang, ctx) or NO_SNAPSHOT
            local c = count_of(tally, fw, kind)
            c.surface = c.surface + 1
            local rank = row["demand-rank"]
            local ranked = rank ~= nil and rank ~= ""
            if ranked then
                c.demand_rows = c.demand_rows + 1
                c.demand_apps = c.demand_apps + number_of(row["demand-apps"])
            end
            local k = surface.key(kind, api)
            if ctx.led6[k] ~= nil then
                c.missing_6_1_3 = c.missing_6_1_3 + 1
            end
            if ctx.led43[k] ~= nil then
                c.missing_4_3 = c.missing_4_3 + 1
            end
            add_state(c, state)
            if state == NOT_CHECKED then
                c.unchecked[lang] = (c.unchecked[lang] or 0) + 1
            end
            if GENERABLE_STATES[state] then
                tally.generable[fw] = tally.generable[fw] or {}
                tally.generable[fw][surface.canonical_member(api, kind)] = true
            end
            local work, step = queue_item(state, ctx.states)
            if work then
                local apps = row["demand-apps"]
                if apps == nil or apps == "" then
                    apps = "0"
                end
                table.insert(tally.queued, {fw = fw, kind = kind, api = api, state = state, work = work, step = step,
                                            unranked = not ranked, rank = ranked and tonumber(rank) or 0,
                                            apps = tonumber(apps), rank_text = ranked and rank or "-", apps_text = apps,
                                            seq = #tally.queued + 1})
            end
        end
    end
end

-- The reconciliation: the rows the scope calls generable against the stubs the trace layer wrote. Returns the file's text, the number of
-- generable rows, of stubs and of rows both share, the number of differences, and the number of differences marked "should be empty"
-- (a generable row with no stub: the run fails on those).
local function reconcile(tally)
    local union = {}
    for fw in pairs(tally.generable) do
        union[fw] = true
    end
    for _, c in ipairs(tally.count_order) do
        union[c.fw] = true
    end
    local lines = {"framework\tapi\treason"}
    local generable_total, stubbed_total, both, marked = 0, 0, 0, 0
    for _, fw in ipairs(order.keys(union)) do
        local stubs = tally.stub_sets[fw] or {}
        local gen = tally.generable[fw] or {}
        for api in pairs(stubs) do
            stubbed_total = stubbed_total + 1
            if gen[api] then
                both = both + 1
            end
        end
        for _ in pairs(gen) do
            generable_total = generable_total + 1
        end
        for _, api in ipairs(order.keys(stubs)) do
            if not gen[api] then
                table.insert(lines, fw .. "\t" .. api .. "\ttrace stub that answers no surface row (spec-only member, or a class the surface does not list)")
            end
        end
        for _, api in ipairs(order.keys(gen)) do
            if not stubs[api] then
                table.insert(lines, fw .. "\t" .. api .. "\tsurface row the scope calls generable with no trace stub (should be empty: one definition)")
                marked = marked + 1
            end
        end
    end
    return strings.backslash_replace(table.concat(lines, "\n") .. "\n"), generable_total, stubbed_total, both, #lines - 1, marked
end

-- Returns the exit status: 0 when the tie-out ties and no reconcile difference is marked "should be empty", else 1. The four files are
-- written either way, so a failing run still leaves what it found in --out.
function run(args)
    assert(args.sdk, "scope needs --sdk: the iOS SDK directory (the scope reads the headers)")
    assert(args.coordination, "scope needs --coordination: the corpus folder (the surface table and the ledgers)")
    assert(args.out, "scope needs --out: the folder the four files are written to")
    local sdk_release = sdk_info.discover(args.sdk).version
    local compile = sdk_info.discover(project.sdk16(args)).version
    local states = states_of(sdk_release, compile)
    local all = surface.all_rows(args.tree, args.coordination, sdk_release)
    local tally = new_tally()
    tally.skipped = coverage.skipped(args.tree)
    for _, fw in ipairs(all.order) do
        tally.surface_total = tally.surface_total + #all.rows[fw]
    end
    for _, group in ipairs(counted_groups(args.tree, all)) do
        scope_rows(args, group.fw, group.rows, tally, group.owner, states)
    end

    local reconcile_text, generable_total, stubbed_total, both, differences, marked = reconcile(tally)
    emit.file(path.join(args.out, "v-gen-reconcile.tsv"), reconcile_text)
    print(string.format("reconcile: %d generable rows, %d stubs, %d in both, %d differences (%d marked should be empty) -> v-gen-reconcile.tsv",
                        generable_total, stubbed_total, both, differences, marked))

    local sorted_counts = {}
    for _, c in ipairs(tally.count_order) do
        table.insert(sorted_counts, c)
    end
    table.sort(sorted_counts, function(a, b)
        if a.fw ~= b.fw then
            return order.less(a.fw, b.fw)
        end
        return order.less(a.kind, b.kind)
    end)
    local lines = {"framework\tkind\tsurface_rows\tdemand_rows\tdemand_apps\tmissing_6_1_3\tmissing_4_3\tnot_checked_6_1_3\tnot_checked_objc\tnot_checked_swift\tstates"}
    local queue_total, surface_total_of = {}, {}
    for _, c in ipairs(sorted_counts) do
        local states = {}
        local names = {}
        for _, state in ipairs(c.state_order) do
            table.insert(names, state)
        end
        table.sort(names, order.less)
        for _, state in ipairs(names) do
            table.insert(states, state .. "=" .. c.states[state])
        end
        table.insert(lines, table.concat({c.fw, c.kind, c.surface, c.demand_rows, c.demand_apps, c.missing_6_1_3, c.missing_4_3,
                                          c.states[NOT_CHECKED] or 0, c.unchecked.objc, c.unchecked.swift,
                                          table.concat(states, "; ")}, "\t"))
        queue_total[c.fw] = (queue_total[c.fw] or 0) + c.demand_apps
        surface_total_of[c.fw] = (surface_total_of[c.fw] or 0) + c.surface
    end
    emit.file(path.join(args.out, "v-gen-scope.tsv"), table.concat(lines, "\n") .. "\n")

    local by_demand = order.keys(queue_total)
    table.sort(by_demand, function(a, b)
        if queue_total[a] ~= queue_total[b] then
            return queue_total[a] > queue_total[b]
        end
        return order.less(a, b)
    end)
    local md = {"# v-gen scope: every surface row, counted from the tables", "",
                "Generated by `tools/gen.lua scope` from " .. sdk_info.names(sdk_release).surface .. ", the ledgers (6.1.3 and 4.3), the registry, and the spec snapshots.",
                "", "Work queue by demand (apps that call the framework's rows, summed):", "",
                "| rank | framework | demand apps | surface rows |", "| --- | --- | --- | --- |"}
    for i = 1, math.min(TOP_RANKS, #by_demand) do
        local fw = by_demand[i]
        table.insert(md, string.format("| %d | %s | %d | %d |", i, fw, queue_total[fw], surface_total_of[fw]))
    end

    local totals, totals_order = {}, {}
    for _, c in ipairs(tally.count_order) do
        for _, state in ipairs(c.state_order) do
            if totals[state] == nil then
                totals[state] = 0
                table.insert(totals_order, state)
            end
            totals[state] = totals[state] + c.states[state]
        end
    end
    table.insert(md, "")
    table.insert(md, "State totals over every surface row (each row has exactly one state):")
    table.insert(md, "")
    table.insert(md, "| state | rows |")
    table.insert(md, "| --- | --- |")
    for _, row in ipairs(ranked_totals(totals, totals_order)) do
        table.insert(md, string.format("| %s | %d |", row.state, row.n))
    end
    local unchecked = {objc = 0, swift = 0}
    for _, c in ipairs(tally.count_order) do
        unchecked.objc = unchecked.objc + c.unchecked.objc
        unchecked.swift = unchecked.swift + c.unchecked.swift
    end
    table.insert(md, "")
    table.insert(md, string.format("Not checked at 6.1.3 (a row the ledger does not list): %d rows, objc %d, swift %d.",
                                   totals[NOT_CHECKED] or 0, unchecked.objc, unchecked.swift))

    local queued = sort_queue(tally.queued)
    local queue_lines = {"framework\tkind\tapi\tstate\twork\tnext_step\tdemand_rank\tdemand_apps"}
    local per_work, works = {}, {}
    for _, q in ipairs(queued) do
        table.insert(queue_lines, table.concat({q.fw, q.kind, q.api, q.state, q.work, q.step, q.rank_text, q.apps_text}, "\t"))
        if per_work[q.work] == nil then
            per_work[q.work] = 0
            table.insert(works, q.work)
        end
        per_work[q.work] = per_work[q.work] + 1
    end
    emit.file(path.join(args.out, "v-gen-queue.tsv"), strings.backslash_replace(table.concat(queue_lines, "\n") .. "\n"))
    table.sort(works, order.less)
    for _, work in ipairs(works) do
        print(string.format("queue: %6d  %s", per_work[work], work))
    end

    local tied = 0
    for _, n in pairs(totals) do
        tied = tied + n
    end
    local md_tie, console_tie = tie_out(tally.surface_total, tied)
    table.insert(md, "")
    table.insert(md, md_tie)
    emit.file(path.join(args.out, "v-gen-scope.md"), table.concat(md, "\n") .. "\n")
    print(console_tie)
    print(string.format("scope: %d framework-kind rows, %d frameworks -> %s", #tally.count_order, #by_demand,
                        path.join(args.out, "v-gen-scope.tsv")))
    local status = 0
    if tied ~= tally.surface_total then
        print(string.format("scope: DO NOT TIE: %d surface rows, %d rows in the state totals", tally.surface_total, tied))
        status = 1
    end
    if marked > 0 then
        print(string.format("scope: %d reconcile difference(s) marked should be empty, see v-gen-reconcile.tsv", marked))
        status = 1
    end
    return status
end
