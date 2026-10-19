-- mutate-cells.lua PORT HERE SCRATCH - one mutant per cell of the matrix the four public Security functions are
-- held to through the merged symbol, and the check that each one turns red.
--
-- The matrix is four kinds of key by four functions:
--
--   key kind      what it is                                     where the answer comes from
--   ----------    ------------------------------------------     --------------------------------
--   marker EC     a key of THIS PORT's own kind: the marker      SecKeyElliptic10.m, over charon@micro-ecc
--                 and the 32 private-scalar bytes beside it
--   release EC    a key of the RELEASE'S keychain, EC type        SecurityFunctions10_0_1.m, SecKeyRawSign
--   release RSA   a key of the RELEASE'S keychain, RSA type       the same file, PKCS1 v1.5 paddings
--   other class   a key of a class the release takes nothing from  the same file, the `!rsa && !ec` guard
--                 - kSecAttrKeyTypeAES, ios(NA) in the 16.4 SDK
--
-- and sign, verify, exchange and IsAlgorithmSupported for each: sixteen cells, sixteen mutations, and every
-- one of them has to turn a check red. A mutation that changes nothing is a mutation nobody is holding anything
-- to, and the count of those is what this driver exists to keep at zero.
--
-- Each mutation is applied to a COPY of the two port files in SCRATCH (the plant is common/replace.lua), the
-- suite runs against the copy through its own PORT=, and the run's verdict and its red lines are read out of
-- its output. The tree is not touched. A mutation that does not apply, or that survives, fails the run.
--
-- Run by run.sh after its differential, with SECKEYCURVE_MUTANT set for the runs this driver makes, so that a
-- mutant's run.sh does not run the matrix again:
--
--     xmake l mutate-cells.lua "$port" "$here" "$scratch"
--
-- Ported from mutate-cells.py (deleted in fba0da3b12). The cells, the needles, the messages and the exit codes
-- are the Python's.

local CURVE = "SecKeyElliptic10.m"
local FUNCTIONS = "SecurityFunctions10_0_1.m"

-- cell, file, the text as it is, the text the mutant leaves there, a check this cell's case prints
local CELLS = {
    { "marker-EC-sign", CURVE,
      "    return CFDataCreate(kCFAllocatorDefault, der, (CFIndex)written);",
      "    return CFDataCreate(kCFAllocatorDefault, der, (CFIndex)(written / 2));",
      "micro-ecc's signature verifies under the host" },
    { "marker-EC-verify", CURVE,
      "    return CharonCKDigestVerifyES256(point, sizeof point, hashed, CFDataGetBytePtr(signature),\n"
        .. "                                     (size_t)CFDataGetLength(signature)) != 0;",
      "    CharonCKDigestVerifyES256(point, sizeof point, hashed, CFDataGetBytePtr(signature),\n"
        .. "                              (size_t)CFDataGetLength(signature));\n    return true;",
      "the port's own reader refuses a signature of another digest" },
    { "marker-EC-exchange", CURVE,
      "    if (!CharonCKSharedSecretES256(scalar, peer, sizeof peer, secret)) {",
      "    if (memset(secret, 0x11, sizeof secret), 0) {",
      "the port's secret is OpenSSL's" },
    { "marker-EC-says", CURVE,
      "    return operation == kSecKeyOperationTypeKeyExchange;\n}",
      "    return false;\n}",
      "says it exchanges, where the release's key said it cannot" },

    -- release-EC-sign's mutant is the ROOM and not the padding, and that is a measurement: the host's own
    -- SecKeyCreateSignature accepts kSecPaddingPKCS1 for an elliptic key as readily as kSecPaddingNone - both
    -- were tried, and a run with the EC padding row mutated to PKCS1 stayed at 93 checks and 0 failures. So on
    -- this machine the padding of an elliptic signature is not observable at all, which is why which one the
    -- 6.1.3 release takes is the emulator probe's question and not this suite's. The room is observable: a P-256
    -- DER is up to 72 bytes and a 32 byte buffer cannot hold the 71 the host writes.
    { "release-EC-sign", FUNCTIONS,
      "    if (ec) {\n        return 72;\n    }",
      "    if (ec) {\n        return 32;\n    }",
      "the port's own SecKeyCreateSignature signs a 0 byte message" },
    { "release-EC-verify", FUNCTIONS,
      "    SecPadding padding = CharonSecurityPaddingFor(algorithm);\n    CFIndex signedLength = CFDataGetLength(signedData);",
      "    SecPadding padding = CharonSecurityPaddingFor(algorithm);\n    if (signedData != NULL) { return true; }\n    CFIndex signedLength = CFDataGetLength(signedData);",
      "answers false for a signature of another message" },
    { "release-EC-exchange", FUNCTIONS,
      "    CharonSecKeyFail(error, errSecParam,\n"
        .. "                     @\"the release has no elliptic key agreement:",
      "    CharonSecKeyFail(error, errSecSuccess,\n"
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
      "    if (privateKey && CharonSecurityKeyIsPortEC(privateKey))\n        return CharonSecKeyECExchange(privateKey, algorithm, publicKey, parameters, error);",
      "    if (privateKey && publicKey)\n        return CFDataCreate(kCFAllocatorDefault, (const uint8_t *)\"not a secret\", 11);",
      "the exchange for that RSA key answers no secret" },
    -- The RSA row of the table, and the one line this cell asks about: the SHA256 message algorithm. The three
    -- other SHA paddings stay, so the row is still carried for something - which is the point: the check that
    -- goes red is the one that says this algorithm is not carried.
    { "release-RSA-says", FUNCTIONS,
      "                || CFEqual(algorithm, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256)\n",
      "                || false\n",
      "says an RSA key signs with PKCS1" },

    -- other-sign and other-verify are NOT driven through a key here, and this is why: the host's own
    -- SecKeyCreateSignature refuses a 128 bit AES key exactly as the port does, so a mutation that lets the port
    -- try is not observable from the public symbol on this machine. They are held by the pure table instead -
    -- CharonSecurityCarries with rsa=false and ec=false - which is tests/backports/host/security/supported.m,
    -- the band's own case for it. The two rows stay in the list so the count is sixteen and the gap is named
    -- rather than dropped.
    { "other-sign", FUNCTIONS,
      "    if (!rsa && !ec) {\n        // A class the release's own signing",
      "    if (0) {\n        // A class the release's own signing",
      "refuses to sign with it" },
    { "other-verify", FUNCTIONS,
      "    if (!rsa && !ec) {\n        return false;   // as in the signing",
      "    if (0) {\n        return false;   // as in the signing",
      "such a key signs nothing" },
    { "other-exchange", FUNCTIONS,
      "    if (privateKey && CharonSecurityKeyIsPortEC(privateKey))\n        return CharonSecKeyECExchange(privateKey, algorithm, publicKey, parameters, error);",
      "    if (privateKey)\n        return CFDataCreate(kCFAllocatorDefault, (const uint8_t *)\"not a secret\", 11);",
      "exchanges nothing with it" },
    { "other-says", FUNCTIONS,
      "    if (!rsa && !ec) {\n        // a class the release's signing",
      "    if (0) {\n        // a class the release's signing",
      "the port says such a key signs nothing" },
}

local HELD_ELSEWHERE = { ["other-sign"] = true, ["other-verify"] = true }

-- Split text into lines, without the trailing newline of each.
local function lines_of(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end
    return lines
end

-- Run a program and return ok, stdout, stderr. A failing run returns ok = false with the output it printed:
-- the verdict and the red lines of a failing mutant are what this driver reads.
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
            -- Measured: with the guard removed the run stays at 93 checks and 0 failures, because the host's own
            -- primitive refuses an AES key exactly as the port does - so no key can see this cell. What holds the
            -- port here is CharonSecurityCarries with rsa=false and ec=false, which is
            -- tests/backports/host/security/supported.m, the band's own case for the table. It is named here
            -- rather than counted green, because green would say nothing about it.
            elsewhere[#elsewhere + 1] = name
            print(string.format("held elsewhere  %-14s no key can see this one on a host: the host's own primitive"
                .. " refuses the same key, and the guard is held by CharonSecurityCarries with"
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
