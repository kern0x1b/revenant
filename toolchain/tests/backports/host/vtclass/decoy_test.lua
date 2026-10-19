local G = import("gen_body", {rootdir = os.scriptdir()})
local V = import("vtlib", {rootdir = os.scriptdir()})

local DECOY_CLASS = "VTDecoyFrameProcessorConfiguration"
local DECOY_ARGUMENT = "revenantNotAProperty"

local function run_checks()
    local bad = {}
    if G.declared_key(DECOY_CLASS, DECOY_ARGUMENT) ~= nil then
        bad[#bad + 1] = "the decoy is IN DECLARED_KEYS, so nothing would refuse it"
    end
    if G.PRIVATE_KEYS()[DECOY_ARGUMENT] then
        bad[#bad + 1] = "the decoy is in PRIVATE_KEYS, so it would be stored as a private key"
    end
    for _, c in ipairs(G.ORDER()) do
        if c == DECOY_CLASS then
            bad[#bad + 1] = "the decoy class is in ORDER, so the generator would try to emit it"
        end
    end

    local accepted = false
    local refusal = nil
    try {
        function()
            G.store_key(DECOY_ARGUMENT, G.odict_new(), "the decoy", DECOY_CLASS)
            accepted = true
        end,
        catch {
            function(err)
                if tostring(err):find("DECLARED_KEYS names the property", 1, true) then
                    V.fail(tostring(err))
                end
                refusal = tostring(err)
            end
        }
    }
    if accepted then
        bad[#bad + 1] = "store_key ACCEPTED a name in neither table - the rule cannot fail"
    elseif refusal ~= nil then
        print("  the decoy is refused, as it must be:")
        local start = 1
        while true do
            local p = refusal:find(". ", start, true)
            local piece = refusal:sub(start, (p or 0) - 1)
            if not p then piece = refusal:sub(start) end
            print("      " .. (piece:gsub("^%s+", ""):gsub("%s+$", "")))
            if not p then break end
            start = p + 2
        end
        for _, wanted in ipairs({DECOY_ARGUMENT, DECOY_CLASS}) do
            if not refusal:find(wanted, 1, true) then
                bad[#bad + 1] = "the refusal does not name '" .. wanted .. "', so it cannot be acted on"
            end
        end
    end
    return bad
end

function main(...)
    local bad = nil
    try {
        function()
            bad = run_checks()
        end,
        catch {
            function(err)
                V.fail(tostring(err))
            end
        }
    }
    for _, line in ipairs(bad) do
        print("FAIL " .. line)
    end
    if #bad > 0 then
        os.exit(1)
    end
    print(string.format("decoy: %s.%s is in neither table, and store_key refuses it by name",
        DECOY_CLASS, DECOY_ARGUMENT))
end
