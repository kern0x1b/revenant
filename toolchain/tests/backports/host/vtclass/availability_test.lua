local A = import("availability", {rootdir = os.scriptdir()})
local V = import("vtlib", {rootdir = os.scriptdir()})
local S = import("pystr", {rootdir = os.scriptdir()})

local TABLE = {
    {"VTFrameProcessor", "26.0"},
    {"VTFrameProcessorFrame", "26.0"},
    {"VTFrameProcessorOpticalFlow", "26.0"},
    {"VTFrameRateConversionConfiguration", "26.0"},
    {"VTFrameRateConversionParameters", "26.0"},
    {"VTLowLatencyFrameInterpolationConfiguration", "26.0"},
    {"VTLowLatencyFrameInterpolationParameters", "26.0"},
    {"VTLowLatencySuperResolutionScalerConfiguration", "26.0"},
    {"VTLowLatencySuperResolutionScalerParameters", "26.0"},
    {"VTMotionBlurConfiguration", "26.0"},
    {"VTMotionBlurParameters", "26.0"},
    {"VTOpticalFlowConfiguration", "26.0"},
    {"VTOpticalFlowParameters", "26.0"},
    {"VTSuperResolutionScalerConfiguration", "26.0"},
    {"VTSuperResolutionScalerParameters", "26.0"},
    {"VTTemporalNoiseFilterConfiguration", "26.0"},
    {"VTTemporalNoiseFilterParameters", "26.0"},
}

local function headers(sdk)
    local directory = sdk .. "/System/Library/Frameworks/VideoToolbox.framework/Headers"
    local paths = V.sort_bytes(os.files(directory .. "/*.h"))
    local out = {}
    for _, path in ipairs(paths) do
        out[#out + 1] = {S.basename(path), V.read_text(path)}
    end
    return out
end

local function replace_first(text, old, new)
    local at = string.find(text, old, 1, true)
    if at == nil then
        return text
    end
    return string.sub(text, 1, at - 1) .. new .. string.sub(text, at + #old)
end

function main(...)
    local args = {...}
    local sdk = args[1]
    if sdk == nil then
        sdk = os.getenv("VT_SDK") or ""
    end
    if sdk == "" then
        V.fail("availability_test.lua: set VT_SDK to an iPhoneOS*.sdk")
    end
    local texts = headers(sdk)
    local parts = {}
    for _, pair in ipairs(texts) do
        parts[#parts + 1] = pair[2]
    end
    local joined = table.concat(parts, "\n")
    local bad = {}
    for _, row in ipairs(TABLE) do
        local name, wanted = row[1], row[2]
        local got, line = nil, nil
        local failure = nil
        try {
            function()
                got, line = A.availability_of(joined, name)
            end,
            catch {
                function(err)
                    failure = tostring(err)
                end
            }
        }
        if failure ~= nil then
            bad[#bad + 1] = name .. ": " .. S.split_newlines(failure)[1]
        elseif got ~= wanted then
            bad[#bad + 1] = string.format("%s: the header says ios %s and the hand-read table says %s",
                name, got, wanted)
        else
            print(string.format("  %-48s ios %-5s from line %d", name, got, line))
        end
    end
    local victim = nil
    for _, pair in ipairs(texts) do
        if S.contains(pair[2], "VTTemporalNoiseFilterConfiguration") then
            victim = pair
            break
        end
    end
    if victim == nil then
        bad[#bad + 1] = "the control could not find a header to copy"
    else
        local broken = replace_first(victim[2], "API_AVAILABLE(", "API_XAVAILABLE(")
        local raised = false
        try {
            function()
                A.availability_of(broken, "VTTemporalNoiseFilterConfiguration")
            end,
            catch {
                function(err)
                    raised = true
                end
            }
        }
        if raised then
            print("  control: a header with its API_AVAILABLE renamed raises, as it must")
        else
            bad[#bad + 1] = "the control did NOT raise: a header with its availability macro renamed still "
                .. "resolved, so a class with no stated version would be given one"
        end
    end
    for _, line in ipairs(bad) do
        print("FAIL " .. line)
    end
    if #bad > 0 then
        os.exit(1)
    end
    print(string.format("availability: %d of %d resolve, control raises", #TABLE, #TABLE))
end
