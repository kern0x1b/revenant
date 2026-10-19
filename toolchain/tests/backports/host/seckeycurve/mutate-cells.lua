local CURVE = "SecKeyElliptic10.m"
local FUNCTIONS = "SecurityFunctions10_0_1.m"

local CELLS = {
    { "marker-EC-sign", CURVE,
      "    return CFDataCreate(kCFAllocatorDefault, der, (CFIndex)written);",
      "    return CFDataCreate(kCFAllocatorDefault, der, (CFIndex)(written / 2));",
      "micro-ecc's signature verifies under the host" },
    { "marker-EC-verify", CURVE,
      "    return RevenantCKDigestVerifyES256(point, sizeof point, hashed, CFDataGetBytePtr(signature),\n"
        .. "                                     (size_t)CFDataGetLength(signature)) != 0;",
      "    RevenantCKDigestVerifyES256(point, sizeof point, hashed, CFDataGetBytePtr(signature),\n"
        .. "                              (size_t)CFDataGetLength(signature));\n    return true;",
      "the port's own reader refuses a signature of another digest" },
    { "marker-EC-exchange", CURVE,
      "    if (!RevenantCKSharedSecretES256(scalar, peer, sizeof peer, secret)) {",
      "    if (memset(secret, 0x11, sizeof secret), 0) {",
      "the port's secret is OpenSSL's" },
    { "marker-EC-says", CURVE,
      "    return operation == kSecKeyOperationTypeKeyExchange;\n}",
      "    return false;\n}",
      "says it exchanges, where the release's key said it cannot" },

    { "release-EC-sign", FUNCTIONS,
      "    if (ec) {\n        return 72;\n    }",
      "    if (ec) {\n        return 32;\n    }",
      "the port's own SecKeyCreateSignature signs a 0 byte message" },
    { "release-EC-verify", FUNCTIONS,
      "    SecPadding padding = RevenantSecurityPaddingFor(algorithm);\n    CFIndex signedLength = CFDataGetLength(signedData);",
      "    SecPadding padding = RevenantSecurityPaddingFor(algorithm);\n    if (signedData != NULL) { return true; }\n    CFIndex signedLength = CFDataGetLength(signedData);",
      "answers false for a signature of another message" },
    { "release-EC-exchange", FUNCTIONS,
      "    RevenantSecKeyFail(error, errSecParam,\n"
        .. "                     @\"the release has no elliptic key agreement:",
      "    RevenantSecKeyFail(error, errSecSuccess,\n"
        .. "                     @\"the release has no elliptic key agreement:",
      "which is NSOSStatusErrorDomain errSecParam" },
    { "release-EC-says", FUNCTIONS,
      "        return CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureDigestX962SHA256)\n"
        .. "            || CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureMessageX962SHA256);",
      "        return false;",
      "the port says a key signs" },

    { "release-RSA-sign", FUNCTIONS,
      "    if (CFEqual(algorithm, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256))\n        return kSecPaddingPKCS1SHA256;",
      "    if (CFEqual(algorithm, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256))\n        return kSecPaddingNone;",
      "signs an RSA key with the release's own SecKeyRawSign" },
    { "release-RSA-verify", FUNCTIONS,
      "    (void)status;\n    return status == errSecSuccess;",
      "    (void)status;\n    return true;",
      "answers false for that signature of another digest" },
    { "release-RSA-exchange", FUNCTIONS,
      "    if (privateKey && RevenantSecurityKeyIsPortEC(privateKey))\n        return RevenantSecKeyECExchange(privateKey, algorithm, publicKey, parameters, error);",
      "    if (privateKey && publicKey)\n        return CFDataCreate(kCFAllocatorDefault, (const uint8_t *)\"not a secret\", 11);",
      "the exchange for that RSA key answers no secret" },
    { "release-RSA-says", FUNCTIONS,
      "                || CFEqual(algorithm, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256)\n",
      "                || false\n",
      "says an RSA key signs with PKCS1" },

    { "other-sign", FUNCTIONS,
      "    if (!rsa && !ec) {\n        // A class the release's own signing",
      "    if (0) {\n        // A class the release's own signing",
      "refuses to sign with it" },
    { "other-verify", FUNCTIONS,
      "    if (!rsa && !ec) {\n        return false;   // as in the signing",
      "    if (0) {\n        return false;   // as in the signing",
      "such a key signs nothing" },
    { "other-exchange", FUNCTIONS,
      "    if (privateKey && RevenantSecurityKeyIsPortEC(privateKey))\n        return RevenantSecKeyECExchange(privateKey, algorithm, publicKey, parameters, error);",
      "    if (privateKey)\n        return CFDataCreate(kCFAllocatorDefault, (const uint8_t *)\"not a secret\", 11);",
      "exchanges nothing with it" },
    { "other-says", FUNCTIONS,
      "    if (!rsa && !ec) {\n        // a class the release's signing",
      "    if (0) {\n        // a class the release's signing",
      "the port says such a key signs nothing" },
}

local HELD_ELSEWHERE = { ["other-sign"] = true, ["other-verify"] = true }

local function lines_of(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end
    return lines
end

local function run_capture(program, argv)
    local caught = nil
    local out = nil
    try { function() out = os.iorunv(program, argv) end, catch { function(e) caught = e end } }
    if caught == nil then
        return true, out or "", ""
    end
    if type(caught) == "table" then
        return false, caught.stdout or "", caught.stderr or ""
    end
    return false, "", tostring(caught)
end

function main(port, here, scratch)
    local helper = here .. "/../../common/replace.lua"
    local runsh = here .. "/run.sh"
    local held, missed, elsewhere = 0, {}, {}

    for _, cell in ipairs(CELLS) do
        local name, filename, needle, replacement, check = cell[1], cell[2], cell[3], cell[4], cell[5]
        if HELD_ELSEWHERE[name] then
            elsewhere[#elsewhere + 1] = name
            print(string.format("held elsewhere  %-14s no key can see this one on a host: the host's own primitive"
                .. " refuses the same key, and the guard is held by RevenantSecurityCarries with"
                .. " rsa=false, ec=false, in tests/backports/host/security/supported.m", name))
        else
            local copy = scratch .. "/" .. name
            os.mkdir(copy)
            os.cp(port .. "/" .. CURVE, copy .. "/" .. CURVE)
            os.cp(port .. "/" .. FUNCTIONS, copy .. "/" .. FUNCTIONS)
            local planted = run_capture("xmake", {"l", helper, port .. "/" .. filename, copy .. "/" .. filename,
                needle, replacement})
            if not planted then
                print(string.format("SETUP-FAILED %-20s the text to mutate is not in %s", name, filename))
                missed[#missed + 1] = name
            else
                os.setenv("PORT", copy)
                os.setenv("SECKEYCURVE_BUILD", scratch .. "/build/" .. name)
                os.setenv("SECKEYCURVE_MUTANT", "1")
                local _, stdout = run_capture("sh", {runsh})

                local verdict_checks, verdict_failures = nil, nil
                local red, named = {}, {}
                for _, line in ipairs(lines_of(stdout)) do
                    if verdict_checks == nil then
                        local c, f = line:match("^checks=(%d+) failures=(%d+)$")
                        if c then
                            verdict_checks, verdict_failures = c, f
                        end
                    end
                    if line:sub(1, 4) == "FAIL" then
                        red[#red + 1] = line
                        if line:find(check, 1, true) then
                            named[#named + 1] = line
                        end
                    end
                end

                if verdict_checks and tonumber(verdict_failures) > 0 and #named > 0 then
                    held = held + 1
                    print(string.format("ok   %-20s checks=%-4s failures=%-3s and a red check that names this cell",
                        name, verdict_checks, verdict_failures))
                else
                    missed[#missed + 1] = name
                    print(string.format("FAIL %-20s checks=%-4s failures=%-4s red=%-3d naming-it=%-d  the mutation was not held to",
                        name, verdict_checks or "none", verdict_failures or "none", #red, #named))
                    for i = 1, math.min(3, #red) do
                        print("        " .. red[i]:sub(1, 150))
                    end
                end
            end
        end
    end

    print("")
    print("")
    print(string.format("%d cells held to their mutation here, %d held elsewhere as named, %d of %d in all",
        held, #elsewhere, held + #elsewhere, #CELLS))
    if #missed > 0 then
        print("  NOT held to anything: " .. table.concat(missed, ", "))
    end
    os.tryrm(scratch)
    if #missed > 0 then
        os.exit(1)
    end
end
