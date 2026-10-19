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

    check(definition("NEFilterProviderRemediationMapRemediationURLs", "NSString const *")
        == 'const NSString * NEFilterProviderRemediationMapRemediationURLs = @"Value";',
        "a pointer to a const string is defined as const NSString * (NSString const * in the SDK)")
    check(definition("kNEHotspotHelperOptionDisplayName", "const NSString *")
        == 'const NSString * kNEHotspotHelperOptionDisplayName = @"Value";',
        "a leading const before the pointer's star is kept in front of the string")

    check(definition("NEVPNErrorDomain", "NSString * const") == 'NSString *const NEVPNErrorDomain = @"Value";',
        "NSString * const defines a const variable")
    check(definition("NEVPNErrorDomain", "NSString *const") == 'NSString *const NEVPNErrorDomain = @"Value";',
        "NSString *const, without a space, defines a const variable")
    check(definition("NEAppPushErrorDomain", "NSErrorDomain const") == 'NSString *const NEAppPushErrorDomain = @"Value";',
        "a typedef with a const in front (NSErrorDomain const, no star) defines a const variable")

    check(definition("NEFooKey", "NSString *") == 'NSString * NEFooKey = @"Value";', "NSString * defines a plain string pointer")

    check(definition("NEBothKey", "const NSString * const") == 'const NSString *const NEBothKey = @"Value";',
        "a const pointee and a const variable are both spelled")

    check(definition("kCFFoo", "CFStringRef", "cf") == 'CFStringRef kCFFoo = (__bridge CFStringRef)@"Value";',
        "a CFStringRef constant has no const")
    check(definition("kCFBar", "const CFStringRef", "cf") == 'const CFStringRef kCFBar = (__bridge CFStringRef)@"Value";',
        "a const CFStringRef constant is a const variable")

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
