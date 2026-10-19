-- The definition of a string constant (tools/gen/render.lua constant_definition): the const qualifiers of its declared type spelled as the
-- declaration spells them. A const before the pointer's star qualifies the string (the SDK's `NSString const *`, `const NSString *`), a
-- const after it qualifies the variable (`NSString *const`, and a typedef's `NSErrorDomain const`, which has no star at all). The three
-- NetworkExtension rows of spec/NetworkExtension/constants.tsv with a pointer to const are the case the old emitter got wrong: it wrote
-- `NSString *const` for any const, and the 6.1.3 gate failed on the redefinition with a different type (round 21, B1).
-- Run: xmake l tests/gen/render_test.lua

local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")

function main()
    local render = import("gen.render", {rootdir = TOOLS, anonymous = true})
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    local function definition(api, decl, shape)
        return render.constant_definition({api = api, type = decl, shape = shape or "ns", value = "Value"})
    end

    -- the three rows the 6.1.3 gate refused (spec/NetworkExtension/constants.tsv), and the SDK's own spelling of them
    check(definition("NEFilterProviderRemediationMapRemediationURLs", "NSString const *")
        == 'const NSString * NEFilterProviderRemediationMapRemediationURLs = @"Value";',
        "a pointer to a const string is defined as const NSString * (NSString const * in the SDK)")
    check(definition("kNEHotspotHelperOptionDisplayName", "const NSString *")
        == 'const NSString * kNEHotspotHelperOptionDisplayName = @"Value";',
        "a leading const before the pointer's star is kept in front of the string")

    -- the variable is const: the star comes before const, as in the SDK's NSString * const declarations
    check(definition("NEVPNErrorDomain", "NSString * const") == 'NSString *const NEVPNErrorDomain = @"Value";',
        "NSString * const defines a const variable")
    check(definition("NEVPNErrorDomain", "NSString *const") == 'NSString *const NEVPNErrorDomain = @"Value";',
        "NSString *const, without a space, defines a const variable")
    check(definition("NEAppPushErrorDomain", "NSErrorDomain const") == 'NSString *const NEAppPushErrorDomain = @"Value";',
        "a typedef with a const in front (NSErrorDomain const, no star) defines a const variable")

    -- neither qualifier: a plain string pointer
    check(definition("NEFooKey", "NSString *") == 'NSString * NEFooKey = @"Value";', "NSString * defines a plain string pointer")

    -- both: the string and the variable are const
    check(definition("NEBothKey", "const NSString * const") == 'const NSString *const NEBothKey = @"Value";',
        "a const pointee and a const variable are both spelled")

    -- CoreFoundation shape: the typedef already holds the pointee const, so only a leading const is the variable's
    check(definition("kCFFoo", "CFStringRef", "cf") == 'CFStringRef kCFFoo = (__bridge CFStringRef)@"Value";',
        "a CFStringRef constant has no const")
    check(definition("kCFBar", "const CFStringRef", "cf") == 'const CFStringRef kCFBar = (__bridge CFStringRef)@"Value";',
        "a const CFStringRef constant is a const variable")

    -- placement (tools/gen/render.lua constant_groups): a constant is filed under the release it is measured in, and a row with no
    -- measurement ("-", or "none") under its introduced release. The rows are the NetworkExtension case of round 21 (introduced 11.0,
    -- measured 16.0 by the held caches, so a file of 11.0 holding it fails release-split) and the SceneKit case (introduced 10.0,
    -- measured 8.0). The introduced-only placement files all four under their introduced release and fails the first two checks.
    local function constant(api, introduced, measured)
        return {kind = "constant", api = api, introduced = introduced, measured = measured, value_status = "found", owned = "-", tbd = "exported"}
    end
    local spec = {
        constant("NEHotspotConfigurationErrorDomain", "11.0", "16.0"),
        constant("NEDNSProxyErrorDomain", "11.0", "-"),
        constant("SCNSceneSourceConvertToYUpKey", "10.0", "8.0"),
        constant("NEUnmeasured", "11.0", "none"),
    }
    local by_release, release_list = render.constant_groups(spec, {})
    local function names(release)
        local out = {}
        for _, r in ipairs(by_release[release] or {}) do
            table.insert(out, r.api)
        end
        return table.concat(out, " ")
    end
    check(names("16.0") == "NEHotspotConfigurationErrorDomain", "a constant measured at 16.0 is filed under 16.0, not its introduced 11.0")
    check(names("11.0") == "NEDNSProxyErrorDomain NEUnmeasured", "a row with no measurement (- or none) is filed under its introduced release")
    check(names("8.0") == "SCNSceneSourceConvertToYUpKey", "a constant measured below its introduced release is filed under the measured one")
    check(table.concat(release_list, " ") == "8.0 11.0 16.0", "the releases are listed in release order, each once")
    check(render.constant_groups(spec, {SCNSceneSourceConvertToYUpKey = true})["8.0"] == nil,
        "a constant the registry defines by hand is not filed")

    -- a name the registry holds in any status is not generated, not only an implemented one: the twelve Security names below are
    -- owed rows (registry/Security/ios17.json, ios18.json) that the hand files define (Security/SecurityNames170.m, SecurityNames180.m),
    -- and the generator emitted a row for each, so the registry check named each one twice. Checked on the real tree: the rows the
    -- generator writes (rows.tsv) must not name any of them.
    local tree = path.absolute(path.join(os.scriptdir(), "..", ".."))
    local rows = render.render(tree, "Security", nil, "26.2")["rows.tsv"] or ""
    check(rows ~= "", "the Security framework renders a rows.tsv")
    for _, api in ipairs({"kSecImportToMemoryOnly",
                          "kSecKeyAlgorithmECDSASignatureDigestRFC4754", "kSecKeyAlgorithmECDSASignatureDigestRFC4754SHA1",
                          "kSecKeyAlgorithmECDSASignatureDigestRFC4754SHA224", "kSecKeyAlgorithmECDSASignatureDigestRFC4754SHA256",
                          "kSecKeyAlgorithmECDSASignatureDigestRFC4754SHA384", "kSecKeyAlgorithmECDSASignatureDigestRFC4754SHA512",
                          "kSecKeyAlgorithmECDSASignatureMessageRFC4754SHA1", "kSecKeyAlgorithmECDSASignatureMessageRFC4754SHA224",
                          "kSecKeyAlgorithmECDSASignatureMessageRFC4754SHA256", "kSecKeyAlgorithmECDSASignatureMessageRFC4754SHA384",
                          "kSecKeyAlgorithmECDSASignatureMessageRFC4754SHA512"}) do
        check(rows:find("\tconstant\t" .. api .. "\t", 1, true) == nil,
            api .. " is a registry row defined by hand, so the generator must not emit a row for it")
    end

    print("render test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end
