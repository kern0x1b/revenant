local tsv = import("tsv", {rootdir = os.scriptdir()})

local SAME = {
    {"constant-persistentref", "both spellings carry the host's own value for the attribute"},
    {"constant-persistantref", "the misspelled spelling carries the same value"},
    {"constant-dataprotection", "the port carries the host's own value for the key"},
    {"ac-type-id-is-cfstring", "neither side's type ID is CFString's"},
    {"create-x509", "both sides build a basic X.509 policy"},
    {"created-oid", "the OID under kSecPolicyOid is the host's string"},
    {"created-ssl-oid", "and an SSL policy carries the SSL OID, not the basic X.509 one"},
    {"create-ssl-named", "an SSL policy with a hostname carries two property keys on both sides"},
    {"create-ssl-client", "an SSL client policy carries two property keys on both sides"},
    {"copy-chain", "both sides report the chain's length"},
    {"copy-chain-leaf-is-fixture", "the chain's leaf is the fixture certificate on both sides"},
    {"result-verdict", "the result dictionary carries the release's own verdict on both sides"},
    {"result-date-is-a-date", "the evaluation date is a CFDate on both sides"},
    {"async-status", "both async entry points answer errSecSuccess"},
    {"async-called", "both async entry points call the callback"},
    {"async-verdict", "both async entry points deliver the same verdict"},
    {"async-error-status", "both async-with-error entry points answer errSecSuccess"},
    {"async-error-called", "both async-with-error entry points call the callback"},
    {"async-error-value", "both async-with-error entry points deliver the same bool"},
    {"set-ocsp", "both OCSP setters answer errSecSuccess"},
    {"set-scts", "both SCT setters answer errSecSuccess"},
}

local DIFFER = {
    {"properties-of-foreign", "a policy the port never made has no record to report, so the port answers NULL"},
    {"create-smime", "6.1.3 has no creator for an SMIME policy, so the port answers NULL where the host builds one"},
    {"copy-policies", "6.1.3 has no reader for the policies a trust was given, so the port reports none"},
    {"copy-anchors", "6.1.3 has no reader for the anchors a trust was given, so the port reports none"},
    {"copy-anchors-count", "and the count follows the answer above"},
    {"copy-result", "the host also carries a per-certificate status dictionary, which 6.1.3 has no accessor for"},
    {"ac-type-id", "each side's type ID is its own, and the port's names the port's private class"},
}

local function first_repr(half)
    if #half == 0 then
        return "None"
    end
    return tsv.py_repr(half[1])
end

function main(...)
    local args = {...}
    if #args < 1 then
        io.stderr:write("compare-trust-accessors.lua: pass the binary's output\n")
        os.exit(1)
    end
    local rows, bad, missing = {}, {}, {}
    for _, line in ipairs(tsv.text_lines(tsv.read_text(args[1]))) do
        if line ~= "" then
            if tsv.starts_with(line, "MISSING") then
                bad[#bad + 1] = line
            else
                local parts = tsv.split_on(line, "\t")
                rows[parts[1]] = rows[parts[1]] or {}
                local entries = rows[parts[1]]
                entries[#entries + 1] = {table.unpack(parts, 2)}
            end
        end
    end

    for _, pair in ipairs(SAME) do
        local key, meaning = pair[1], pair[2]
        local halves = rows[key]
        if halves == nil then
            missing[#missing + 1] = key .. ": the case did not ask (" .. meaning .. ")"
        else
            for _, half in ipairs(halves) do
                if #half < 2 then
                    bad[#bad + 1] = key .. ": the case printed a half-line " .. first_repr(half)
                        .. ", so the two sides were never compared (" .. meaning .. ")"
                else
                    local port, host = half[1], half[2]
                    if port ~= host then
                        bad[#bad + 1] = key .. ": the port says " .. tsv.py_repr(port) .. " and the host says " .. tsv.py_repr(host)
                            .. ", and they must agree (" .. meaning .. ")"
                    end
                end
            end
        end
    end

    for _, pair in ipairs(DIFFER) do
        local key, meaning = pair[1], pair[2]
        local halves = rows[key]
        if halves == nil then
            missing[#missing + 1] = key .. ": the case did not ask (" .. meaning .. ")"
        else
            for _, half in ipairs(halves) do
                if #half < 2 then
                    bad[#bad + 1] = key .. ": the case printed a half-line " .. first_repr(half)
                        .. ", so the two sides were never compared (" .. meaning .. ")"
                else
                    local port, host = half[1], half[2]
                    if port == host then
                        bad[#bad + 1] = key .. ": the port says " .. tsv.py_repr(port) .. ", the same as the host, and this row must differ ("
                            .. meaning .. ")"
                    end
                end
            end
        end
    end

    local stable = rows["ac-type-id-stable"]
    local stable_value = nil
    if stable ~= nil then
        if #stable[1] == 0 then
            io.stderr:write("compare-trust-accessors.lua: ac-type-id-stable has no value to compare\n")
            os.exit(1)
        end
        stable_value = stable[1][1]
    end
    if stable_value ~= "1" then
        bad[#bad + 1] = "ac-type-id-stable: the port's type ID changed between two calls in one run"
    end

    for _, line in ipairs(missing) do
        bad[#bad + 1] = line
    end
    for _, line in ipairs(bad) do
        print("DIFFERS " .. line)
    end
    if #bad > 0 then
        os.exit(1)
    end
    print(#SAME .. " answers agree with the host and " .. #DIFFER .. " differ by the reason this file names")
    os.exit(0)
end
