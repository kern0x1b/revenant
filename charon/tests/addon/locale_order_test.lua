local LOCALES = {
    {name = "C", envs = {LC_ALL = "C"}},
    {name = "en_NZ.UTF-8", envs = {LC_ALL = "", LANG = "en_NZ.UTF-8"}},
    {name = "en_US.UTF-8", envs = {LC_ALL = "", LANG = "en_US.UTF-8"}},
}

local NOT_STRINGS = {
    ["modules/emulator.lua|table.sort(held, function (a, b) return a.address < b.address end)"] = "addresses",
    ["modules/emulator.lua|table.sort(named, function (a, b) return a.address < b.address end)"] = "addresses",
    ["modules/apple/backports.lua|table.sort(candidates, function (a, b)"] = "preferred rank, then byteorder.less",
    ["modules/apple/backports.lua|table.sort(named, function (a, b)"] = "status order, then byteorder.less",
    ["modules/apple/backports.lua|table.sort(order, function (a, b) return lower(a, b) == a and a ~= b end)"] = "versions",
    ["modules/apple/backports.lua|table.sort(found, function (a, b) return dyld.compare_versions(a, b) < 0 end)"] = "versions",
    ["modules/apple/backports.lua|table.sort(points, function (a, b) return dyld.compare_versions(a, b) < 0 end)"] = "versions",
    ["modules/apple/backports.lua|table.sort(listed, function (a, b) return dyld.compare_versions(a, b) < 0 end)"] = "versions",
    ["modules/packaging.lua|table.sort(merged, function (a, b) return a ~= executable and b == executable end)"] = "booleans",
    ["modules/apple/sdkstubs.lua|table.sort(found, function (a, b) return release(a) < release(b) end)"] = "numbers",
    ["modules/apple/dyld.lua|table.sort(releases, function (a, b) return compare(a, b) < 0 end)"] = "versions",
    ["modules/apple/dyld.lua|table.sort(ladder, function (a, b) return compare(a.release, b.release) < 0 end)"] = "versions",
    ["modules/apple/dyld.lua|table.sort(missing, function (a, b)"] = "byteorder.less on both names",
    ["modules/apple/dyld.lua|table.sort(dangling, function (a, b)"] = "byteorder.less on both names",
    ["modules/apple/dyld.lua|table.sort(ordering, function (a, b)"] = "byteorder.less on both names",
    ["modules/apple/dyld.lua|table.sort(slots)"] = "numbers",
    ["modules/apple/firmware.lua|table.sort(chosen, function (a, b) return a.size < b.size end)"] = "sizes",
    ["modules/apple/firmware.lua|table.sort(listed, function (a, b) return dyld.compare_versions(a, b) < 0 end)"] = "versions",
    ["modules/gyb/runtime.lua|table.sort(keyed, function(a, b)"] = "Python's order, byteorder.less on strings, then the index",
    ["tools/matter-registry.lua|table.sort(types, function (left, right) return #left > #right end)"] = "lengths",
    ["tools/symbol-first-release.lua|table.sort(found, function (a, b) return os.mtime(a) > os.mtime(b) end)"] = "modification times",
    ["tools/corpus/skeleton-table.lua|table.sort(addresses)"] = "numbers",
    ["tools/corpus/cache-value.lua|table.sort(entries, function (a, b) return a.address < b.address end)"] = "addresses",
}

local function unsorted_strings(root)
    local found, sites, on_byteorder, used = {}, 0, 0, {}
    for _, folder in ipairs({"addons", "modules", "tools"}) do
        for _, file in ipairs(os.files(path.join(root, folder, "**.lua"))) do
            local relative = path.relative(file, root)
            if not relative:find("/gen/", 1, true) and relative ~= "modules/byteorder.lua" then
                local number = 0
                for line in io.lines(file) do
                    number = number + 1
                    local text = line:trim()
                    if text:find("table.sort(", 1, true) or text:find("byteorder.sort(", 1, true) then
                        sites = sites + 1
                        local key = relative .. "|" .. text
                        if text:find("byteorder", 1, true) then
                            on_byteorder = on_byteorder + 1
                        elseif NOT_STRINGS[key] then
                            used[key] = true
                        else
                            table.insert(found, string.format("%s:%d sorts with table.sort outside byteorder: %s", relative, number, text))
                        end
                    end
                end
            end
        end
    end
    for key in pairs(NOT_STRINGS) do
        if not used[key] then
            table.insert(found, "the allowlist entry matches no table.sort in the tree: " .. key)
        end
    end
    return found, sites, on_byteorder
end

function failures(opt)
    local found = {}
    local probe = path.join(opt.modules, "..", "tests", "addon", "locale_probe.lua")
    local work = path.join(os.tmpdir(), "locale_order_test-" .. os.getpid())
    os.tryrm(work)
    os.mkdir(work)
    local outputs = {}
    for _, locale in ipairs(LOCALES) do
        local log = path.join(work, locale.name:gsub("[^%w]", "_") .. ".out")
        local code = os.execv(os.programfile(), {"l", probe, opt.modules, path.join(work, "fixtures")},
                              {curdir = work, envs = locale.envs, try = true, stdout = log, stderr = log})
        local text = io.readfile(log) or ""
        if code ~= 0 then
            table.insert(found, string.format("the probe under %s exited %s: %s", locale.name, tostring(code), text:sub(1, 400)))
        end
        outputs[locale.name] = text
    end
    os.tryrm(work)

    local function by_case(text)
        local cases, order = {}, {}
        for line in text:gmatch("[^\n]+") do
            local case = line:match("^([^\t]+)\t")
            if case then
                if not cases[case] then
                    cases[case] = {}
                    table.insert(order, case)
                end
                table.insert(cases[case], line)
            end
        end
        return cases, order
    end
    local reference = LOCALES[1].name
    local expected, order = by_case(outputs[reference])
    local compared = 0
    for _, case in ipairs(order) do
        local count = #expected[case]
        compared = compared + count
        if count == 0 then
            table.insert(found, case .. " printed nothing under " .. reference)
        end
    end
    if compared == 0 then
        table.insert(found, "the comparison compared 0 strings under " .. reference .. ": the probe printed nothing to compare")
    end
    for index = 2, #LOCALES do
        local locale = LOCALES[index].name
        local got = by_case(outputs[locale])
        for _, case in ipairs(order) do
            local wanted, have = table.concat(expected[case], "\n"), table.concat(got[case] or {}, "\n")
            if wanted ~= have then
                local at = 1
                local lines, others = expected[case], got[case] or {}
                while at <= #lines and lines[at] == others[at] do at = at + 1 end
                table.insert(found, string.format("%s differs between %s and %s, first at line %d: %s, not %s",
                    case, reference, locale, at, tostring(lines[at]), tostring(others[at])))
            end
        end
    end
    local bare, sites, on_byteorder = unsorted_strings(path.directory(opt.modules))
    if sites == 0 then
        table.insert(found, "the scan of table.sort sites read 0 sites")
    end
    for _, failure in ipairs(bare) do
        table.insert(found, failure)
    end
    print(string.format("locale_order_test: compared %d strings in %d cases under %d locales, %d differences", compared, #order, #LOCALES, #found))
    print(string.format("locale_order_test: %d sort sites outside tools/gen read: %d on byteorder, %d allowlisted as not strings or byteorder-below-a-number, %d bare",
        sites, on_byteorder, sites - on_byteorder - #bare, #bare))
    return found
end
