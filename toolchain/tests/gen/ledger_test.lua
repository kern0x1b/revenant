local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")

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

local function decl(fw, kind, api, usr, getter)
    return {framework = fw, claimed_by = fw, kind = kind, lang = "objc", api = api, usr = usr or "", getter = getter or "-"}
end

function main()
    local check, failures = checks()
    local ledger = import("gen.ledger", {rootdir = TOOLS, anonymous = true})

    local objc = table.concat({
        "class\tUIView\tUIResponder\t/System/Library/Frameworks/UIKit.framework/UIKit\t-setFrame:,-frame\t+animateWithDuration:\tNSCoding",
        "protocol\tNSLocking\t\t\t-lock,-unlock\t\t",
        "class\tAVPlayer\tNSObject\tAVFoundation\t\t\t",
    }, "\n")
    local exports = "_NSLog\tFoundation\n_OBJC_CLASS_$_UIView\tUIKit\n"
    local facts = ledger.parse_facts(objc, exports)
    check(facts.classes.UIView ~= nil and facts.classes.UIView.inst["setFrame:"] == true,
          "an instance selector is read without its sign (got " .. tostring(facts.classes.UIView and facts.classes.UIView.inst["setFrame:"]) .. ")")
    check(facts.classes.UIView.inst["-setFrame:"] == nil, "the sign is not kept in the name")
    check(facts.classes.UIView.cls["animateWithDuration:"] == true and facts.classes.UIView.inst["animateWithDuration:"] == nil,
          "a class selector is told apart by its field, not by its sign")
    check(facts.protocols.NSLocking.inst.lock == true, "a protocol's instance selectors are read")
    check(facts.exports._NSLog == true and facts.exports["_OBJC_CLASS_$_UIView"] == true,
          "exports are read by their linker symbol, underscore kept")

    check(ledger.check(decl("UIKit", "class", "UIView"), facts) == "present", "an ObjC class in the cache is present")
    check(ledger.check(decl("X", "class", "XYZMissing"), facts) == "absent", "an ObjC class not in the cache is absent")
    check(ledger.check(decl("UIKit", "protocol", "NSLocking"), facts) == "present", "a protocol in the cache is present")
    check(ledger.check(decl("UIKit", "method", "-[UIView setFrame:]"), facts) == "present", "an instance method in the cache is present")
    check(ledger.check(decl("UIKit", "method", "-[UIView make]"), facts) == "absent", "an instance method not in the cache is absent")
    check(ledger.check(decl("UIKit", "method", "+[UIView animateWithDuration:]"), facts) == "present",
          "a class method is checked on the class side")
    check(ledger.check(decl("UIKit", "method", "-[UIView animateWithDuration:]"), facts) == "absent",
          "an instance method is not satisfied by a class selector of the same name")
    check(ledger.check(decl("UIKit", "property", "UIView.frame", nil, "frame"), facts) == "present",
          "a property is checked by its getter")
    check(ledger.check(decl("UIKit", "property", "UIView.bounds", nil, "-"), facts) == "absent",
          "a property with no getter is checked by its name, and absent when the cache lacks it")
    check(ledger.check(decl("X", "method", "-[Gone make]"), facts) == "absent", "a method of a class not in the cache is absent")
    check(ledger.check(decl("F", "function", "NSLog()"), facts) == "present", "a function in the cache is present by its symbol")
    check(ledger.check(decl("F", "function", "NSMissing()"), facts) == nil, "a C function missing from the cache, no .tbd export: no evidence")
    check(ledger.check(decl("F", "function", "NSMissing()"), facts, {}) == nil, "an empty export set proves nothing either")
    check(ledger.check(decl("F", "function", "NSMissing()"), facts, {NSMissing = true}) == "absent",
          "a C function the 26.2 .tbd exports and the cache lacks is absent")
    check(ledger.check(decl("F", "constant", "NSMissingConst"), facts, {NSMissingConst = true}) == "absent",
          "a C constant the 26.2 .tbd exports and the cache lacks is absent")
    check(ledger.check(decl("F", "function", "NSLog()"), facts, {}) == "present", "a C function in the cache is present whatever the .tbd says")
    check(ledger.check(decl("F", "enum", "NSThing"), facts) == nil, "an enum is not checkable by the cache")
    check(ledger.check(decl("F", "struct", "NSRect2"), facts) == nil, "a struct is not checkable by the cache")
    local member = decl("F", "constant", "kThingA", "c:@EA@thing@kThingA@")
    check(ledger.check(member, facts) == nil, "an enum member (c:@E..@..@) is not checkable: it has no symbol of its own")
    check(ledger.check(decl("F", "constant", "kGlobal", "c:@kGlobal"), facts, {kGlobal = true}) == "absent",
          "a global constant the .tbd exports is checkable by its symbol")

    local decls = {
        RuntimeHere = {decl("RuntimeHere", "class", "UIView"), decl("RuntimeHere", "class", "Gone")},
        RuntimeGone = {decl("RuntimeGone", "class", "Gone"), decl("RuntimeGone", "method", "-[Gone make]")},
        COnly = {decl("COnly", "function", "NSMissing()"), decl("COnly", "constant", "NSMissingConst")},
        MixedFn = {decl("MixedFn", "class", "Gone"), decl("MixedFn", "function", "NSLog()")},
        Types = {decl("Types", "enum", "NSThing")},
        Borrower = {decl("RuntimeGone", "class", "Gone")},
    }
    decls.Borrower[1].claimed_by = "MixedFn"
    local verdicts = ledger.verdicts(decls, facts)
    check(verdicts.RuntimeHere.verdict == "present", "a framework with a declaration in the cache is present")
    check(verdicts.RuntimeGone.verdict == "absent", "a framework whose runtime declarations are all missing is absent")
    check(verdicts.RuntimeGone.checkable == 2 and verdicts.RuntimeGone.present == 0, "absent counts its runtime declarations")
    check(verdicts.COnly.verdict == "undecided", "C symbols alone are undecided: a static inline function has none (got " .. verdicts.COnly.verdict .. ")")
    check(verdicts.MixedFn.verdict == "present", "a C symbol in the cache is presence even beside a missing class")
    check(verdicts.Types.verdict == "undecided", "a framework of types only is undecided")
    check(verdicts.Types.checkable == 0, "a type is not counted as checkable")
    check(verdicts.RuntimeGone.reason:find("Gone", 1, true) ~= nil, "an absent verdict names the first missing declaration")
    check(verdicts.Borrower.verdict == "undecided" and verdicts.Borrower.checkable == 0,
          "a shard whose only declaration another framework owns gives it nothing (got " .. verdicts.Borrower.verdict .. ")")

    local exported = function(unit)
        if unit == "COnly" then
            return {NSMissing = true, NSMissingConst = true}
        end
        return {}
    end
    local with_tbd = ledger.verdicts(decls, facts, exported)
    check(with_tbd.COnly.verdict == "absent" and with_tbd.COnly.checkable == 2,
          "a C-only framework the .tbd exports, absent from the cache, is absent (got " .. with_tbd.COnly.verdict .. ")")
    check(with_tbd.Types.verdict == "undecided", "a framework with no runtime or exported C declaration stays undecided")

    local sub = decl("Outer", "class", "Gone")
    sub.unit = "Outer/Sub"
    local nested = {Outer = {decl("Outer", "class", "UIView"), sub}}
    local both = ledger.verdicts(nested, facts)
    check(both["Outer/Sub"] ~= nil and both["Outer/Sub"].verdict == "absent" and both["Outer/Sub"].checkable == 1,
          "a nested unit has its own verdict over its own declarations (got " .. tostring(both["Outer/Sub"] and both["Outer/Sub"].verdict) .. ")")
    check(both.Outer.verdict == "present" and both.Outer.checkable == 2 and both.Outer.present == 1,
          "the outer framework still aggregates all of its declarations (got checkable " .. tostring(both.Outer.checkable) .. ")")

    local built = ledger.parse_facts("class\tUIView\t\t\t-addSub:\t\t\nclass\tARSession\t\t\t-run:\t\t", "_NSBuilt\tlib")
    local both = ledger.merge(ledger.parse_facts(objc, exports), built)
    check(both.classes.UIView.inst["setFrame:"] == true and both.classes.UIView.inst["addSub:"] == true,
          "a built library's selectors join the cache's")
    check(both.classes.ARSession ~= nil and both.exports._NSBuilt == true and both.exports._NSLog == true,
          "a built library's classes and exports are added, the cache's kept")

    local status, needs = ledger.state_of(decl("UIKit", "class", "UIView"), facts)
    check(status == "implemented" and needs == "none", "a class in the cache is implemented (got " .. tostring(status) .. ")")
    status, needs = ledger.state_of(decl("X", "class", "XYZMissing"), facts)
    check(status == "missing" and needs == "code", "a class in neither the cache nor the libraries is missing")
    status, needs = ledger.state_of(decl("F", "function", "NSMissing()"), facts)
    check(status == "undecided" and needs == "lift", "a C declaration neither source shows is undecided until the lifted headers")
    status = ledger.state_of(decl("F", "function", "NSMissing()"), facts, {NSMissing = true})
    check(status == "missing", "a C declaration the .tbd exports and the cache lacks is missing")
    local swift = {framework = "F", claimed_by = "F", kind = "method", lang = "swift", api = "Thing.run()", usr = "", getter = "-"}
    status, needs = ledger.state_of(swift, facts)
    check(status == "undecided" and needs == "swift-module", "a Swift declaration is undecided without the cache's Swift proof")

    local swift_only = {framework = "F", claimed_by = "F", kind = "method", lang = "swift", api = "Thing.run()", usr = "s:1F5ThingC3runyyF",
                        getter = "-"}
    local plain_images = "/usr/lib/libSystem.B.dylib\t4938\n/System/Library/Frameworks/Foundation.framework/Foundation\t9\n"
    local proved = ledger.parse_facts(objc, exports, plain_images)
    check(proved.swift ~= nil and proved.swift.holds, "a cache with no Swift image and no Swift export holds no Swift")
    local reason
    status, needs, reason = ledger.state_of(swift_only, proved)
    check(status == "missing" and needs == "code" and string.find(reason, "holds no Swift runtime", 1, true) ~= nil,
          "a Swift-only declaration is missing at a cache with no Swift, with the proof in its reason")
    local with_swift = ledger.parse_facts(objc, exports .. "_$sSo3NSObjCN\tlibswiftCore.dylib\n", "/usr/lib/swift/libswiftCore.dylib\t3\n")
    check(not with_swift.swift.holds, "a cache with a libswift* image or a Swift export does not hold the proof")
    status = ledger.state_of(swift_only, with_swift)
    check(status == "undecided", "without the proof a Swift-only declaration stays undecided")

    local twin = decl("F", "class", "UIView", "c:objc(cs)UIView")
    local swift_import = {framework = "F", claimed_by = "F", kind = "class", lang = "swift", api = "UIView", usr = "c:objc(cs)UIView", getter = "-"}
    local twins = ledger.twins_of(ledger.rows_of({twin}, facts, function() return {} end))
    local imported = ledger.rows_of({swift_import}, facts, function() return {} end, nil, twins)
    check(#imported == 1 and imported[1].status == "implemented" and string.find(imported[1].reason, "the import of class UIView", 1, true) ~= nil,
          "an import takes its twin's state, and says so")
    local unmatched = ledger.rows_of({swift_import}, facts, function() return {} end, nil, {})
    check(unmatched[1].status == "undecided" and unmatched[1].needs == "lift", "an import with no twin in the model is undecided")
    local macro = {framework = "F", claimed_by = "F", kind = "constant", lang = "swift", api = "F_VERSION", usr = "c:@macro@F_VERSION",
                   getter = "-"}
    local macro_row = ledger.rows_of({macro}, facts, function() return {} end, nil, {})
    check(string.find(macro_row[1].reason, "a C macro", 1, true) ~= nil, "an import of a C macro says so")

    local records = {decl("UIKit", "class", "XYZMissing"), decl("UIKit", "class", "UIView"), decl("UIKit", "class", "UIView"),
                     decl("UIKit", "function", "NSLog()")}
    records[2].introduced = "2.0"
    local list = ledger.rows_of(records, facts, function() return {} end)
    check(#list == 3, "a row per key: the repeated UIView is one row (got " .. #list .. ")")
    check(list[1].api == "UIView" and list[1].status == "implemented" and list[1].introduced == "2.0",
          "the first row is UIView, implemented, with its introduction")
    check(list[2].api == "XYZMissing" and list[2].status == "missing" and list[3].kind == "function",
          "rows are sorted by kind, then api")
    local text = ledger.rows_text(list)
    check(string.match(text, "^[^\n]*") == "kind\tlang\tapi\tintroduced\theader-introduced\tstatus\tneeds\treason",
          "the ledger's header is ledger-w45's columns")
    check(#ledger.split(string.match(text, "\n([^\n]*)"), "\t") == 8, "a row has eight columns")

    local header_pass = import("gen.header_pass", {rootdir = TOOLS, anonymous = true})
    check(header_pass.statement_of("function", "NSLog()") == "(void)(NSLog);", "a function is named by its name, without the call")
    check(header_pass.statement_of("method", "UIView.run") == nil, "a method is not named by the header pass")
    local source = "/x/AVFAudio.m"
    local compiler = table.concat({
        "/x/AVFAudio.m:3:9: warning: 'AVAudioSessionModeVideoChat' is only available on iOS 15.0 or newer [-Wunguarded-availability-new]",
        "/x/AVFAudio.m:3:9: note: 'AVAudioSessionModeVideoChat' has been explicitly marked partial here",
        "/x/AVFAudio.m:4:9: error: use of undeclared identifier 'Nope'",
        "/x/AVFAudio.m:5:9: warning: 'Dep' is deprecated [-Wdeprecated-declarations]",
        "/x/AVFAudio.m:6:9: error: 'Gone' is unavailable",
    }, "\n")
    local diagnostics = header_pass.diagnostics_of(compiler, source)
    check(diagnostics[3] and diagnostics[3].class == "available" and diagnostics[3].version == "15.0", "an availability warning is the answer, with its version")
    check(diagnostics[4] and diagnostics[4].class == "undeclared", "an undeclared identifier is the undeclared answer")
    check(diagnostics[5] == nil, "a deprecation warning is no answer")
    check(diagnostics[6] and diagnostics[6].class == "unavailable", "an unavailable mark is the unavailable answer")
    check(header_pass.answer_of(nil, "6.1.3").status == "header-ok", "a name with no diagnostic is header-ok")
    check(header_pass.answer_of(diagnostics[3], "6.1.3").status == "missing", "an introduction after the release is missing")
    check(header_pass.answer_of(diagnostics[4], "6.1.3").status == "undecided", "an undeclared name is undecided")
    local probe, line_of = header_pass.probe_of("AVFAudio", {"AVAudioSession.h"}, {"(void)(X);", "(void)(Y);"})
    check(probe == "#import <AVFAudio/AVAudioSession.h>\nvoid revenant_probe(void) {\n(void)(X);\n(void)(Y);\n}\n",
          "the probe imports the headers and names each declaration on its own line")
    check(line_of[3] == 1 and line_of[4] == 2, "each statement's line is kept")

    print("ledger test: " .. (failures() == 0 and "OK" or ("FAIL " .. failures())))
    if failures() > 0 then
        os.exit(1)
    end
end
