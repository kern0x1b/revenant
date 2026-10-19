local rows = {
    {"HKQuery", "predicateForStatesOfMindWithValence:operatorType:", true},
    {"HKQuery", "predicateForStatesOfMindWithKind:", true},
    {"HKQuery", "predicateForStatesOfMindWithLabel:", true},
    {"HKQuery", "predicateForStatesOfMindWithAssociation:", true},
    {"HKHealthStore", "startWorkoutSession:", false},
    {"HKHealthStore", "endWorkoutSession:", false},
    {"HKHealthStore", "pauseWorkoutSession:", false},
    {"HKHealthStore", "resumeWorkoutSession:", false},
    {"HKObject", "init", false},
    {"HKObjectType", "init", false},
    {"HKQuantity", "init", false},
    {"HKSource", "init", false},
    {"HKStatistics", "init", false},
    {"HKStatisticsCollection", "init", false},
    {"HKCategorySample", "init", false},
    {"HKWorkoutEvent", "init", false},
}

local OWNERS = {}
for _, row in ipairs(rows) do OWNERS[row[1]] = true end
for owner in pairs(OWNERS) do
    if owner ~= "HKQuery" and owner ~= "HKHealthStore" then OWNERS[owner] = true end
end

local root = path.join(os.getenv("CHARON_ROOT"), "modules")
local objc = import("apple.objc", {rootdir = root, anonymous = true})
local dyld = import("apple.dyld", {rootdir = root, anonymous = true})

local held = {}
for _, rung in ipairs(dyld.held_ladder({"armv7", "armv7s"})) do held[rung.release] = rung end

function main(...)
    local wanted = {...}
    if #wanted == 0 then wanted = {"8.0", "6.1.3", "4.3", "9.0", "18.0"} end
    for _, release in ipairs(wanted) do
        local rung = held[release]
        if not rung then
            print(string.format("== %s  NOT HELD", release))
        else
            local map = objc.code_map(rung.source)
            local own, anywhere, present = {}, {}, {}
            for _, image in ipairs(map.images) do
                for _, method in ipairs(image.methods or {}) do
                    local owner, meta, selector, category = method[1], method[2], method[3], method[5]
                    if OWNERS[owner] then
                        present[owner] = true
                        own[owner] = (own[owner] or 0) + (category == nil and 1 or 0)
                    end
                    local key = (meta and "+" or "-") .. owner .. " " .. selector
                    if not anywhere[key] then
                        anywhere[key] = {}
                        table.insert(anywhere[key], category == nil and "own" or ("category " .. tostring(category)))
                    end
                end
            end
            print(string.format("== %s  %s  %s", release, rung.architecture, rung.source))
            print(string.format("   %d images, %d methods", #map.images,
                                (function()
                                    local n = 0
                                    for _, image in ipairs(map.images) do
                                        n = n + (image.methods and #image.methods or 0)
                                    end
                                    return n
                                end)()))
            for _, row in ipairs(rows) do
                local owner, selector, meta = row[1], row[2], row[3]
                local key = (meta and "+" or "-") .. owner .. " " .. selector
                local said = anywhere[key] or {}
                print(string.format("   %s%-22s %-46s  own-methods-of-owner=%-5d  %s", meta and "+" or "-",
                                    owner, selector, own[owner] or 0,
                                    #said > 0 and table.concat(said, " / ") or "NOT DECLARED BY THIS CLASS"))
            end
            for _, selector in ipairs({"predicateForStatesOfMindWithValence:operatorType:",
                                       "startWorkoutSession:", "endWorkoutSession:",
                                       "pauseWorkoutSession:", "resumeWorkoutSession:"}) do
                local holders = {}
                for key, said in pairs(anywhere) do
                    if key:endswith(" " .. selector) then
                        for _, entry in ipairs(said) do table.insert(holders, key .. " [" .. entry .. "]") end
                    end
                end
                table.sort(holders)
                print(string.format("   anywhere %-46s  %s", selector,
                                    #holders > 0 and table.concat(holders, ", ") or "no class in this rung"))
            end
            local absent, blind = {}, {}
            for owner in pairs(OWNERS) do
                if not present[owner] then table.insert(absent, owner) elseif (own[owner] or 0) == 0 then table.insert(blind, owner) end
            end
            table.sort(absent)
            table.sort(blind)
            if #absent > 0 then
                print("   this rung holds none of: " .. table.concat(absent, ", "))
            end
            if #blind > 0 then
                print("   CONTROL FAILED: present but with no own method list: " .. table.concat(blind, ", "))
            else
                print("   control: every owner class this rung holds declares methods of its own")
            end
        end
    end
end
