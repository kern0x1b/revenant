function main(checkout)
    local revenant = path.absolute(checkout or path.directory(os.scriptdir()))
    local addon = path.join(revenant, "tests", "addon")
    local modules = path.join(revenant, "modules")
    local names = {"descriptions_test", "checkout_test", "dependency_test", "swift_rule_test", "workspace_test",
                   "revenant_index_test"}
    if os.isfile(path.join(addon, "lock_test.lua")) then
        table.insert(names, "lock_test")
    end
    if os.isfile(path.join(addon, "cache_sweep_test.lua")) then
        table.insert(names, "cache_sweep_test")
    end
    if os.isfile(path.join(addon, "sdk_verbatim_test.lua")) then
        table.insert(names, "sdk_verbatim_test")
    end
    if os.isfile(path.join(addon, "locale_order_test.lua")) then
        table.insert(names, "locale_order_test")
    end
    local failed = 0
    for _, name in ipairs(names) do
        local t = import(name, {rootdir = addon, anonymous = true})
        local failures = t.failures({modules = modules})
        if #failures == 0 then
            print(name .. ": OK (0 failures)")
        else
            for _, f in ipairs(failures) do print(name .. " FAIL: " .. f) end
            failed = failed + #failures
        end
    end
    if failed > 0 then
        print("light guard: " .. failed .. " failure(s)")
        os.exit(1)
    end
end
