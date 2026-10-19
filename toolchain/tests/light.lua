function main(checkout)
    local revenant = path.absolute(checkout or path.directory(os.scriptdir()))
    local addon = path.join(revenant, "tests", "addon")
    local modules = path.join(revenant, "modules")
    local names = {"descriptions_test", "checkout_test", "registry_test", "dependency_test", "swift_rule_test", "workspace_test"}
    if os.isfile(path.join(addon, "lock_test.lua")) then
        table.insert(names, "lock_test")
    end
    if os.isfile(path.join(addon, "cache_sweep_test.lua")) then
        table.insert(names, "cache_sweep_test")
    end
    if os.isfile(path.join(addon, "protocol_headers_test.lua")) then
        table.insert(names, "protocol_headers_test")
    end
    if os.isfile(path.join(addon, "matter_closure_test.lua")) then
        table.insert(names, "matter_closure_test")
    end
    if os.isfile(path.join(addon, "sdk_verbatim_test.lua")) then
        table.insert(names, "sdk_verbatim_test")
    end
    if os.isfile(path.join(addon, "matter_objects_test.lua")) then
        table.insert(names, "matter_objects_test")
    end
    if os.isfile(path.join(addon, "locale_order_test.lua")) then
        table.insert(names, "locale_order_test")
    end
    if os.isfile(path.join(addon, "py_values_test.lua")) then
        table.insert(names, "py_values_test")
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
    if os.isfile(path.join(addon, "archive_language_test.lua")) then
        local ok = try {
            function ()
                import("archive_language_test", {rootdir = addon, anonymous = true}).main()
                print("archive_language_test: OK (0 failures)")
                return true
            end,
            catch {
                function (errors)
                    print("archive_language_test FAIL: " .. tostring(errors))
                end
            }
        }
        if not ok then failed = failed + 1 end
    end
    local corpus_lua_test = path.join(revenant, "tools", "corpus", "tests", "corpus_test.lua")
    if os.isfile(corpus_lua_test) then
        local ok = try {
            function ()
                os.execv(os.programfile(), {"l", corpus_lua_test}, {stdout = os.nuldev(), stderr = os.nuldev(), curdir = revenant})
                print("corpus_test.lua: OK")
                return true
            end,
            catch {
                function (errors)
                    print("corpus_test.lua FAIL: " .. tostring(errors))
                end
            }
        }
        if not ok then failed = failed + 1 end
    end
    if os.isfile(path.join(revenant, "tools", "found", "xmake.lua")) and os.isfile(path.join(revenant, "tests", "gen", "render_headers_test.lua")) then
        local found = path.join(revenant, "tools", "found")
        local built = try {
            function ()
                os.execv(os.programfile(), {"f", "-P", found, "-y"}, {stdout = os.nuldev(), stderr = os.nuldev(), curdir = revenant})
                os.execv(os.programfile(), {"-P", found}, {stdout = os.nuldev(), stderr = os.nuldev(), curdir = revenant})
                return true
            end,
            catch {
                function (errors)
                    print("tools/found build FAIL: " .. tostring(errors))
                end
            }
        }
        if not built then failed = failed + 1 end
    end
    for _, name in ipairs({"gen_test", "headers_test", "members_test", "trace_test", "doc_test", "scope_test", "protocols_test",
                           "atomic_test", "ir_failure_test", "ir_identity_test", "record_test", "clean_checkout_test",
                           "targets_test", "host_json_test", "stream_test", "protocol_set_test", "removed_ceiling_test",
                           "snapshot_pins_test", "input_test", "render_test",
                           "render_headers_test",
                           "swift_model_test", "swift_render_test", "swift_roundtrip_test",
                           "sdk_test", "sdk_cmd_test", "literal_test",
                           "surface_test", "swift_interface_test", "swift_match_test",
                           "ledger_test",
                           "worklist_test",
                           "verify_test",
                           "target_availability_test", "port_headers_test",
                           "measured_test",
                           "functions_test", "usr_include_test", "probe_test",
                           "swift_name_render_test", "reexport_import_test", "usr_headers_test", "vfs_overlay_test"}) do
        local suite = path.join(revenant, "tests", "gen", name .. ".lua")
        if os.isfile(suite) then
            local ok = try {
                function ()
                    os.execv(os.programfile(), {"l", suite}, {stdout = os.nuldev(), stderr = os.nuldev(), curdir = revenant})
                    print(name .. ": OK")
                    return true
                end,
                catch {
                    function (errors)
                        print(name .. " FAIL: " .. tostring(errors))
                    end
                }
            }
            if not ok then failed = failed + 1 end
        end
    end
    if failed > 0 then
        print("light guard: " .. failed .. " failure(s)")
        os.exit(1)
    end
end
