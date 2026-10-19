import("fixtures")

function failures(opt)
    local architectures = import("apple.architectures", {rootdir = opt.modules, anonymous = true})
    local found = {}
    for _, case in ipairs({{"armv6", "2.0"}, {"armv6", "2.2.1"}, {"armv6", "4.2.1"}, {"armv7", "3.0"}, {"armv7", "6.1.3"},
                           {"armv7s", "6.0"}, {"arm64", "7.0"}}) do
        local kept = architectures.deployment(case[1], case[2])
        if kept ~= case[2] then
            table.insert(found, string.format("a %s port for %s builds for the release it declares, not %s", case[1], case[2], tostring(kept)))
        end
    end
    for _, case in ipairs({{"armv7", "2.0", "apple_minimum 2.0 is older than 3.0, the first release an armv7 device runs"},
                           {"armv7", "2.0", "armv6 runs it, so build that architecture, or raise apple_minimum to 3.0"},
                           {"armv7", "1.1.4", "no architecture this toolchain builds runs it, so raise apple_minimum to 3.0"},
                           {"armv7s", "5.1.1", "older than 6.0, the first release an armv7s device runs"},
                           {"arm64", "6.1.3", "older than 7.0, the first release an arm64 device runs"},
                           {"armv6", "6.0", "apple_minimum 6.0 is newer than 4.2.1, the last release an armv6 device runs"},
                           {"armv8", "6.0", "toolchain(apple-ios) builds arm64, armv6, armv7, armv7s, not armv8"}}) do
        local errors = fixtures.refusal(function () architectures.deployment(case[1], case[2]) end)
        if not errors then
            table.insert(found, string.format("a %s port for %s must be refused, not quietly built for another release", case[1], case[2]))
        elseif not errors:find(case[3], 1, true) then
            table.insert(found, string.format("a %s port for %s must be refused saying %s, and said: %s", case[1], case[2], case[3], errors))
        end
    end

    -- The slice of a universal target: modules/apple/slices.lua repeats the toolchain's bounds because the toolchain's own
    -- file is in the digest of every package, so it is held to them here, both ways.
    local slices = import("apple.slices", {rootdir = opt.modules, anonymous = true})
    local floors, lasts = slices.slice_floors()
    local named = {}
    for _, name in ipairs(table.orderkeys(floors)) do
        table.insert(named, name)
    end
    local builds = fixtures.refusal(function () architectures.deployment("armv8", "6.0") end) or ""
    if not builds:find("builds " .. table.concat(named, ", ") .. ", not armv8", 1, true) then
        table.insert(found, string.format("slices.lua knows %s and the toolchain builds another set: %s", table.concat(named, ", "), builds))
    end
    for name, floor in pairs(floors) do
        if architectures.deployment(name, floor) ~= floor then
            table.insert(found, string.format("slices.lua says %s first runs %s, and the toolchain builds it for another", name, floor))
        end
        local below = fixtures.refusal(function () architectures.deployment(name, "1.0") end) or ""
        if not below:find("older than " .. floor .. ", the first release an " .. name .. " device runs", 1, true) then
            table.insert(found, string.format("slices.lua says %s first runs %s, and the toolchain says: %s", name, floor, below))
        end
        local last = lasts[name]
        local above = fixtures.refusal(function () architectures.deployment(name, "99.0") end) or ""
        if (last ~= nil) ~= (above:find("the last release an " .. name .. " device runs", 1, true) ~= nil) or
           (last and not above:find("newer than " .. last .. ",", 1, true)) then
            table.insert(found, string.format("slices.lua says %s last runs %s, and the toolchain says: %s", name, tostring(last), above))
        end
    end
    for _, case in ipairs({
        {"arm64", "6.0", "armv7,arm64", "7.0", "armv7"},
        {"arm64", "6.0", "arm64,armv7", "7.0", "armv7"},
        {"arm64", "6.1.3", "armv7,armv7s,arm64", "7.0", "armv7"},
        {"armv7s", "5.0", "armv7,armv7s", "6.0", "armv7"},
        {"armv7", "2.0", "armv6,armv7", "3.0", "armv6"},
        {"armv7", "6.0", "armv7,arm64", "6.0", nil},
        {"arm64", "7.0", "armv7,arm64", "7.0", nil},
        {"arm64", "8.0", "armv7,arm64", "8.0", nil},
        {"arm64", "6.0", nil, "6.0", nil},
        {"arm64", "6.0", "arm64", "6.0", nil},
        {"arm64", "6.0", "armv6,arm64", "6.0", nil},
        {"armv7", "2.0", "armv7", "2.0", nil},
        {"armv8", "6.0", "armv7,armv8", "6.0", nil}}) do
        local release, kept = slices.slice_minimum(case[1], case[2], case[3])
        if release ~= case[4] or kept ~= case[5] then
            table.insert(found, string.format("a %s slice declared %s among %s is built for %s by %s, not %s by %s", case[1], case[2],
                                              tostring(case[3]), tostring(release), tostring(kept), case[4], tostring(case[5])))
        end
    end
    -- A description cannot import, so the project's includes include it; and the rule imports it.
    local includes = io.readfile(path.join(opt.modules, "..", "includes", "apple-ios", "xmake.lua"))
    local rule = io.readfile(path.join(opt.modules, "..", "rules", "apple-ios", "xmake.lua"))
    if not includes:find('"slices.lua"', 1, true) or not includes:find("slice_minimum(", 1, true) then
        table.insert(found, "the includes of apple-ios must build the packages of a slice for the release its architecture first runs")
    end
    if not rule:find("apple.slices", 1, true) or not rule:find("slice_minimum(", 1, true) then
        table.insert(found, "the rule of apple-ios must build the target's slice for the release its architecture first runs")
    end
    return found
end
