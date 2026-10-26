function failures(opt)
    local stubs = import("apple.sdkstubs", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local function expect(what, got, wanted)
        if got ~= wanted then
            table.insert(found, string.format("%s was %s, not %s", what, tostring(got), tostring(wanted)))
        end
    end

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

    local target = documents[1]
    local added = stubs.add_markers(target, {{archs = {"armv7", "armv7s", "arm64e"}, tokens = {"$ld$hide$os6.1$_a", "$ld$hide$os6.1$_b"}}})
    local wanted = "exports:\n  - targets: [ armv7-ios, armv7s-ios ]\n    symbols: [ '$ld$hide$os6.1$_a', '$ld$hide$os6.1$_b' ]\n  - targets:         [ armv7-ios, armv7s-ios ]\n"
    expect("markers added to a tbd 4 document", added:find(wanted, 1, true) and "as wanted" or added, "as wanted")
    expect("what is left of the document", added:gsub("  %- targets: %[ armv7%-ios, armv7s%-ios %]\n    symbols: %[[^\n]*\n", ""), target)
    expect("a marker already there is not added again", stubs.add_markers(added, {{archs = {"armv7"}, tokens = {"$ld$hide$os6.1$_a"}}}), added)
    expect("architectures the document lacks", stubs.add_markers(target, {{archs = {"i386"}, tokens = {"$ld$hide$os6.1$_a"}}}), target)
    local hidden = stubs.read(added)
    expect("a document read again after adding", #stubs.markers(hidden), 2)

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

    local bare = "--- !tapi-tbd\ntbd-version:     4\ntargets:         [ armv7-ios, arm64-ios ]\ninstall-name:    '/usr/lib/libx.dylib'\nreexported-libraries:\n  - targets:         [ armv7-ios ]\n    libraries:       [ '/usr/lib/liby.dylib' ]\n...\n"
    local grown = stubs.add_markers(bare, {{archs = {"armv7"}, tokens = {"$ld$hide$os6.1$_a"}}})
    expect("markers in a document with no exports", grown, bare:gsub("%.%.%.\n$", "") .. "exports:\n  - targets: [ armv7-ios ]\n    symbols: [ '$ld$hide$os6.1$_a' ]\n...\n")

    local versions = {"3.0", "5.0", "6.0", "6.1", "7.0"}
    expect("hides below a release", table.concat(stubs.hides("_s", "6.1.3", versions), " "), "$ld$hide$os3.0$_s $ld$hide$os5.0$_s $ld$hide$os6.0$_s")
    expect("hides of a symbol no held release exports", #stubs.hides("_s", nil, versions), 5)
    expect("nothing hidden from the release it arrived in", #stubs.hides("_s", "3.0", versions), 0)

    local table_of = stubs.releases("# comment\n_new\t6.0\n_newest\t-\n")
    expect("the table of first releases", tostring(table_of._new) .. " " .. tostring(table_of._newest), "6.0 false")
    local wanted_groups = stubs.derived(doc3, {___bswapdi2 = "5.0", ___unrelated = "5.0"}, {"3.0", "4.3", "5.0"})
    expect("derived groups", #wanted_groups, 1)
    expect("derived architectures", table.concat(wanted_groups[1].archs, ","), "armv7,armv7s")
    expect("derived markers", table.concat(wanted_groups[1].tokens, " "), "$ld$hide$os3.0$___bswapdi2 $ld$hide$os4.3$___bswapdi2")

    local groups = stubs.group(stubs.markers(second))
    expect("carried groups", #groups, 1)
    expect("carried tokens", #groups[1].tokens, 2)

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

    local ios6 = stubs.inventory("# held by iOS 6\n/usr/lib/libP.dylib\n")
    expect("a comment of the inventory is no install name", ios6["# held by iOS 6"] and "listed" or "not", "not")
    expect("an install name of the inventory is listed", ios6["/usr/lib/libP.dylib"] and "listed" or "not", "listed")

    local folder = import("fixtures").scratch()
    local umbrella = table.concat({
        "--- !tapi-tbd-v3\n", "archs:                 [ armv7, armv7s, arm64, arm64e ]\n", "platform:              ios\n",
        "install-name:          /usr/lib/libU.dylib\n", "exports:\n",
        "  - archs:                [ armv7, armv7s, arm64, arm64e ]\n",
        "    re-exports:           [ /usr/lib/libM.dylib, /usr/lib/libP.dylib, /usr/lib/libN.dylib ]\n",
        "    symbols:              [ _own ]\n",
        "  - archs:                [ armv7 ]\n", "    re-exports:           [ /usr/lib/libN.dylib ]\n", "...\n"})
    local library = table.concat({
        "--- !tapi-tbd-v3\n", "archs:                 [ armv7, armv7s, arm64, arm64e ]\n", "platform:              ios\n",
        "install-name:          /usr/lib/libM.dylib\n", "exports:\n",
        "  - archs:                [ armv7, armv7s, arm64, arm64e ]\n",
        "    symbols:              [ _m_func, _m_shared ]\n",
        "    weak-def-symbols:     [ _m_weak ]\n",
        "  - archs:                [ arm64 ]\n", "    objc-classes:         [ MClass ]\n", "...\n"})
    local legacy = table.concat({
        "--- !tapi-tbd\n", "tbd-version:     4\n", "targets:         [ armv7-ios, arm64-ios ]\n",
        "install-name:    '/usr/lib/libV.dylib'\n", "reexported-libraries:\n",
        "  - targets:         [ armv7-ios ]\n", "    libraries:       [ '/usr/lib/libM.dylib' ]\n",
        "exports:\n", "  - targets:         [ armv7-ios, arm64-ios ]\n", "    symbols:         [ _v ]\n", "...\n"})
    io.writefile(path.join(folder, "U.tbd"), umbrella)
    io.writefile(path.join(folder, "M.tbd"), library)
    io.writefile(path.join(folder, "V.tbd"), legacy)
    local report = stubs.fold_reexports({path.join(folder, "U.tbd"), path.join(folder, "M.tbd"), path.join(folder, "V.tbd")}, ios6)
    local folded = stubs.read(io.readfile(path.join(folder, "U.tbd")))
    local exported = stubs.exported(folded)
    expect("a folded symbol exports from the umbrella for armv7", exported._m_func and exported._m_func.armv7 or false, true)
    expect("a folded weak definition exports from the umbrella", exported._m_weak and exported._m_weak.armv7 or false, true)
    expect("a folded class exports from the umbrella for arm64", exported.MClass and exported.MClass.arm64 or false, true)
    expect("a folded class is not exported for armv7, where the library had none", exported.MClass and exported.MClass.armv7 or false, false)
    expect("the umbrella's own export is kept", exported._own and exported._own.armv7 or false, true)
    local kept = {}
    for _, entry in ipairs(folded.reexports) do
        table.insert(kept, table.concat(entry.libraries, ","))
    end
    expect("the re-exports left are those of libraries iOS 6 has, and of one with no stub", table.concat(kept, ";"), "/usr/lib/libP.dylib,/usr/lib/libN.dylib;/usr/lib/libN.dylib")
    expect("a library with no stub in the SDK is kept and reported", report.lost[1][1] .. " " .. report.lost[1][2] .. " " .. report.lost[1][3],
           "/usr/lib/libU.dylib /usr/lib/libN.dylib the SDK has no stub for it to fold")
    expect("the folded umbrellas", #report.folded, 2)
    local v4 = stubs.read(io.readfile(path.join(folder, "V.tbd")))
    local v4_exported = stubs.exported(v4)
    expect("a v4 umbrella takes the folded symbol for armv7", v4_exported._m_func and v4_exported._m_func.armv7 or false, true)
    expect("a v4 umbrella loses its re-export section once it is empty", #v4.reexports, 0)
    expect("a v4 umbrella keeps its own export for both", v4_exported._v and v4_exported._v.arm64 or false, true)
    os.tryrm(folder)
    return found
end
