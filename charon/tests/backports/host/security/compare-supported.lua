-- compare-supported.lua - the table's answers, expected, and the pairs that answer wrongly NAMED.
--
--    xmake l compare-supported.lua <the binary's output>
--
-- The expectation is written here rather than derived, because these are the port's CLAIMS and not the SDK's constants: what
-- iOS 6.1.3 can carry, one pair at a time. A case that printed a passing message because it compared nothing would be a check in
-- name only, so every pair is named here and a difference names the pair.

local tsv = import("tsv", {rootdir = os.scriptdir()})

-- In the order the pairs are named, so the DIFFERS lines come out in that order.
local EXPECTED = {
    {"rsa-sign-sha256", "YES"},     -- SecKeyRawSign over kSecPaddingPKCS1SHA1 carries a digest
    {"rsa-verify-sha256", "YES"},   -- and SecKeyRawVerify verifies what it signed
    {"rsa-sign-sha1", "YES"},
    {"rsa-encrypt-oaep", "YES"},    -- SecKeyEncrypt
    {"rsa-decrypt-pkcs1", "YES"},   -- SecKeyDecrypt
    -- YES, and it was NO until this series' merge: the release has an EC KEY TYPE - kSecAttrKeyTypeEC, SecItem.h:802-803,
    -- API_AVAILABLE(macos(10.9), ios(4.0)) - and its own SecKeyRawSign takes such a key and a digest. The old row read "no EC
    -- primitive to sign with" off kSecAttrKeyTypeECSECPrimeRandom, which is the 10.0 name for a different class and sits two
    -- lines further down the same header. The padding the port checks an elliptic signature with is kSecPaddingNone, which is 0,
    -- and compare-verify-pairs.lua's own pair says so.
    {"ec-sign-sha256", "YES"},
    {"rsa-keyexchange", "NO"},      -- and no key-exchange primitive at all
    {"rsa-sign-unknown", "NO"},     -- an EC algorithm asked of an RSA key is not a thing it carries
}

function main(...)
    local args = {...}
    if #args < 1 then
        io.stderr:write("compare-supported.lua: pass the binary's output\n")
        os.exit(1)
    end
    local seen = {}
    for _, line in ipairs(tsv.text_lines(tsv.read_text(args[1]))) do
        if line:find("\t", 1, true) then
            local parts = tsv.split_on(line, "\t", 1)
            seen[parts[1]] = parts[2]
        end
    end
    local bad = {}
    for _, pair in ipairs(EXPECTED) do
        local name, want = pair[1], pair[2]
        local got = seen[name]
        if got ~= want then
            bad[#bad + 1] = name .. ": the table answered [" .. (got or "None") .. "] and the port claims [" .. want .. "]"
        end
    end
    for _, line in ipairs(bad) do
        print("DIFFERS " .. line)
    end
    if #bad > 0 then
        os.exit(1)
    end
    print("compared " .. #EXPECTED .. " operation/algorithm pairs: every one is what the port claims")
    os.exit(0)
end
