-- The light guard: charon's pure-Lua suites, no SDK, no device, no heavy job.
-- Usage: xmake l tests/light.lua [checkout]   (default: the charon this file is in)
-- Exits non-zero when any suite reports a failure, so a caller can gate on the exit code.
function main(checkout)
    local charon = checkout and path.absolute(checkout) or path.directory(os.scriptdir())
    local addon = path.join(charon, "tests", "addon")
    local modules = path.join(charon, "modules")
    local names = {"descriptions_test", "checkout_test", "registry_test", "dependency_test", "swift_rule_test"}
    -- lock_test arrives with a band's series and is not on main yet: run it only in a tree that has it
    if os.isfile(path.join(addon, "lock_test.lua")) then
        table.insert(names, "lock_test")
    end
    -- cache_sweep_test arrives with a band's series and is not on main yet: same guard as above
    if os.isfile(path.join(addon, "cache_sweep_test.lua")) then
        table.insert(names, "cache_sweep_test")
    end
    -- protocol_headers_test arrived with uikit-b-fin4: a registry row whose protocol no generated
    -- source can see is a source the 6.1.3 gate cannot compile, and nothing before the gate reads
    -- that header. Pure Lua, no clang, so it belongs here rather than in a gate suite.
    if os.isfile(path.join(addon, "protocol_headers_test.lua")) then
        table.insert(names, "protocol_headers_test")
    end
    -- matter_closure_test (v-matter12, v-matter13): pure Lua, fails when a generated Matter object is committed for a class
    -- the emit rule does not emit (facts/Matter/emit-closure.tsv: none is emitted) or when that table is stale; same guard.
    -- matter_skip_test was retired with the generated Matter family (v-matter13).
    if os.isfile(path.join(addon, "matter_closure_test.lua")) then
        table.insert(names, "matter_closure_test")
    end
    -- sdk_verbatim_test arrives with v-legal round 2 and is not on main yet: pure Lua over a committed fixture (a fake SDK
    -- header, a source that copies one of its comment lines and one that does not); the same guard as above
    if os.isfile(path.join(addon, "sdk_verbatim_test.lua")) then
        table.insert(names, "sdk_verbatim_test")
    end
    -- matter_objects_test arrives with v-matter11: pure Lua, fails when a committed generated Matter object implements a
    -- class the real stack (charon@matter) carries; the same guard as above
    if os.isfile(path.join(addon, "matter_objects_test.lua")) then
        table.insert(names, "matter_objects_test")
    end
    -- locale_order_test arrives with v-locale and is not on main yet: pure Lua, runs a probe in one process per locale and
    -- compares the outputs byte for byte (a string sort that follows the machine's locale is a determinism defect); same guard
    if os.isfile(path.join(addon, "locale_order_test.lua")) then
        table.insert(names, "locale_order_test")
    end
    -- digest_test is NOT run here: swift-runtime's digest.lua is stale on main, and rewriting it changes the build hash of
    -- the 16.4 SDK package (a reinstall of the SDK and a rebuild of libcxx and swift-runtime, measured 2026-10-12: the gate
    -- failed on a new empty sysroot). The refresh is its own heavy job, queued; add digest_test here when it has run.
    -- py_values_test (v-port-host-b): pure Lua, the Python value rules the host helpers replicate (float repr, the decoder's
    -- kinds, ==, round) against CPython's own answers; the same guard as above
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
    -- archive_language_test is pure Lua, has no failures() and raises on a defect: a library whose C archive a band
    -- with no .mm object would drop from the link (paid for by tail-a-fin: Security, micro-ecc). Run it where it exists.
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
    -- The Python corpus suite (tools/corpus/tests/test_corpus.py) is no longer run (owner, 2026-10-19: no Python in any
    -- form); the Lua suite below is its port and the corpus tools' control.
    -- corpus_test (v-port-corpus) is the Lua suite of the ported corpus tools; it runs in its own xmake process where it
    -- exists, and a non-zero exit is a failure.
    local corpus_lua_test = path.join(charon, "tools", "corpus", "tests", "corpus_test.lua")
    if os.isfile(corpus_lua_test) then
        local ok = try {
            function ()
                os.execv(os.programfile(), {"l", corpus_lua_test}, {stdout = os.nuldev(), stderr = os.nuldev(), curdir = charon})
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
    -- The declaration extractor (tools/found) is built in the checkout first: render_headers_test runs it on its own fixture
    -- SDK. xmake rebuilds it only when its source changed, so a built checkout pays one up-to-date check.
    if os.isfile(path.join(charon, "tools", "found", "xmake.lua")) and os.isfile(path.join(charon, "tests", "gen", "render_headers_test.lua")) then
        local found = path.join(charon, "tools", "found")
        local built = try {
            function ()
                os.execv(os.programfile(), {"f", "-P", found, "-y"}, {stdout = os.nuldev(), stderr = os.nuldev(), curdir = charon})
                os.execv(os.programfile(), {"-P", found}, {stdout = os.nuldev(), stderr = os.nuldev(), curdir = charon})
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
    -- tests/gen (the apple-backports generator, in Lua under xmake): each suite runs in its own xmake process, and a non-zero
    -- exit is a failure. trace_test calls the trace layer's stubs through the Objective-C runtime on a fixture framework (each
    -- log line once, each safe default, a generated class object); it needs the host clang only (no device, no heavy job).
    -- gen_test refuses a write on a no-op run and reads the real tree; it needs no SDK.
    -- protocols_test, atomic_test and ir_failure_test are pure Lua fixtures as well; parser_real_test needs the iOS SDK and runs in the
    -- full gate, not here.
    -- record_test (pinned refusal and --record) and clean_checkout_test (git archive HEAD, gen and check, nothing written outside .gen)
    -- are pure Lua fixtures too; clean_checkout_test runs the generator on a committed snapshot of the tree.
    for _, name in ipairs({"gen_test", "headers_test", "members_test", "trace_test", "doc_test", "scope_test", "protocols_test",
                           "atomic_test", "ir_failure_test", "ir_identity_test", "record_test", "clean_checkout_test",
                           "targets_test", "host_json_test", "stream_test", "protocol_set_test", "removed_ceiling_test",
                           "snapshot_pins_test", "input_test", "render_test",
                           -- render_headers_test (v-gen-headers) runs decls on its own fixture SDK: it needs tools/found built
                           -- in the checkout (xmake f -P tools/found -y && xmake -P tools/found).
                           "render_headers_test",
                           -- swift_model_test / swift_render_test / swift_roundtrip_test (v-gen-swiftcode): pure Lua with our
                           -- own fixture, no SDK.
                           "swift_model_test", "swift_render_test", "swift_roundtrip_test",
                           -- sdk_test / sdk_cmd_test (v-gen-sdk): the SDK's name and version from fixture SDKSettings files,
                           -- and the sdk command's step order and first-failure stop; literal_test: no generator step names a
                           -- release or a machine path. Guarded until v-gen-sdk is on every checkout this runs over.
                           "sdk_test", "sdk_cmd_test", "literal_test",
                           -- surface_test, swift_interface_test, swift_match_test (v-gen-surface2): the surface from the
                           -- model's shards, the Swift introductions read from the interfaces, the Swift key match.
                           "surface_test", "swift_interface_test", "swift_match_test",
                           -- ledger_test (v-gen-ledger): the 6.1.3 framework verdicts from the cache readers' output.
                           "ledger_test",
                           -- worklist_test (v-gen-sdk-render): the sdk run's work list per module from a fixture scope table.
                           "worklist_test",
                           -- verify_test (v-gen-verify): a difference the known table does not explain fails the verify run.
                           "verify_test",
                           -- target_availability_test / port_headers_test (v-lift-remove): the port's release lowers what the
                           -- registry implements, and the port's headers are a second output beside the faithful render.
                           "target_availability_test", "port_headers_test",
                           -- measured_test (v-clean-generated): the build-time objects tools/gen/measured.lua writes from
                           -- the committed measured tables.
                           "measured_test",
                           -- functions_test / usr_include_test / probe_test (v-clean-dead): suites of live generator steps
                           -- that no list ran.
                           "functions_test", "usr_include_test", "probe_test",
                           -- swift_name_render_test / reexport_import_test / usr_headers_test / vfs_overlay_test (v-gen-headers3):
                           -- the apinotes Swift names rendered, a private module's declarations imported through the public umbrella
                           -- that re-exports it, and the port headers' overlay; pure Lua fixtures.
                           "swift_name_render_test", "reexport_import_test", "usr_headers_test", "vfs_overlay_test"}) do
        local suite = path.join(charon, "tests", "gen", name .. ".lua")
        if os.isfile(suite) then
            local ok = try {
                function ()
                    os.execv(os.programfile(), {"l", suite}, {stdout = os.nuldev(), stderr = os.nuldev(), curdir = charon})
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
