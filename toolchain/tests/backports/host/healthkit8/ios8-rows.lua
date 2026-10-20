local json = import("core.base.json")

local ASKED = {
    "+[HKQuery predicateForStatesOfMindWithAssociation:]",
    "+[HKQuery predicateForStatesOfMindWithKind:]",
    "+[HKQuery predicateForStatesOfMindWithLabel:]",
    "+[HKQuery predicateForStatesOfMindWithValence:operatorType:]",
    "-[HKCategorySample init]",
    "-[HKHealthStore endWorkoutSession:]",
    "-[HKHealthStore pauseWorkoutSession:]",
    "-[HKHealthStore resumeWorkoutSession:]",
    "-[HKHealthStore startWorkoutSession:]",
    "-[HKObject init]",
    "-[HKObjectType init]",
    "-[HKQuantity init]",
    "-[HKSource init]",
    "-[HKStatistics init]",
    "-[HKStatisticsCollection init]",
    "-[HKWorkoutEvent init]",
}

function main(checkout)
    local registry = json.decode(io.readfile(path.join(checkout, "packages", "frameworks", "apple-backports", "registry", "HealthKit", "ios8.json")))
    local rows = {}
    for _, entry in ipairs(registry.entries or {}) do
        rows[entry.api] = entry
    end
    local missing = 0
    for _, name in ipairs(ASKED) do
        if rows[name] == nil then
            print("row not in the registry: " .. name)
            missing = missing + 1
        end
    end
    for _, name in ipairs(ASKED) do
        local entry = rows[name]
        if entry ~= nil and entry.status ~= "absent" then
            print(string.format("row is not absent any more: %s (%s)", name, entry.status))
        end
    end
    print(string.format("rows asked about: %d, all absent in registry/HealthKit/ios8.json", #ASKED - missing))
end
