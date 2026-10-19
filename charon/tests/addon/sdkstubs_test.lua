-- The markers a stub carries and the ones the iphoneos-sdk package puts into an SDK whose stubs carry none: read from tbd 4
-- and 3, put where the linker looks, and never twice.
function failures(opt)
    local stubs = import("apple.sdkstubs", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local function expect(what, got, wanted)
        if got ~= wanted then
            table.insert(found, string.format("%s was %s, not %s", what, tostring(got), tostring(wanted)))
        end
    end

    -- tbd 4, several documents in one file, with a marker in the second and a symbol-level reexports section
    local v4 = table.concat({
        "--- !tapi-tbd\n", "tbd-version:     4\n", "targets:         [ armv7-ios, armv7s-ios, arm64-ios ]\n",
        "install-name:    '/usr/lib/libSystem.B.dylib'\n", "reexported-libraries:\n",
        "  - targets:         [ armv7-ios ]\n", "    libraries:       [ '/usr/lib/system/libunwind.dylib' ]\n",
        "exports:\n", "  - targets:         [ armv7-ios, armv7s-ios ]\n", "    symbols:         [ _open ]\n",
        "reexports:\n", "  - targets:         [ armv7-ios ]\n", "    symbols:         [ _memcpy ]\n",
        "--- !tapi-tbd\n", "tbd-version:     4\n", "targets:         [ armv7-ios, armv7s-ios, arm64-ios ]\n",
        "install-name:    '/usr/lib/system/libunwind.dylib'\n", "exports:\n",
        "  - targets:         [ armv7-ios, armv7s-ios ]\n",
        "    symbols:         [ '$ld$hide$os3.0$__Unwind_GetIPInfo', '$ld$hide$os4.3$__Unwind_GetIPInfo', __Unwind_GetIPInfo,\n",
        "                       __Unwind_Backtrace ]\n",
        "undefineds:\n", "  - targets:         [ armv7-ios ]\n", "    symbols:         [ _abort ]\n", "...\n"})
    local documents = stubs.documents(v4)
    expect("documents of a tbd 4 file", #documents, 2)
    expect("documents put back together", table.concat(documents), v4)
    local first, second = stubs.read(documents[1]), stubs.read(documents[2])
    expect("install name", first.install, "/usr/lib/libSystem.B.dylib")
    expect("a symbol of exports and one of reexports", (stubs.exported(first)._open and stubs.exported(first)._memcpy) and "both" or "not both", "both")
    expect("an undefined symbol is not exported", stubs.exported(second)._abort, nil)
    expect("a marker is no exported symbol", stubs.exported(second)["$ld$hide$os3.0$__Unwind_GetIPInfo"], nil)
    local found_markers = stubs.markers(second)
    expect("markers of libunwind", #found_markers, 2)
    expect("a marker's kind and release", found_markers[2].kind .. " " .. found_markers[2].version .. " " .. table.concat(found_markers[2].archs, ","),
           "hide 4.3 armv7,armv7s")
    expect("the releases hidden", table.concat(stubs.hidden_releases(second), " "), "3.0 4.3")
    expect("libSystem's own", (stubs.in_libsystem(first.install) and stubs.in_libsystem(second.install) and not stubs.in_libsystem("/usr/lib/libobjc.A.dylib"))
           and "yes" or "no", "yes")

    -- adding: the architectures the document has, each marker once, at the top of the exports; nothing else moves
    local target = documents[1]
    local added = stubs.add_markers(target, {{archs = {"armv7", "armv7s", "arm64e"}, tokens = {"$ld$hide$os6.1$_a", "$ld$hide$os6.1$_b"}}})
    local wanted = "exports:\n  - targets: [ armv7-ios, armv7s-ios ]\n    symbols: [ '$ld$hide$os6.1$_a', '$ld$hide$os6.1$_b' ]\n  - targets:         [ armv7-ios, armv7s-ios ]\n"
    expect("markers added to a tbd 4 document", added:find(wanted, 1, true) and "as wanted" or added, "as wanted")
    expect("what is left of the document", added:gsub("  %- targets: %[ armv7%-ios, armv7s%-ios %]\n    symbols: %[[^\n]*\n", ""), target)
    expect("a marker already there is not added again", stubs.add_markers(added, {{archs = {"armv7"}, tokens = {"$ld$hide$os6.1$_a"}}}), added)
    expect("architectures the document lacks", stubs.add_markers(target, {{archs = {"i386"}, tokens = {"$ld$hide$os6.1$_a"}}}), target)
    local hidden = stubs.read(added)
    expect("a document read again after adding", #stubs.markers(hidden), 2)

    -- tbd 3: archs, no -ios, one document
    local v3 = table.concat({
        "--- !tapi-tbd-v3\n", "archs:                 [ armv7, armv7s, arm64, arm64e ]\n", "platform:              ios\n",
        "install-name:          /usr/lib/system/libcompiler_rt.dylib\n", "exports:\n",
        "  - archs:                [ armv7, armv7s, arm64, arm64e ]\n", "    symbols:              [ ___bswapdi2, ___floatundidf ]\n", "...\n"})
    local doc3 = stubs.read(v3)
    expect("install name of a tbd 3 document", doc3.install, "/usr/lib/system/libcompiler_rt.dylib")
    expect("architectures of a tbd 3 document", table.concat(doc3.archs, ","), "armv7,armv7s,arm64,arm64e")
    local added3 = stubs.add_markers(v3, {{archs = {"armv7", "armv7s"}, tokens = {"$ld$hide$os5.0$___bswapdi2"}}})
    expect("markers added to a tbd 3 document", added3:find("exports:\n  - archs: [ armv7, armv7s ]\n    symbols: [ '$ld$hide$os5.0$___bswapdi2' ]\n  - archs:", 1, true) and "as wanted" or added3, "as wanted")
    local many = {}
    for n = 1, 30 do
        table.insert(many, "$ld$hide$os4.3$_symbol_number_" .. n)
    end
    local wrapped = stubs.add_markers(v3, {{archs = {"armv7"}, tokens = many}})
    expect("a long list wraps", #wrapped:match("    symbols: [^\n]*\n") < 130 and #wrapped:match("\n[^\n]*_symbol_number_30'") > 0, true)

    -- a document that re-exports whole libraries and exports nothing gets the section, before its end
    local bare = "--- !tapi-tbd\ntbd-version:     4\ntargets:         [ armv7-ios, arm64-ios ]\ninstall-name:    '/usr/lib/libx.dylib'\nreexported-libraries:\n  - targets:         [ armv7-ios ]\n    libraries:       [ '/usr/lib/liby.dylib' ]\n...\n"
    local grown = stubs.add_markers(bare, {{archs = {"armv7"}, tokens = {"$ld$hide$os6.1$_a"}}})
    expect("markers in a document with no exports", grown, bare:gsub("%.%.%.\n$", "") .. "exports:\n  - targets: [ armv7-ios ]\n    symbols: [ '$ld$hide$os6.1$_a' ]\n...\n")

    -- a marker names one release, and a release is (major, minor): 6.1 for 6.1.3, so a symbol a 6.1.3 device has is not hidden at 6.1
    local versions = {"3.0", "5.0", "6.0", "6.1", "7.0"}
    expect("hides below a release", table.concat(stubs.hides("_s", "6.1.3", versions), " "), "$ld$hide$os3.0$_s $ld$hide$os5.0$_s $ld$hide$os6.0$_s")
    expect("hides of a symbol no held release exports", #stubs.hides("_s", nil, versions), 5)
    expect("nothing hidden from the release it arrived in", #stubs.hides("_s", "3.0", versions), 0)

    -- what the package derives: only the symbols the table names, for armv7 and armv7s
    local table_of = stubs.releases("# comment\n_new\t6.0\n_newest\t-\n")
    expect("the table of first releases", tostring(table_of._new) .. " " .. tostring(table_of._newest), "6.0 false")
    local wanted_groups = stubs.derived(doc3, {___bswapdi2 = "5.0", ___unrelated = "5.0"}, {"3.0", "4.3", "5.0"})
    expect("derived groups", #wanted_groups, 1)
    expect("derived architectures", table.concat(wanted_groups[1].archs, ","), "armv7,armv7s")
    expect("derived markers", table.concat(wanted_groups[1].tokens, " "), "$ld$hide$os3.0$___bswapdi2 $ld$hide$os4.3$___bswapdi2")

    -- a document's markers carried to another: grouped by architectures, in the order met
    local groups = stubs.group(stubs.markers(second))
    expect("carried groups", #groups, 1)
    expect("carried tokens", #groups[1].tokens, 2)

    -- a newer SDK's tbd (v3, no armv7-only symbols at all: no device runs 26.2 on 32-bit) beside the older one
    -- (v4, still names them for armv7/armv7s): what it dropped, and adding it back as plain exports, not markers
    local old_unwind = table.concat({
        "--- !tapi-tbd\n", "tbd-version:     4\n", "targets:         [ armv7-ios, armv7s-ios, arm64-ios ]\n",
        "install-name:    '/usr/lib/system/libunwind.dylib'\n", "exports:\n",
        "  - targets:         [ armv7-ios, armv7s-ios ]\n",
        "    symbols:         [ __Unwind_SjLj_Register, __Unwind_SjLj_Resume ]\n",
        "  - targets:         [ armv7-ios, armv7s-ios, arm64-ios ]\n",
        "    symbols:         [ __Unwind_Backtrace ]\n",
        "  - targets:         [ armv7-ios ]\n",
        "    weak-symbols:    [ __Unwind_Rarely ]\n", "...\n"})
    local new_unwind = table.concat({
        "--- !tapi-tbd-v3\n", "archs:                 [ armv7, armv7s, arm64, arm64e ]\n", "platform:              ios\n",
        "install-name:          /usr/lib/system/libunwind.dylib\n", "exports:\n",
        "  - archs:                [ armv7, armv7s, arm64, arm64e ]\n",
        "    symbols:              [ __Unwind_Backtrace ]\n", "...\n"})
    local dropped = stubs.dropped(stubs.read(old_unwind), stubs.read(new_unwind))
    expect("dropped groups (symbols, weak-symbols)", #dropped, 2)
    local by_list = {}
    for _, g in ipairs(dropped) do by_list[g.list] = g end
    expect("dropped plain symbols", table.concat(by_list.symbols.tokens, " "), "__Unwind_SjLj_Register __Unwind_SjLj_Resume")
    expect("dropped symbols' architectures", table.concat(by_list.symbols.archs, ","), "armv7,armv7s")
    expect("dropped weak symbols", table.concat(by_list["weak-symbols"].tokens, " "), "__Unwind_Rarely")
    expect("what a shared, still-exported symbol is not", #stubs.dropped(stubs.read(old_unwind), stubs.read(old_unwind)), 0)
    local restored = stubs.add_symbols(new_unwind, dropped)
    local restored_doc = stubs.read(restored)
    local exported = stubs.exported(restored_doc)
    expect("a restored symbol exports for armv7", exported.__Unwind_SjLj_Register and exported.__Unwind_SjLj_Register.armv7 or false, true)
    expect("a restored symbol does not export for arm64 (the new stub never had it there)", exported.__Unwind_SjLj_Register and exported.__Unwind_SjLj_Register.arm64 or false, false)
    expect("the original export untouched", exported.__Unwind_Backtrace and exported.__Unwind_Backtrace.arm64 or false, true)
    expect("restoring the same drop twice adds nothing new", stubs.add_symbols(restored, dropped), restored)

    -- a symbol the new stub still lists, just regrouped under an architecture the old one never paired it with alone
    -- (arm64 only, here) - not dropped, whatever architecture carries it now: restoring it would assert something no
    -- SDK measurement backs, the exact gap the review of this series found the first version of dropped() left open
    local new_unwind_regrouped = table.concat({
        "--- !tapi-tbd-v3\n", "archs:                 [ armv7, armv7s, arm64, arm64e ]\n", "platform:              ios\n",
        "install-name:          /usr/lib/system/libunwind.dylib\n", "exports:\n",
        "  - archs:                [ armv7, armv7s, arm64, arm64e ]\n",
        "    symbols:              [ __Unwind_Backtrace ]\n",
        "  - archs:                [ arm64, arm64e ]\n",
        "    symbols:              [ __Unwind_SjLj_Register ]\n", "...\n"})
    local dropped_regrouped = stubs.dropped(stubs.read(old_unwind), stubs.read(new_unwind_regrouped))
    local regrouped_by_list = {}
    for _, g in ipairs(dropped_regrouped) do regrouped_by_list[g.list] = g end
    expect("a symbol regrouped under arm64 only is not counted as dropped",
           table.concat((regrouped_by_list.symbols or {tokens = {}}).tokens, " "), "__Unwind_SjLj_Resume")
    return found
end
