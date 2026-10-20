local json = import("core.base.json")

local failures, checks = 0, 0

local function expect(name, condition)
    checks = checks + 1
    if not condition then
        failures = failures + 1
        print("FAIL " .. name)
    end
end

local rows = {
    "-[HMAccessoryProfile init]", "+[HMAccessorySetupPayload new]", "-[HMAccessorySetupPayload init]",
    "+[HMAccessorySetupResult new]", "-[HMAccessorySetupResult init]", "-[HMCalendarEvent init]",
    "-[HMCameraProfile init]", "-[HMCharacteristicThresholdRangeEvent init]", "+[HMCharacteristicWriteAction new]",
    "-[HMDurationEvent init]", "+[HMEvent new]", "-[HMEventTrigger init]", "-[HMHomeAccessControl init]",
    "-[HMMutableCalendarEvent init]", "-[HMMutableCharacteristicEvent init]",
    "-[HMMutableCharacteristicThresholdRangeEvent init]", "-[HMMutableDurationEvent init]",
    "-[HMMutablePresenceEvent init]", "-[HMNumberRange init]", "-[HMPresenceEvent init]",
    "-[HMSignificantTimeEvent init]", "-[HMTrigger init]", "-[HMCharacteristicWriteAction init]", "-[HMEvent init]",
    "-[HKDeletedObject init]", "+[HKClinicalRecord new]",
    "-[HKCategorySample init]", "-[HKObject init]", "-[HKObjectType init]", "-[HKQuantity init]",
    "-[HKSource init]", "-[HKStatistics init]", "-[HKStatisticsCollection init]", "-[HKWorkoutEvent init]",
}

local neither = {
    "HMAccessoryProfile", "HMAccessorySetupPayload", "HMAccessorySetupResult", "HMCalendarEvent", "HMCameraProfile",
    "HMCharacteristicThresholdRangeEvent", "HMCharacteristicWriteAction", "HMDurationEvent", "HMEvent", "HMEventTrigger",
    "HMHomeAccessControl", "HMMutableCalendarEvent", "HMMutableCharacteristicEvent",
    "HMMutableCharacteristicThresholdRangeEvent", "HMMutableDurationEvent", "HMMutablePresenceEvent", "HMNumberRange",
    "HMPresenceEvent", "HMSignificantTimeEvent", "HMTrigger",
    "HKDeletedObject",
}

local function definitions(files, wanted)
    local found = {}
    for name in pairs(wanted) do
        found[name] = {}
    end
    for _, file in ipairs(files) do
        local current = nil
        for line in io.lines(file) do
            local cls = line:match("^@implementation%s+([%w_]+)")
            if cls then
                current = wanted[cls] and cls or nil
            elseif line:match("^@end") then
                current = nil
            end
            if current then
                local sign, sel = line:match("^([-+])%s*%([^)]*%)%s*([%w_]+)")
                if not sign then
                    sign, sel = line:match("^([-+])%s*([%w_]+)")
                end
                if (sign == "-" and sel == "init") or (sign == "+" and sel == "new") then
                    table.insert(found[current], path.filename(file) .. ": " .. line)
                end
            end
        end
    end
    return found
end

local raising = {
    "HKCategorySample", "HKObject", "HKObjectType", "HKQuantity", "HKSource", "HKStatistics",
    "HKStatisticsCollection", "HKWorkoutEvent",
}
local inheriting = { "HKSample", "HKQuantitySample", "HKWorkout", "HKCorrelation", "HKQuantityType" }

local function carries_macro(files, wanted)
    local found = {}
    for name in pairs(wanted) do
        found[name] = false
    end
    for _, file in ipairs(files) do
        local current = nil
        for line in io.lines(file) do
            local cls = line:match("^@implementation%s+([%w_]+)%s*{?%s*$")
            if cls then
                current = wanted[cls] and cls or nil
            elseif line:match("^@end") then
                current = nil
            end
            if current and line:match("^REVENANT_HEALTHKIT_UNCREATABLE_INIT%s*$") then
                found[current] = true
            end
        end
    end
    return found
end

local function constructions(files, classes)
    local hits = {}
    for _, file in ipairs(files) do
        local number = 0
        for line in io.lines(file) do
            number = number + 1
            for _, name in ipairs(classes) do
                if line:find("%[%[%s*" .. name .. "%s+alloc%]%s+init%]") or line:find("%[%s*" .. name .. "%s+new%]") then
                    table.insert(hits, path.filename(file) .. ":" .. number .. ": " .. line)
                end
            end
        end
    end
    return hits
end

local function revenant_builds(files, name)
    local count = 0
    for _, file in ipairs(files) do
        for line in io.lines(file) do
            if line:find("%[%[%s*" .. name .. "%s+alloc%]%s+revenant_init%]") then
                count = count + 1
            end
        end
    end
    return count
end

function main(revenant)
    local apple = path.join(revenant, "packages", "frameworks", "apple-backports")
    local files = table.join(os.files(path.join(apple, "HomeKit", "*.m")), os.files(path.join(apple, "HealthKit", "*.m")))

    local status = {}
    for _, file in ipairs(table.join(os.files(path.join(apple, "registry", "HomeKit", "*.json")),
                                     os.files(path.join(apple, "registry", "HealthKit", "*.json")))) do
        local data = json.decode(io.readfile(file))
        local entries = data.entries or data
        for _, entry in ipairs(entries) do
            if entry.api then
                status[entry.api] = entry.status
            end
        end
    end
    for _, api in ipairs(rows) do
        expect(api .. " is implemented in the registry", status[api] == "implemented")
    end

    local wanted = {}
    for _, name in ipairs(neither) do
        wanted[name] = true
    end
    wanted["HMAction"] = true
    local defined = definitions(files, wanted)
    expect("the control HMAction shows its own -init, so the scanner reads blocks", #defined["HMAction"] == 1)
    for _, name in ipairs(neither) do
        expect(name .. " defines neither -init nor +new in the port", #defined[name] == 0)
    end

    local hk_files = os.files(path.join(apple, "HealthKit", "*.m"))
    local raise_wanted = {}
    for _, name in ipairs(raising) do
        raise_wanted[name] = true
    end
    local macros = carries_macro(hk_files, raise_wanted)
    for _, name in ipairs(raising) do
        expect(name .. " carries REVENANT_HEALTHKIT_UNCREATABLE_INIT in its own @implementation block", macros[name])
    end

    local hits = constructions(hk_files, table.join(raising, inheriting))
    for _, hit in ipairs(hits) do
        print("  " .. hit)
    end
    expect("no HealthKit source builds a raising class through -init or +new", #hits == 0)
    expect("the control: HKStatistics builds through revenant_init at least twice", revenant_builds(hk_files, "HKStatistics") >= 2)
    expect("the control: HKStatisticsCollection builds through revenant_init at least twice",
           revenant_builds(hk_files, "HKStatisticsCollection") >= 2)

    print(string.format("checks=%d failures=%d", checks, failures))
    if failures > 0 then
        raise("init-inherited: %d of %d checks failed", failures, checks)
    end
end
