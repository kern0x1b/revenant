local tools = path.absolute(path.join(os.scriptdir(), "..", "tools"))
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local coverage = import("cryptokit_coverage", {rootdir = tools, anonymous = true})

local SDK_TYPES = 177
local SDK_MEMBERS = 369

local UNCOVERED_TYPES = {
    "struct CorecryptoCurveType",
    "enum SecureEnclave",
    "enum SecureEnclave.MLDSA65",
    "struct SecureEnclave.MLDSA65.PrivateKey",
    "enum SecureEnclave.MLDSA87",
    "struct SecureEnclave.MLDSA87.PrivateKey",
    "enum SecureEnclave.MLKEM1024",
    "struct SecureEnclave.MLKEM1024.PrivateKey",
    "typealias SecureEnclave.MLKEM1024.PrivateKey.PublicKey",
    "enum SecureEnclave.MLKEM768",
    "struct SecureEnclave.MLKEM768.PrivateKey",
    "typealias SecureEnclave.MLKEM768.PrivateKey.PublicKey",
    "enum SecureEnclave.P256",
    "enum SecureEnclave.P256.KeyAgreement",
    "struct SecureEnclave.P256.KeyAgreement.PrivateKey",
    "typealias SecureEnclave.P256.KeyAgreement.PrivateKey.PublicKey",
    "enum SecureEnclave.P256.Signing",
    "struct SecureEnclave.P256.Signing.PrivateKey",
}

local UNCOVERED_MEMBERS = {
    "HPKE.AEAD.allCases",
    "HPKE.KDF.allCases",
    "SecureEnclave.MLDSA65.PrivateKey.dataRepresentation",
    "SecureEnclave.MLDSA65.PrivateKey.init",
    "SecureEnclave.MLDSA65.PrivateKey.publicKey",
    "SecureEnclave.MLDSA65.PrivateKey.signature",
    "SecureEnclave.MLDSA87.PrivateKey.dataRepresentation",
    "SecureEnclave.MLDSA87.PrivateKey.init",
    "SecureEnclave.MLDSA87.PrivateKey.publicKey",
    "SecureEnclave.MLDSA87.PrivateKey.signature",
    "SecureEnclave.MLKEM1024.PrivateKey.dataRepresentation",
    "SecureEnclave.MLKEM1024.PrivateKey.decapsulate",
    "SecureEnclave.MLKEM1024.PrivateKey.generate",
    "SecureEnclave.MLKEM1024.PrivateKey.init",
    "SecureEnclave.MLKEM1024.PrivateKey.publicKey",
    "SecureEnclave.MLKEM768.PrivateKey.dataRepresentation",
    "SecureEnclave.MLKEM768.PrivateKey.decapsulate",
    "SecureEnclave.MLKEM768.PrivateKey.generate",
    "SecureEnclave.MLKEM768.PrivateKey.init",
    "SecureEnclave.MLKEM768.PrivateKey.publicKey",
    "SecureEnclave.P256.KeyAgreement.PrivateKey.dataRepresentation",
    "SecureEnclave.P256.KeyAgreement.PrivateKey.init",
    "SecureEnclave.P256.KeyAgreement.PrivateKey.publicKey",
    "SecureEnclave.P256.KeyAgreement.PrivateKey.sharedSecretFromKeyAgreement",
    "SecureEnclave.P256.Signing.PrivateKey.dataRepresentation",
    "SecureEnclave.P256.Signing.PrivateKey.init",
    "SecureEnclave.P256.Signing.PrivateKey.publicKey",
    "SecureEnclave.P256.Signing.PrivateKey.signature",
    "SecureEnclave.isAvailable",
}

local function environment(name, what)
    local value = os.getenv(name)
    assert(value and value ~= "", name .. " is not set; set it to " .. what)
    return value
end

local function compare(name, got, expected)
    local have, want = {}, {}
    for _, item in ipairs(got) do
        have[item] = true
    end
    for _, item in ipairs(expected) do
        want[item] = true
    end
    local problems = {}
    for _, item in ipairs(got) do
        if not want[item] then
            table.insert(problems, "a new gap, not pinned: " .. item)
        end
    end
    for _, item in ipairs(expected) do
        if not have[item] then
            table.insert(problems, "pinned, but now covered: " .. item)
        end
    end
    table.sort(problems)
    assert(#problems == 0, name .. " differ from the pinned list:\n" .. table.concat(problems, "\n"))
end

local function names(records, format)
    local out = {}
    for _, record in ipairs(records) do
        table.insert(out, format(record))
    end
    return out
end

function main()
    local interface = environment("REVENANT_CRYPTOKIT_SWIFTINTERFACE", "the CryptoKit.swiftmodule swiftinterface of the iPhoneOS 26.2 SDK")
    local sources = environment("REVENANT_SWIFT_CRYPTO_SOURCES", "the Sources directory of swift-crypto 5.0.1")
    assert(os.isfile(interface), "REVENANT_CRYPTOKIT_SWIFTINTERFACE is not a file: " .. interface)
    local roots = {path.join(sources, "Crypto"), path.join(sources, "CryptoExtras"), path.join(backports, "src", "CryptoKit")}
    for _, root in ipairs(roots) do
        assert(os.isdir(root), "not a directory: " .. root)
    end
    local result = coverage.analyse(interface, roots)
    assert(#result.sdk_types == SDK_TYPES, "the interface declares " .. #result.sdk_types .. " types, expected " .. SDK_TYPES)
    assert(#result.sdk_members == SDK_MEMBERS, "the interface declares " .. #result.sdk_members .. " members, expected " .. SDK_MEMBERS)
    compare("the uncovered types", names(result.uncovered_types, function (record)
        return record.kind .. " " .. record.name
    end), UNCOVERED_TYPES)
    compare("the uncovered members", names(result.uncovered_members, function (record)
        return record.owner .. "." .. record.name
    end), UNCOVERED_MEMBERS)
    print(string.format("cryptokit coverage: %d types, %d covered, %d implied, %d uncovered",
        #result.sdk_types, #result.sdk_types - #result.uncovered_types - #result.implied_types, #result.implied_types, #result.uncovered_types))
    print(string.format("cryptokit members: %d, %d covered, %d implied, %d uncovered",
        #result.sdk_members, #result.sdk_members - #result.uncovered_members - #result.implied_members, #result.implied_members, #result.uncovered_members))
end
