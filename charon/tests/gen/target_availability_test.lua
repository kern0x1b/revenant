local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")

local function row(kind, usr, name, avail, typ, params, container)
    return {"ARKit", kind, usr, container or "-", name, "-", "Header.h", "1", avail or "-", "-", typ or "-", params or "-"}
end

local function entry(api, kind, status, minimum)
    return {api = api, kind = kind, status = status, minimum = minimum}
end

local function run()
    local rule = import("gen.target_availability", {rootdir = TOOLS, anonymous = true})
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end
    local function avail_of(r)
        return r[9]
    end

    local method = row("method", "c:objc(cs)Foo(im)bar", "bar", "ios=13.0/-/-/0", "void")
    local changes, counts, blocked
    changes, counts = rule.plan({method}, {["-[Foo bar]"] = entry("-[Foo bar]", "method", "implemented", "6.0")}, "6.1.3")
    check(avail_of(method) == "ios=13.0/-/-/0", "plan does not write the rows it plans")
    check(#changes == 1 and changes[1].to == "6.1.3" and counts.own == 1, "an implemented method is lowered to the release, by its own entry")
    rule.apply({method}, {["-[Foo bar]"] = entry("-[Foo bar]", "method", "implemented", "6.0")}, "6.1.3")
    check(avail_of(method) == "ios=6.1.3/-/-/0", "apply writes the lowered mark into the row")

    local late = row("method", "c:objc(cs)Foo(im)late", "late", "ios=13.0/-/-/0", "void")
    changes = rule.plan({late}, {["-[Foo late]"] = entry("-[Foo late]", "method", "implemented", "7.0")}, "6.1.3")
    check(#changes == 1 and changes[1].to == "7.0", "a minimum later than the release is the target")

    local other = row("method", "c:objc(cs)Foo(im)bar", "bar", "ios=13.0/-/-/0", "void")
    changes = rule.plan({other}, {["-[Foo bar]"] = entry("-[Foo bar]", "method", "implemented", "6.0")}, "7.5")
    check(#changes == 1 and changes[1].to == "7.5", "the release comes from the caller, not from a literal in the rule")

    changes = rule.plan({method}, {["-[Foo bar]"] = entry("-[Foo bar]", "method", "owed", "6.0")}, "6.1.3")
    check(#changes == 0, "an owed entry keeps its SDK mark")
    changes = rule.plan({method}, {}, "6.1.3")
    check(#changes == 0, "a declaration no entry names keeps its SDK mark")

    local early = row("method", "c:objc(cs)Foo(im)early", "early", "ios=5.0/-/-/0", "void")
    changes = rule.plan({early}, {["-[Foo early]"] = entry("-[Foo early]", "method", "implemented", "6.0")}, "6.1.3")
    check(#changes == 0, "a mark at or below the release is kept")

    local class = row("interface", "c:objc(cs)Foo", "Foo", "ios=13.0/-/-/0")
    local member = row("property", "c:objc(cs)Foo(py)baz", "baz", "ios=13.0/-/-/0", "NSInteger")
    local own_owed = row("property", "c:objc(cs)Foo(py)owed", "owed", "ios=13.0/-/-/0", "NSInteger")
    local registry = {Foo = entry("Foo", "class", "implemented", "6.0"), ["Foo.owed"] = entry("Foo.owed", "property", "owed", "6.0")}
    changes = rule.plan({class, member, own_owed}, registry, "6.1.3")
    local lowered_member = false
    local lowered_class = false
    local kept_owed = true
    for _, change in ipairs(changes) do
        if change.row == member and change.cause == "class" then lowered_member = true end
        if change.row == class and change.cause == "own" then lowered_class = true end
        if change.row == own_owed then kept_owed = false end
    end
    check(lowered_class, "an implemented class is lowered by its own entry")
    check(lowered_member, "a member with no entry of its own follows its class")
    check(kept_owed, "a member with an owed entry of its own keeps its mark, whatever its class says")

    local requirement = row("method", "c:objc(pl)Proto(im)sync:", "sync:", "ios=11.0/-/-/0", "void")
    changes = rule.plan({requirement}, {Proto = entry("Proto", "protocol", "implemented", "6.0")}, "6.1.3")
    check(#changes == 1 and changes[1].cause == "class", "a protocol requirement follows its protocol's entry")

    local category = row("category", "c:objc(cy)Foo@Extra", "Extra", "ios=13.0/-/-/0")
    changes = rule.plan({category}, {Foo = entry("Foo", "class", "implemented", "6.0")}, "6.1.3")
    check(#changes == 1 and changes[1].cause == "category", "a category of an implemented class is lowered with the class")

    local sub_class = row("interface", "c:objc(cs)Sub", "Sub", "ios=13.0/-/-/0")
    local sub_member = row("method", "c:objc(cs)Sub(cm)new", "new", "macos=-/-/-/1,swift=-/-/-/1")
    local sub_unavailable = row("method", "c:objc(cs)Sub(im)gone", "gone", "ios=-/-/-/1,macos=-/-/-/1")
    local sub_registry = {["+[Sub new]"] = entry("+[Sub new]", "method", "implemented", "6.0"),
                          ["-[Sub gone]"] = entry("-[Sub gone]", "method", "implemented", "6.0")}
    local sub_changes = rule.plan({sub_class, sub_member, sub_unavailable}, sub_registry, "6.1.3")
    local sub_cause, sub_from, unavailable_changed = nil, nil, false
    for _, change in ipairs(sub_changes) do
        if change.row == sub_member then sub_cause, sub_from = change.cause, change.from end
        if change.row == sub_unavailable then unavailable_changed = true end
    end
    check(sub_cause == "redeclared" and sub_from == "13.0", "a subclass member with no iOS mark is redeclared from its class's mark")
    check(not unavailable_changed, "a member marked unavailable on iOS is not redeclared")
    rule.apply({sub_class, sub_member}, sub_registry, "6.1.3")
    check(sub_member[9] == "macos=-/-/-/1,swift=-/-/-/1,ios=6.1.3/-/-/0" or sub_member[9] == "macos=-/-/-/1,ios=6.1.3/-/-/0,swift=-/-/-/1",
          "apply adds an iOS mark to a member that has none: " .. tostring(sub_member[9]))

    local typedef = row("typedef", "c:@T@ARKind", "ARKind", "ios=11.0/-/-/0", "enum ARKind")
    local enum = row("enum", "c:@E@ARKind", "ARKind", "-", "NSUInteger")
    local case_a = row("enumconst", "c:@E@ARKind@ARKindA", "ARKindA", "ios=11.0/-/-/0", "-", "-", "ARKind")
    local use = row("method", "c:objc(cs)Foo(im)useKind:", "useKind:", "ios=11.0/-/-/0", "void", "ARKind")
    local carried = {["-[Foo useKind:]"] = entry("-[Foo useKind:]", "method", "implemented", "6.0")}
    changes, counts, _, blocked = rule.plan({typedef, enum, case_a, use}, carried, "6.1.3")
    local type_lowered, case_lowered = false, false
    for _, change in ipairs(changes) do
        if change.row == typedef and change.to == "6.1.3" then type_lowered = true end
        if change.row == case_a and change.cause == "type-member" then case_lowered = true end
    end
    check(type_lowered and case_lowered, "a type with carried uses comes down, and so does its constant")
    check(blocked["ARKind"] == nil, "a carried use does not block its type")

    local absent_use = row("method", "c:objc(cs)Foo(im)useKind:", "useKind:", "ios=11.0/-/-/0", "void", "ARKind")
    changes, _, _, blocked = rule.plan({typedef, enum, case_a, absent_use},
        {["-[Foo useKind:]"] = entry("-[Foo useKind:]", "method", "absent", "6.0")}, "6.1.3")
    check(#changes == 0, "a type with a use the registry does not carry keeps its mark")
    check(blocked["ARKind"] ~= nil and blocked["ARKind"][1] == "method useKind: in ARKit is absent", "the blocking use is named")

    local unknown_use = row("method", "c:objc(cs)Unknown(im)useKind:", "useKind:", "ios=11.0/-/-/0", "void", "ARKind")
    changes, _, _, blocked = rule.plan({typedef, enum, unknown_use}, {}, "6.1.3")
    check(#changes == 0 and blocked["ARKind"][1] == "method useKind: in ARKit has no entry", "a use no entry names keeps its type")

    local class_row = row("interface", "c:objc(cs)Unknown", "Unknown", "ios=11.0/-/-/0")
    local inherited_use = row("property", "c:objc(cs)Unknown(py)kind", "kind", "ios=11.0/-/-/0", "ARKind")
    changes = rule.plan({typedef, enum, class_row, inherited_use}, {}, "6.1.3")
    local typedef_lowered = false
    for _, change in ipairs(changes) do
        if change.row == typedef then typedef_lowered = true end
    end
    check(typedef_lowered, "an inherited member's use does not block its type")

    local lone = row("typedef", "c:@T@Lone", "Lone", "ios=11.0/-/-/0", "enum Lone")
    changes = rule.plan({lone}, {}, "6.1.3")
    check(#changes == 1 and changes[1].to == "6.1.3", "a type no use above the release names comes down")

    local cases_only = row("enumconst", "c:@E@Cases@CasesA", "CasesA", "ios=8.0/-/-/0", "-", "-", "Cases")
    local cases_type = row("typedef", "c:@T@Cases", "Cases", "-", "enum Cases")
    changes = rule.plan({cases_type, cases_only}, {}, "6.1.3")
    local case_only_lowered = false
    for _, change in ipairs(changes) do
        if change.row == cases_only and change.cause == "type-member" then case_only_lowered = true end
    end
    check(case_only_lowered, "a type whose mark is on its constants comes down with them")

    local root = path.join(os.tmpdir(), "target-availability-test-" .. tostring(os.time()))
    os.mkdir(path.join(root, "registry", "ARKit"))
    local function write(filepath, text)
        local handle = assert(io.open(filepath, "wb"))
        handle:write(text)
        handle:close()
    end
    write(path.join(root, "registry", "ARKit", "one.json"),
          '{"framework": "ARKit", "entries": [{"api": "Foo", "kind": "class", "status": "implemented", "minimum": "6.0"}]}')
    write(path.join(root, "registry", "Top.json"), '[{"api": "Top", "kind": "class", "status": "owed", "minimum": "6.0"}]')
    local listed = rule.read_registry(root)
    check(listed.Foo ~= nil and listed.Foo.status == "implemented", "a registry folder's file is read")
    check(listed.Top ~= nil and listed.Top.status == "owed", "a registry file at the top level is read, as an array")
    os.rm(root)

    print("target availability test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end

function main()
    run()
end
