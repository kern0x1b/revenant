-- The symbol gate judges each new import by the library its binary names. The fixtures are
-- armv7 Mach-O files linked here with the ld64 package, and a cache folder that stands in for
-- the iOS 6.0 libraries. Run it with the linker of the revenant@ld64 package:
--   REVENANT_LD64=<ld64>/bin/ld ./xmakew l frameworks/WebKit/tests/gate/symbols_test.lua
local TESTS = path.absolute(os.scriptdir())
local MODULES = path.absolute(path.join(TESTS, "..", "..", "src", "modules"))
local SYSTEM_STUB = [[--- !tapi-tbd
tbd-version: 4
targets: [ armv7-ios, arm64-ios ]
install-name: '/usr/lib/libSystem.B.dylib'
exports:
  - targets: [ armv7-ios, arm64-ios ]
    symbols: [ dyld_stub_binder ]
...
]]

local function compile(folder, name, source)
    io.writefile(path.join(folder, name .. ".c"), source)
    os.vrunv("xcrun", {"clang", "-target", "armv7-apple-ios6.0", "-Wno-incompatible-sysroot", "-c", name .. ".c", "-o", name .. ".o"}, {curdir = folder})
    return name .. ".o"
end

local function link(work, ld, folder, output, install, objects, flags)
    local argv = {"-dylib", "-arch", "armv7", "-iphoneos_version_min", "6.0", "-install_name", install}
    table.join2(argv, flags or {})
    table.join2(argv, {"-L" .. path.join(work, "sdk"), "-lSystem"})
    table.join2(argv, objects)
    table.join2(argv, {"-o", output})
    os.vrunv(ld, argv, {curdir = folder})
    return path.join(folder, output)
end

local function library(work, ld, folder, name, install, source, flags)
    return link(work, ld, folder, path.filename(install), install, {compile(folder, name, source)}, flags)
end

local function verdict_of(verdicts, binary, name)
    for _, verdict in ipairs(verdicts[binary]) do
        if verdict.name == name then
            return verdict
        end
    end
    raise("the judgement of %s has no verdict for %s", binary, name)
end

local function contains(text, part)
    return text:find(part, 1, true) ~= nil
end

function main()
    local ld = os.getenv("REVENANT_LD64")
    assert(ld and os.isfile(ld), "set REVENANT_LD64 to the bin/ld of the revenant@ld64 package, which ./xmakew require -P . revenant@ld64 installs")
    local work = path.join(os.tmpdir(), "revenant-symbols-test")
    os.tryrm(work)
    for _, folder in ipairs({"sdk", "link", "probes", "build", path.join("cache", "libraries_armv7")}) do
        os.mkdir(path.join(work, folder))
    end
    io.writefile(path.join(work, "sdk", "libSystem.tbd"), SYSTEM_STUB)
    local links = path.join(work, "link")
    local cache = path.join(work, "cache", "libraries_armv7")

    library(work, ld, links, "gcc", "/usr/lib/libgcc_s.1.dylib", "int __ashldi3(void) { return 1; }\nint __clear_cache_probe(void) { return 2; }\n")
    library(work, ld, links, "a", "/usr/lib/libA.dylib", "int wrong_sym(void) { return 3; }\n")
    library(work, ld, links, "gone", "/usr/lib/libgone.dylib", "int gone_sym(void) { return 4; }\n")
    library(work, ld, cache, "gcc", "/usr/lib/libgcc_s.1.dylib", "int __ashldi3(void) { return 1; }\n")
    library(work, ld, cache, "a", "/usr/lib/libA.dylib", "int other_sym(void) { return 5; }\n")
    library(work, ld, cache, "b", "/usr/lib/libB.dylib", "int wrong_sym(void) { return 6; }\n")
    local link_flags = {"-L" .. links, "-lgcc_s.1", "-la", "-lgone"}
    local probe = library(work, ld, path.join(work, "probes"), "probe", "/usr/lib/libprobe.dylib",
        "int __ashldi3(void);\nint __clear_cache_probe(void);\nint wrong_sym(void);\nint gone_sym(void);\n"
        .. "int use(void) { return __ashldi3() + __clear_cache_probe() + wrong_sym() + gone_sym(); }\n", link_flags)
    local accepted = library(work, ld, path.join(work, "probes"), "accepted", "/usr/lib/libaccepted.dylib",
        "int __ashldi3(void);\nint use(void) { return __ashldi3(); }\n", {"-L" .. links, "-lgcc_s.1"})
    local flat = library(work, ld, path.join(work, "probes"), "flat", "/usr/lib/libflat.dylib",
        "int __ashldi3(void);\nint use(void) { return __ashldi3(); }\n", {"-L" .. links, "-lgcc_s.1", "-flat_namespace", "-undefined", "suppress"})
    library(work, ld, links, "cxx", "@rpath/libc++.1.dylib", "int cxx_exported(void) { return 7; }\nint cxx_absent(void) { return 8; }\n")
    library(work, ld, links, "unk", "@rpath/libunk.dylib", "int unk_sym(void) { return 9; }\n")
    library(work, ld, cache, "cxx", "/usr/lib/libc++.1.dylib", "int cxx_exported(void) { return 10; }\n")
    local cxx_probe = library(work, ld, path.join(work, "probes"), "cxxprobe", "/usr/lib/libcxxprobe.dylib",
        "int cxx_exported(void);\nint cxx_absent(void);\nint unk_sym(void);\nint use(void) { return cxx_exported() + cxx_absent() + unk_sym(); }\n",
        {"-L" .. links, "-lc++.1", "-lunk"})

    local symbols = import("symbols", {rootdir = MODULES, anonymous = true})
    local dyld = import("@addon.revenant.apple.dyld", {anonymous = true})
    local verdicts = dyld.import_verdicts(cache, {probe, flat})

    local ashl = verdict_of(verdicts, probe, "___ashldi3")
    assert(ashl.accepted and ashl.library == "/usr/lib/libgcc_s.1.dylib", "an import the named library exports is not accepted: " .. tostring(ashl.reason))
    local cleared = verdict_of(verdicts, probe, "___clear_cache_probe")
    assert(not cleared.accepted and contains(cleared.reason, "/usr/lib/libgcc_s.1.dylib") and contains(cleared.reason, "does not export"), "an import the named library does not export is accepted: " .. tostring(cleared.reason))
    local wrong = verdict_of(verdicts, probe, "_wrong_sym")
    assert(not wrong.accepted and contains(wrong.reason, "/usr/lib/libA.dylib") and contains(wrong.reason, "/usr/lib/libB.dylib"), "a wrong ordinal is not named as the wrong library: " .. tostring(wrong.reason))
    local gone = verdict_of(verdicts, probe, "_gone_sym")
    assert(not gone.accepted and contains(gone.reason, "does not hold"), "an import from a library the cache does not hold is accepted: " .. tostring(gone.reason))
    local flat_verdict = verdict_of(verdicts, flat, "___ashldi3")
    assert(not flat_verdict.accepted and contains(flat_verdict.reason, "flat namespace"), "a flat-namespace import is accepted: " .. tostring(flat_verdict.reason))
    local cxx_verdicts = dyld.import_verdicts(cache, {cxx_probe})
    local cxx_exported_verdict = verdict_of(cxx_verdicts, cxx_probe, "_cxx_exported")
    assert(cxx_exported_verdict.accepted and cxx_exported_verdict.library == "/usr/lib/libc++.1.dylib", "an @rpath libc++ import the cache's libc++ exports is not accepted: " .. tostring(cxx_exported_verdict.reason))
    local cxx_absent_verdict = verdict_of(cxx_verdicts, cxx_probe, "_cxx_absent")
    assert(not cxx_absent_verdict.accepted and contains(cxx_absent_verdict.reason, "/usr/lib/libc++.1.dylib") and contains(cxx_absent_verdict.reason, "@rpath/libc++.1.dylib"), "an @rpath libc++ import the cache's libc++ does not export is accepted: " .. tostring(cxx_absent_verdict.reason))
    local unknown_verdict = verdict_of(cxx_verdicts, cxx_probe, "_unk_sym")
    assert(not unknown_verdict.accepted and contains(unknown_verdict.reason, "does not hold") and contains(unknown_verdict.reason, "@rpath/libunk.dylib"), "an import from an @rpath library the cache does not hold is accepted: " .. tostring(unknown_verdict.reason))

    local function stage(binary)
        local build = path.join(work, "build", path.filename(binary) .. "-build")
        for _, framework in ipairs({"JavaScriptCore", "WebCore", "WebKitLegacy"}) do
            os.mkdir(path.join(build, framework .. ".framework"))
            os.cp(binary, path.join(build, framework .. ".framework", framework))
        end
        return build
    end

    local rejecting = stage(probe)
    local report = symbols.compare(rejecting, cache)
    assert(#report.accepted == 3 and #report.rejected == 9, string.format("the gate reports %d accepted and %d rejected, not 3 and 9", #report.accepted, #report.rejected))
    local rejected_entries = {}
    for _, item in ipairs(report.rejected) do
        rejected_entries[item.entry] = true
    end
    assert(rejected_entries["undefined JavaScriptCore ___clear_cache_probe"] and rejected_entries["undefined JavaScriptCore _wrong_sym"] and rejected_entries["undefined JavaScriptCore _gone_sym"], "the gate does not reject the three bad imports of JavaScriptCore")
    local raised
    try {
        function () symbols.verify(rejecting, cache) end,
        catch {
            function (err) raised = tostring(err) end
        }
    }
    assert(raised and contains(raised, "iOS 6.0 does not export"), "the gate passes a build with rejected imports: " .. tostring(raised))

    local passing = stage(accepted)
    local clean = symbols.compare(passing, cache)
    assert(#clean.rejected == 0 and #clean.accepted == 3, "a build whose only import the cache exports is not accepted")

    print(string.format("SYMBOLS_GATE_TEST passed (an exported import is accepted from its library, a missing export, a wrong ordinal, a library the cache does not hold and a flat-namespace import are rejected, and the gate names each one)"))
    os.tryrm(work)
end
