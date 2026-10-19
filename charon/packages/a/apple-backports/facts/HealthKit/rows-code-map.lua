-- The registry rows of a release's `absent` set, answered per OWNER CLASS from the releases' own caches.
--
-- Usage: CHARON_ROOT=<repo> xmake l packages/a/apple-backports/facts/HealthKit/rows-code-map.lua RELEASE...
--
-- Read through objc.code_map(), which gives every method a rung declares as
-- {owner, is_class_method, selector, imp, category} - so an answer can say WHICH class declares it,
-- whether it is a class method, and whether the class declares it of its own or a category adds it.
-- objc.inventory() cannot tell those three apart: modules/apple/objc.lua's method_list() keys BOTH of
-- a class's method lists with a leading "-" and nothing says whether an entry came from the class or
-- from a category. Measured: a first differential built on objc.inventory() answered NO for all sixteen
-- owners and all sixteen controls alike and could not tell a real zero from a blind reader.
--
-- WHAT IT IS FOR. A registry row's `reason` that says "the release does not carry this" is a claim about
-- the release, and a claim about a RELEASE is only worth what the release's own cache says. A zero with
-- no control is ambiguous - the name may be absent, or the reader may be looking at the wrong thing -
-- so this prints, per owner class, how many methods that class declares of its own. That count is the
-- control: an owner with a non-zero count and a zero for one selector is a real absence in that
-- selector, and an owner with a zero count everywhere means this reader is not seeing that class's
-- method lists and NO answer from this run may be written down. A rung that does not hold the class at
-- all prints own-methods-of-owner=0, which is NOT blindness and NOT an absence: it is the class being
-- absent, and the last line of the rung says so.
--
-- A SECOND ANSWER, and why it is here: `anywhere` names every class in the rung that declares a
-- selector at all. It is what keeps "the selector is a string in this cache" apart from "this class
-- declares it": measured, -endWorkoutSession: is a string in the armv7 caches of iOS 9.0 and later and
-- HKHealthStore declares it there, while in 18.0 CMWorkoutManager declares it as well, so a first-rung
-- answer for a selector says which release has the STRING and never which class owns it.

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
            -- The two the selector strings are in the ladder for: every class in this rung that has them.
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
