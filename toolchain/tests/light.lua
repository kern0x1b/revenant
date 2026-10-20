import("async.runjobs")

local function child(name, argv, curdir)
    local scratch = path.join(os.getenv("HOME"), ".revenant", "cache", name)
    os.tryrm(scratch)
    os.mkdir(scratch)
    local log = path.join(scratch, "output.log")
    local status = os.execv(os.programfile(), argv, {stdout = log, stderr = log, curdir = curdir, try = true})
    return {status = status, log = log, scratch = scratch}
end

local function report(label, result)
    if result.status == 0 then
        print(label .. ": OK")
        os.tryrm(result.scratch)
        return 0
    end
    print(label .. " FAIL: exit " .. result.status .. ", its output follows (kept in " .. result.scratch .. ")")
    print(io.readfile(result.log))
    return 1
end

local addon_suites = {"descriptions_test", "checkout_test", "registry_test", "dependency_test", "swift_rule_test",
                      "workspace_test", "revenant_index_test", "lock_test", "cache_sweep_test", "protocol_headers_test",
                      "matter_closure_test", "sdk_verbatim_test", "locale_order_test"}

local gen_suites = {"gen_test", "headers_test", "members_test", "trace_test", "doc_test", "scope_test", "protocols_test",
                    "atomic_test", "ir_failure_test", "ir_identity_test", "record_test", "clean_checkout_test",
                    "targets_test", "host_json_test", "stream_test", "protocol_set_test", "removed_ceiling_test",
                    "snapshot_pins_test", "input_test", "render_test", "render_headers_test", "swift_model_test",
                    "swift_render_test", "swift_roundtrip_test", "sdk_test", "sdk_cmd_test", "literal_test",
                    "surface_test", "swift_interface_test", "swift_match_test", "ledger_test", "worklist_test",
                    "verify_test", "target_availability_test", "port_headers_test", "measured_test", "functions_test",
                    "usr_include_test", "probe_test", "swift_name_render_test", "reexport_import_test",
                    "usr_headers_test", "vfs_overlay_test"}

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
    local found = path.join(revenant, "tools", "found")
    local built = child("found-configure", {"f", "-P", found, "-y"}, revenant)
    if built.status == 0 then
        built = child("found-build", {"-P", found}, revenant)
    end
    failed = failed + report("tools/found build", built)
    local skip = {}
    for name in (os.getenv("LIGHT_SKIP") or ""):gmatch("[^,%s]+") do
        skip[name] = true
    end
    local suites = {}
    for _, name in ipairs(gen_suites) do
        table.insert(suites, {name = name, file = path.join(revenant, "tests", "gen", name .. ".lua")})
    end
    table.insert(suites, {name = "corpus_test", file = path.join(revenant, "tests", "corpus", "corpus_test.lua")})
    local jobs = {}
    for _, suite in ipairs(suites) do
        if skip[suite.name] then
            print(suite.name .. ": SKIPPED by LIGHT_SKIP")
        else
            table.insert(jobs, suite)
        end
    end
    local results = {}
    runjobs("light", function (index)
        local suite = jobs[index]
        results[index] = child(suite.name, {"l", suite.file}, revenant)
    end, {total = #jobs, comax = os.cpuinfo().ncpu})
    for index, suite in ipairs(jobs) do
        failed = failed + report(suite.name, results[index])
    end
    if failed > 0 then
        print("light guard: " .. failed .. " failure(s)")
        os.exit(1)
    end
end
