local addon_suites = {"descriptions_test", "checkout_test", "dependency_test", "swift_rule_test", "workspace_test",
                      "lock_test", "cache_sweep_test", "sdk_verbatim_test", "locale_order_test"}

function main(checkout)
    local revenant = path.absolute(checkout or path.directory(os.scriptdir()))
    local addon = path.join(revenant, "tests", "addon")
    local modules = path.join(revenant, "modules")
    local failed = 0
    for _, name in ipairs(addon_suites) do
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
