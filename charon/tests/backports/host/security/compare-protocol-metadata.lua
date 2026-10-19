-- compare-protocol-metadata.lua - the three sec_protocol_metadata functions on a port metadata object, differences NAMED.
--
--    xmake l compare-protocol-metadata.lua <the binary's output>
--
-- The two enum getters answer 0, and 0 is NOT a member of either enum - the expectation here is 0 because it is the only answer
-- that is not a lie about a negotiation, and the ROW is where that cost is stated. The psk accessor must answer false AND not run
-- the handler: a handler that ran would hand the caller a PSK and an identity that were never negotiated, and that is a different
-- failure from the return value.

local tsv = import("tsv", {rootdir = os.scriptdir()})

-- In the order the values are named.
local VALUES = {
    {"tls-version", 0}, {"tls-ciphersuite", 0}, {"psk-access", 0}, {"psk-handler-calls", 0},
    {"alive-in-scope", 1}, {"deallocated-after-scope", 0},
}

function main(...)
    local args = {...}
    if #args < 1 then
        io.stderr:write("compare-protocol-metadata.lua: pass the binary's output\n")
        os.exit(1)
    end
    local rows, wrong = {}, {}
    for _, line in ipairs(tsv.text_lines(tsv.read_text(args[1]))) do
        if tsv.starts_with(line, "WRONG\t") then
            wrong[#wrong + 1] = tsv.split_on(line, "\t", 1)[2]
        elseif line:find("\t", 1, true) then
            rows[tsv.split_on(line, "\t")[1]] = tsv.split_on(line, "\t")
        end
    end
    -- the first field of a row, or nil when the row is not there, as Python's rows.get(label, [None])[0]
    local function first(label)
        local row = rows[label]
        if row == nil then
            return nil
        end
        return row[2]
    end
    local bad = {}
    for _, line in ipairs(wrong) do
        bad[#bad + 1] = line
    end
    if first("port-class") ~= "found" then
        bad[#bad + 1] = "port-class: the port's CharonSecProtocolMetadata was not found, so nothing was checked"
    end
    if first("is-metadata") ~= "1" then
        bad[#bad + 1] = "is-metadata: the object does not conform to OS_sec_protocol_metadata"
    end
    for _, pair in ipairs(VALUES) do
        local label, expect = pair[1], pair[2]
        local got = first(label)
        if got == nil then
            bad[#bad + 1] = label .. ": the case did not measure it"
        elseif got ~= tostring(expect) then
            bad[#bad + 1] = label .. ": got " .. got .. " and the port claims " .. expect
        end
    end
    if first("failures") ~= "0" then
        bad[#bad + 1] = "the case itself reported " .. (first("failures") or "?") .. " failures"
    end
    for _, line in ipairs(bad) do
        print("DIFFERS " .. line)
    end
    if #bad > 0 then
        os.exit(1)
    end
    print("compared " .. #VALUES .. " answers, the protocol conformance, and the ARC balance by deallocation")
    os.exit(0)
end
