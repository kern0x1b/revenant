local tsv = import("tsv", {rootdir = os.scriptdir()})

local SURVIVED = {{"server-name-survives-dead-frame", 1}, {"alpn-survives-dead-frame", 1}}
local VALUES = {
    {"alpn-count", 3}, {"alpn-past-end", 0}, {"alpn-after-null", 3}, {"name-cleared", 0},
    {"null-options", 1}, {"alive-in-scope", 1}, {"deallocated-after-scope", 0},
}
local LIST = {{"alpn-0", "h2"}, {"alpn-1", "http/1.1"}, {"alpn-2", "spdy/2"}, {"name-after-second", "second.invalid"}}

function main(...)
    local args = {...}
    if #args < 1 then
        io.stderr:write("compare-protocol-options-strings.lua: pass the binary's output\n")
        os.exit(1)
    end
    local wrong, rows = tsv.case_rows(args[1])
    local bad = {}
    for _, line in ipairs(wrong) do
        bad[#bad + 1] = line
    end
    if tsv.first_field(rows, "port-class") ~= "found" then
        bad[#bad + 1] = "port-class: the port's CharonSecProtocolStrings was not found"
    end
    local all = {}
    for _, pair in ipairs(SURVIVED) do
        all[#all + 1] = pair
    end
    for _, pair in ipairs(VALUES) do
        all[#all + 1] = pair
    end
    for _, pair in ipairs(all) do
        local label, expect = pair[1], pair[2]
        local got = tsv.first_field(rows, label)
        if got == nil then
            bad[#bad + 1] = label .. ": the case did not measure it"
        elseif got ~= tostring(expect) then
            bad[#bad + 1] = label .. ": got " .. got .. " and the port claims " .. expect
        end
    end
    for _, pair in ipairs(LIST) do
        local label, expect = pair[1], pair[2]
        local got = tsv.first_field(rows, label)
        if got == nil then
            bad[#bad + 1] = label .. ": the case did not read it"
        elseif got ~= expect then
            bad[#bad + 1] = label .. ": read [" .. got .. "] and the port claims [" .. expect .. "]"
        end
    end
    if tsv.first_field(rows, "failures") ~= "0" then
        bad[#bad + 1] = "the case reported " .. (tsv.first_field(rows, "failures") or "?") .. " failures"
    end
    for _, line in ipairs(bad) do
        print("DIFFERS " .. line)
    end
    if #bad > 0 then
        os.exit(1)
    end
    print("compared " .. #SURVIVED .. " survives, " .. #VALUES .. " values and " .. #LIST .. " list entries, in the order they were offered")
    os.exit(0)
end
