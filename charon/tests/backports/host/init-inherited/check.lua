-- check.lua - the -init and +new rows of HomeKit and HealthKit that this group implements.
--
-- Two kinds of row are here. The HomeKit and HKDeletedObject rows name a class whose own list carries neither
-- selector on iOS 16.0 (tools/objc-init-members.lua, arm64e cache, NSObject as the control): the caller reaches
-- NSObject's pair, and the port must define neither. The eight HealthKit -init rows name a class whose own -init
-- raises, measured at run time on the macOS host (tests/backports/host/init-inherited/host.sh): the port defines
-- CHARON_HEALTHKIT_UNCREATABLE_INIT in each of the eight, and nothing in the port reaches -init or +new on any of
-- them or on a class that inherits the raise. Every row must say implemented, with the facts file the row names.
--
-- Four things are asked, and each one has a control:
--   * the REGISTRY: every row named here is implemented. A row that went back to absent would say that
--     respondsToSelector: answers NO, which the NSObject pair contradicts.
--   * the SOURCE, neither: no @implementation block of a class named here defines -init or +new. The control is
--     HMAction, which defines an -init of its own, so a scanner that reads nothing would report 0 for it and
--     the check says so.
--   * the SOURCE, raising: each @implementation block of the eight carries the macro. The control is that the
--     macro is found in exactly these eight blocks and no other, read from the same files.
--   * the SOURCE, construction: no line of a HealthKit source builds one of the eight, or a class that inherits
--     the raise, through -init or +new. The control is HKStatistics, which builds through charon_init, so a
--     scanner that reads nothing would report 0 for it and the check says so.
--
-- What this does NOT check is the object: the built library's own class list. The gate's objects carry it,
-- and it is read with objc.binary_inventory when a gate run is kept; the source check is the one that runs on
-- every light guard.

local json = import("core.base.json")

local failures, checks = 0, 0

local function expect(name, condition)
    checks = checks + 1
    if not condition then
        failures = failures + 1
        print("FAIL " .. name)
    end
end

-- The rows this group closes: the 24 HomeKit rows, HKDeletedObject's -init, HKClinicalRecord's +new, and the eight
-- HealthKit -init rows that raise on the host.
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

-- The classes whose own lists carry neither selector: no @implementation block of theirs may define one.
local neither = {
    "HMAccessoryProfile", "HMAccessorySetupPayload", "HMAccessorySetupResult", "HMCalendarEvent", "HMCameraProfile",
    "HMCharacteristicThresholdRangeEvent", "HMCharacteristicWriteAction", "HMDurationEvent", "HMEvent", "HMEventTrigger",
    "HMHomeAccessControl", "HMMutableCalendarEvent", "HMMutableCharacteristicEvent",
    "HMMutableCharacteristicThresholdRangeEvent", "HMMutableDurationEvent", "HMMutablePresenceEvent", "HMNumberRange",
    "HMPresenceEvent", "HMSignificantTimeEvent", "HMTrigger",
    "HKDeletedObject",
}

-- Every @implementation block of a class in `wanted`, read line by line, with each -init and +new it defines.
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

-- The eight HealthKit classes whose own -init raises on the host, and the classes that inherit that raise: a
-- HealthKit source may not build any of them through -init or +new.
local raising = {
    "HKCategorySample", "HKObject", "HKObjectType", "HKQuantity", "HKSource", "HKStatistics",
    "HKStatisticsCollection", "HKWorkoutEvent",
}
local inheriting = { "HKSample", "HKQuantitySample", "HKWorkout", "HKCorrelation", "HKQuantityType" }

-- Every @implementation block of a class in `wanted`, and whether the block carries the uncreatable-init macro.
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
            if current and line:match("^CHARON_HEALTHKIT_UNCREATABLE_INIT%s*$") then
                found[current] = true
            end
        end
    end
    return found
end

-- The lines of `files` that build one of `classes` through -init or +new: [[X alloc] init] and [X new].
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

-- The lines of `files` that build `name` through charon_init: the control that the scan above reads the sources.
local function charon_builds(files, name)
    local count = 0
    for _, file in ipairs(files) do
        for line in io.lines(file) do
            if line:find("%[%[%s*" .. name .. "%s+alloc%]%s+charon_init%]") then
                count = count + 1
            end
        end
    end
    return count
end

function main(charon)
    local apple = path.join(charon, "packages", "a", "apple-backports")
    local files = table.join(os.files(path.join(apple, "HomeKit", "*.m")), os.files(path.join(apple, "HealthKit", "*.m")))

    -- REGISTRY: each row named above is implemented
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

    -- SOURCE: neither selector is defined by any block of the classes named as carrying neither
    local wanted = {}
    for _, name in ipairs(neither) do
        wanted[name] = true
    end
    wanted["HMAction"] = true -- the control: this class defines an -init of its own
    local defined = definitions(files, wanted)
    expect("the control HMAction shows its own -init, so the scanner reads blocks", #defined["HMAction"] == 1)
    for _, name in ipairs(neither) do
        expect(name .. " defines neither -init nor +new in the port", #defined[name] == 0)
    end

    -- SOURCE, raising: each of the eight carries the macro in its own @implementation block
    local hk_files = os.files(path.join(apple, "HealthKit", "*.m"))
    local raise_wanted = {}
    for _, name in ipairs(raising) do
        raise_wanted[name] = true
    end
    local macros = carries_macro(hk_files, raise_wanted)
    for _, name in ipairs(raising) do
        expect(name .. " carries CHARON_HEALTHKIT_UNCREATABLE_INIT in its own @implementation block", macros[name])
    end

    -- SOURCE, construction: nothing builds the eight, or a class that inherits the raise, through -init or +new.
    -- The control is that the scan reads HKStatistics's and HKStatisticsCollection's charon_init sites.
    local hits = constructions(hk_files, table.join(raising, inheriting))
    for _, hit in ipairs(hits) do
        print("  " .. hit)
    end
    expect("no HealthKit source builds a raising class through -init or +new", #hits == 0)
    expect("the control: HKStatistics builds through charon_init at least twice", charon_builds(hk_files, "HKStatistics") >= 2)
    expect("the control: HKStatisticsCollection builds through charon_init at least twice",
           charon_builds(hk_files, "HKStatisticsCollection") >= 2)

    print(string.format("checks=%d failures=%d", checks, failures))
    if failures > 0 then
        raise("init-inherited: %d of %d checks failed", failures, checks)
    end
end
