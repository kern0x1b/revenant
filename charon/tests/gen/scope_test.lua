local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")

local scope = import("gen.cmd_scope", {rootdir = TOOLS, anonymous = true})
local surface = import("gen.surface", {rootdir = TOOLS, anonymous = true})
local coverage = import("gen.coverage", {rootdir = TOOLS, anonymous = true})
local strings = import("gen.strings", {rootdir = TOOLS, anonymous = true})
local swift_shard = import("gen.swift_shard", {rootdir = TOOLS, anonymous = true})

local function checks()
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end
    return check, function() return failures end
end

local function empty_context()
    return {
        states = scope.states_of("26.2", "16.4"), led6 = {}, registry = {}, protocols = {}, proto = {}, functions = {}, class_decisions = {}, spec_by_api = {},
        stub_reason_of = function() return nil end, stub_keys = {}, gap_of = nil, unchecked = surface.not_checked_state(),
        rendered = {},
    }
end

local function test_states(check)
    local ctx = empty_context()
    local function missing(kind, api)
        ctx.led6[surface.key(kind, api)] = "missing"
    end
    missing("method", "-[Thing reset]")
    missing("method", "-[Thing setLevel:error:]")
    missing("method", "-[Thing lift]")
    ctx.led6[surface.key("method", "-[Thing lift]")] = "header-ok"
    ctx.stub_keys["-[Thing reset]"] = true
    ctx.spec_by_api["-[Thing reset]"] = {kind = "method", api = "-[Thing reset]"}
    ctx.spec_by_api["-[Thing setLevel:error:]"] = {kind = "method", api = "-[Thing setLevel:error:]"}
    check(scope.row_state("method", "-[Thing items]", "objc", ctx) == "not checked at 6.1.3",
          "a row the 6.1.3 ledger does not list is not checked there, and never implemented")
    ctx.unchecked = "absent at 6.1.3"
    check(scope.row_state("method", "-[Thing items]", "objc", ctx) == "absent at 6.1.3",
          "a row the ledger does not list, of a framework absent from 6.1.3, is absent at 6.1.3")
    ctx.unchecked = surface.not_checked_state()
    check(scope.row_state("method", "-[Thing lift]", "objc", ctx) == "header-only (lift): no symbol to generate",
          "a header-ok row is header-only")
    check(scope.row_state("method", "-[Thing reset]", "objc", ctx) == "generable stub", "a stubbed member is a generable stub")
    ctx.stub_reason_of = function(key) return key == "-[Thing setLevel:error:]" and "type not declared for iOS: NSFoo" or nil end
    check(scope.row_state("method", "-[Thing setLevel:error:]", "objc", ctx) == "not declared for iOS",
          "a member whose type iOS does not declare is not declared for iOS")
    ctx.registry["-[Thing legacy]"] = true
    missing("method", "-[Thing legacy]")
    check(scope.row_state("method", "-[Thing legacy]", "objc", ctx) == "overridden", "a registry row answers the state first")
    missing("property", "Thing.swiftOnly")
    check(scope.row_state("property", "Thing.swiftOnly", "swift", ctx) == "no snapshot: no Swift shard for the framework",
          "a swift row of a framework with no Swift shard is no snapshot, with its reason")
    missing("constant", "FKLimit")
    ctx.spec_by_api["FKLimit"] = {owned = "-", tbd = "exported", value_status = "found"}
    check(scope.row_state("constant", "FKLimit", "objc", ctx) == "generable constant", "an exported string constant is generable")
    missing("class", "Thing")
    ctx.class_decisions["Thing"] = {generated = false, reason = "the package's own sources define the class"}
    check(scope.row_state("class", "Thing", "objc", ctx) == "class object: hand code covers it (not generated)",
          "a class the package defines is hand code")
    missing("method", "-[Other sel]")
    ctx.gap_of = function() return "spelled by the headers, not parsed (parse gap)" end
    check(scope.row_state("method", "-[Other sel]", "objc", ctx) == "spelled by the headers, not parsed (parse gap)",
          "a member the spec does not hold takes its gap reason")
    missing("function", "CFOo()")
    ctx.functions["CFOo()"] = {status = "generable", reasons = ""}
    check(scope.row_state("function", "CFOo()", "objc", ctx) == "C function: generable stub (trace layer)",
          "a generable C function is a stub of the trace layer")
    missing("method", "-[Pl reset]")
    ctx.protocols["Pl"] = true
    ctx.proto["Pl"] = {status = "transcribed", members = {{selector = "reset", in16 = "-"}}}
    check(scope.row_state("method", "-[Pl reset]", "objc", ctx) == "protocol member: in the transcribed protocol header",
          "a protocol member of a transcribed protocol is in its header")
end

local function test_gaps_and_queue(check)
    local states = scope.states_of("26.2", "16.4")
    check(scope.gap_reason("-[Thing init]", nil, states) ==
          "init/new: not spelled by the 26.2 headers (implicit, or unavailable by a macro)", "a bare init is implicit")
    check(scope.gap_reason("-[Thing init]", "no Objective-C or C header", states) ==
          "init/new: not spelled by the 26.2 headers (implicit, or unavailable by a macro)", "an init stays implicit in a skipped framework")
    check(scope.gap_reason("-[Thing reset]", nil, states) == "not in the extractor's parse (the framework is parsed and declares no such member)",
          "a member of a parsed framework that the spec lacks is not in the parse")
    check(scope.gap_reason("-[Thing reset]", "no Objective-C or C header; Swift interface only", states)
          == "framework skipped by the extractor: no Objective-C or C header; Swift interface only",
          "a member of a framework the extractor skips takes the list's reason")
    check(scope.queue_item("generable stub", states) == nil, "a decided state is not queued")
    check(scope.queue_item("not checked at 6.1.3", states) ~= nil, "a row the 6.1.3 ledger does not list is queued as work, not decided")
    check(scope.queue_item("not in the extractor's parse (the framework is parsed and declares no such member)", states)
          == "member the parse of a parsed framework does not declare", "a member the parse does not hold is queued")
    check(scope.queue_item("framework skipped by the extractor: x", states) == "member of a framework the extractor skips",
          "a member of a skipped framework is queued")

    local function item(fw, api, rank, apps, seq)
        return {fw = fw, api = api, unranked = rank == nil, rank = rank or 0, apps = apps, seq = seq}
    end
    local queued = {
        item("Y", "-[Y c]", nil, 50, 1),
        item("X", "-[X b]", 2, 100, 2),
        item("X", "-[X a]", 1, 5, 3),
        item("X", "-[X d]", 1, 9, 4),
        item("X", "z", nil, 50, 5),
        item("X", "a", nil, 50, 6),
        item("X", "-[X b]", 1, 9, 7),
    }
    local sorted = scope.sort_queue(queued)
    local got = {}
    for _, q in ipairs(sorted) do
        table.insert(got, q.seq)
    end
    check(table.concat(got, ",") == "7,4,3,2,6,5,1", "the queue is ranked first, by apps, by framework and api, then by table order: got "
          .. table.concat(got, ","))
end

local function test_tie_out(check)
    local md, console = scope.tie_out(10, 10)
    check(md == "Tie-out: 10 surface rows, 10 rows in the state totals: tie.", "a tie-out that ties reads tie")
    check(console == "tie-out: 10 surface rows, 10 in state totals", "the console tie-out line")
    local untied = scope.tie_out(10, 9)
    check(untied == "Tie-out: 10 surface rows, 9 rows in the state totals: DO NOT TIE.", "a tie-out that does not tie says so")
    local ranked = scope.ranked_totals({a = 2, b = 3, c = 2}, {"a", "b", "c"})
    local names = {}
    for _, r in ipairs(ranked) do
        table.insert(names, r.state)
    end
    check(table.concat(names, ",") == "b,a,c", "state totals: most first, a tie in the order first counted")
end

local function test_escapes(check)
    check(strings.backslash_replace("norwegianBokm\195\165l") == "norwegianBokm\\xe5l", "a code point below 0x100 is \\xhh")
    check(strings.backslash_replace("a\226\128\153b") == "a\\u2019b", "a code point below 0x10000 is \\uhhhh")
    check(strings.backslash_replace("x\240\159\152\128") == "x\\U0001f600", "a code point above is \\Uhhhhhhhh")
    check(strings.backslash_replace("plain") == "plain", "ASCII passes through")
end

local LIST_TEXT = [==[# the frameworks of the SDK with no declaration the extractor reads, and why: one line each
Charts	parsed (Swift interface)	no Objective-C or C header; Swift interface only
AutomaticAssessmentConfiguration/AACClient	no declarations	no public header in Headers/ and no module map header
]==]

local function test_coverage(check)
    local listed = coverage.parse(LIST_TEXT)
    check(listed["Charts"] == "no Objective-C or C header; Swift interface only", "the list gives a framework's reason")
    check(listed["AutomaticAssessmentConfiguration/AACClient"] == "no public header in Headers/ and no module map header",
          "a subframework is its own entry")
    local count = 0
    for _ in pairs(listed) do
        count = count + 1
    end
    check(count == 2, "the comment line is no entry (got " .. count .. ")")
end

local function test_function_reasons(check)
    local ctx = empty_context()
    local recorded = {["CFHand()"] = "override or hand implementation", ["CFBad()"] = "type not resolved: kern_return_t"}
    ctx.stub_reason_of = function(key) return recorded[key] end
    for _, api in ipairs({"CFHand()", "CFBad()", "CFStub()"}) do
        ctx.led6[surface.key("function", api)] = "missing"
        ctx.functions[api] = {status = "generable", reasons = ""}
    end
    check(scope.row_state("function", "CFHand()", "objc", ctx) == "hand implementation (no registry row)",
          "a generable C function the port defines by hand reports that")
    check(scope.row_state("function", "CFBad()", "objc", ctx) == "C function: not stubbed: type not resolved: kern_return_t",
          "a generable C function the trace layer left out reports its recorded reason")
    check(scope.row_state("function", "CFStub()", "objc", ctx) == "C function: generable stub (trace layer)",
          "a generable C function with no recorded reason is a stub of the trace layer")
end

local function test_swift_rows(check)
    local tree = path.join(TOOLS, "..")
    local api = "AVAudioSession.Location.orientationTop"
    local ctx = empty_context()
    ctx.led6[surface.key("property", api)] = "missing"
    ctx.swift = swift_shard.index(tree, "AVFAudio")
    local declared = scope.row_state("property", api, "swift", ctx)
    check(declared == "swift: declared in the 26.2 Swift shard (not generated: no Swift generator)",
          "a seeded Swift row named by the committed shard gets the declared state, got: " .. declared)
    ctx.rendered[surface.key("property", swift_shard.canonical_api(api))] = true
    check(scope.row_state("property", api, "swift", ctx) == "swift: rendered by the Swift skeleton (generated stub)",
          "a Swift row the skeleton renders is a generated stub")
    ctx.rendered = {}
    local unnamed = "AVAudioSession.Location.noSuchMember"
    ctx.led6[surface.key("property", unnamed)] = "missing"
    check(scope.row_state("property", unnamed, "swift", ctx)
          == "no snapshot: the Swift shard names no declaration for this api", "a row no shard names is no snapshot")
    ctx.swift = nil
    check(scope.row_state("property", api, "swift", ctx) == "no snapshot: no Swift shard for the framework",
          "a framework with no Swift shard says so")
    local case_api = "ARCamera.TrackingState.Reason.excessiveMotion"
    local case_ctx = empty_context()
    case_ctx.led6[surface.key("constant", case_api)] = "missing"
    case_ctx.led6[surface.key("property", case_api)] = "missing"
    case_ctx.swift = swift_shard.index(tree, "ARKit")
    check(scope.row_state("constant", case_api, "swift", case_ctx) == "swift: declared in the 26.2 Swift shard (not generated: no Swift generator)",
          "a Swift enum case the committed shard names as constant gets the declared state")
    check(scope.row_state("property", case_api, "swift", case_ctx) == "no snapshot: the Swift shard names no declaration for this api",
          "an enum case is not a property row")
    local op_api = "ARCamera.TrackingState.Reason.==(a:b:)"
    local op_ctx = empty_context()
    op_ctx.led6[surface.key("method", op_api)] = "missing"
    op_ctx.swift = swift_shard.index(tree, "ARKit")
    check(scope.row_state("method", op_api, "swift", op_ctx) == "swift: declared in the 26.2 Swift shard (not generated: no Swift generator)",
          "a Swift operator with the surface's labels is declared by the shard's underscore labels")
    check(swift_shard.canonical_api("==(lhs:rhs:)") == "==(_:_:)", "an operator's labels are keyed by arity")
    check(swift_shard.canonical_api("Foo.<(a:b:)") == "Foo.<(_:_:)", "an operator in a type is keyed by arity")
    check(swift_shard.canonical_api("init?(colorSpace:components:)") == "init(colorSpace:components:)", "a failable initializer keeps its labels, without the ?")
    check(swift_shard.canonical_api("ColorScheme.init?(_:)") == swift_shard.canonical_api("ColorScheme.init(_:)"),
          "a failable initializer is the key of its non-failable form (the dump prints no ? on a constructor)")
    check(swift_shard.canonical_api("Column.subscript(position:)") == "Column.subscript(_:)",
          "a subscript is keyed by its arity (TabularData's subscript(position:) is the dump's subscript(_:))")
    check(swift_shard.canonical_api("subscript(_:)") == "subscript(_:)", "a subscript keeps its labels")
    check(swift_shard.canonical_api("count") == "count", "a property is its own key")
    local underscore_api = "_UIHostingView._viewDebugData()"
    local underscore_ctx = empty_context()
    underscore_ctx.led6[surface.key("method", underscore_api)] = "missing"
    underscore_ctx.swift = swift_shard.index(tree, "SwiftUI")
    check(scope.row_state("method", underscore_api, "swift", underscore_ctx)
          == "swift: declared in the 26.2 Swift shard (not generated: no Swift generator)",
          "an underscore-named declaration the ABI dump carries is named by the shard")
    check(swift_shard.index(tree, "SwiftUI")["class\t_UIHostingView"] == true,
          "the shard carries the underscore-named class itself")
end

local function test_recorded_reasons(check)
    local facts = {members = {{kind = "property", api = "+[SCNNode simdLocalFront]", alias = "SCNNode.simdLocalFront"}}}
    local recorded = {["+[SCNNode simdLocalFront]"] = "type not resolved: simd_float3", ["-[SCNNode simdLocalUp]"] = "override or hand implementation"}
    local keyed = scope.reasons_by_key(recorded, facts)
    check(keyed["-[SCNNode simdLocalFront]"] == "type not resolved: simd_float3", "a class property's reason is keyed by its instance form")
    check(keyed["+[SCNNode simdLocalFront]"] == "type not resolved: simd_float3", "a class property keeps its accessor key")
    check(keyed["-[SCNNode simdLocalUp]"] == "override or hand implementation", "an instance member's reason keeps its key")
    local ctx = empty_context()
    ctx.led6[surface.key("property", "SCNNode.simdLocalFront")] = "missing"
    ctx.spec_by_api["SCNNode.simdLocalFront"] = {kind = "property", api = "+[SCNNode simdLocalFront]"}
    ctx.stub_reason_of = function(key) return keyed[key] end
    check(scope.row_state("property", "SCNNode.simdLocalFront", "objc", ctx) == "not stubbed: type not resolved: simd_float3",
          "a class property the trace layer left out reports its recorded reason")
end

local function test_counted_groups(check)
    local ROOT = path.absolute(path.join(os.scriptdir(), "..", ".."))
    local all = {
        order = {"Accelerate"},
        rows = {Accelerate = {
            {kind = "function", api = "vImageConvert_BGRAFFFFtoRGBFFF()", lang = "objc", framework = "Accelerate"},
            {kind = "function", api = "vDSP.convolve(_:rowCount:)", lang = "swift", framework = "Accelerate"},
            {kind = "function", api = "NoSuchDeclaration()", lang = "objc", framework = "Accelerate"},
        }},
    }
    local groups = scope.counted_groups(ROOT, all)
    check(#groups == 2, "counted_groups: the umbrella's rows split into the nested target and the umbrella")
    check(groups[1].fw == "Accelerate/vImage" and groups[1].owner == "Accelerate" and #groups[1].rows == 1,
          "counted_groups: the declared C row is counted under Accelerate/vImage, owned by Accelerate")
    check(groups[2].fw == "Accelerate" and groups[2].owner == "Accelerate" and #groups[2].rows == 2,
          "counted_groups: the Swift row and the undeclared row stay under Accelerate")
end

function main()
    local check, failures = checks()
    test_states(check)
    test_gaps_and_queue(check)
    test_tie_out(check)
    test_escapes(check)
    test_coverage(check)
    test_recorded_reasons(check)
    test_function_reasons(check)
    test_counted_groups(check)
    test_swift_rows(check)
    print("scope test: " .. (failures() == 0 and "OK" or ("FAIL " .. failures())))
    if failures() > 0 then
        os.exit(1)
    end
end
