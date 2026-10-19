function main(release, band, ...)
    local binaries = {...}
    assert(release and band and #binaries > 0, "usage: xmake l check-app.lua <release> <band folder> <binary>...")
    local dyld = import("apple.dyld", {rootdir = path.join(os.getenv("CHARON_ROOT"), "modules"), anonymous = true})
    local cache = path.join(os.getenv("HOME"), ".charon", "dyld", release, "dyld_shared_cache_armv7")
    local provided = {}
    for _, library in ipairs(os.files(path.join(band, "*.dylib"))) do
        table.insert(provided, library)
    end
    local checked = table.join(binaries, provided)
    local missing, _, _, dangling = dyld.missing_imports(cache, checked)
    local exported = {}
    for _, library in ipairs(provided) do
        for symbol in os.iorunv("xcrun", {"nm", "-gU", library}):gmatch("[^\n]+ [TDSsdt] (_[^%s]+)") do
            exported[symbol] = true
        end
    end
    local linkage, absent, skipped = {}, {}, {}
    for _, entry in ipairs(missing) do
        if entry[2]:find("^%(no slice") then
            table.insert(skipped, entry[1])
            goto continue
        end
        local line = string.format("%s  %s", path.filename(entry[1]), entry[2]:gsub("%s*%(.*$", ""))
        if exported[entry[2]:match("^(%S+)")] then
            table.insert(linkage, line)
        else
            table.insert(absent, line)
        end
        ::continue::
    end
    if #skipped > 0 then
        print("NOT ANALYSED: %d binaries have no armv7 slice an iOS %s device loads, so nothing below says anything about them", #skipped, release)
        print("(an arm64-only application has to be lifted to armv7 before it can be checked)")
        for _, name in ipairs(skipped) do
            print("  " .. name)
        end
        print("")
    end
    print("%d binaries checked against the shared cache of iOS %s and the libraries in %s", #binaries - #skipped, release, band)
    print("")
    print("carried by the backports, and unresolved only because the stock library is bound first (%d):", #linkage)
    for _, line in ipairs(linkage) do
        print("  " .. line)
    end
    print("")
    print("not carried by the backports and not in the release (%d):", #absent)
    for _, line in ipairs(absent) do
        print("  " .. line)
    end
    local weak_carried, weak_absent = {}, {}
    for _, entry in ipairs(dangling) do
        local name = entry[2]
        if entry[1] ~= nil and not path.filename(entry[1]):find("Backports") then
            table.insert(exported[name] and weak_carried or weak_absent, string.format("%s  %s", path.filename(entry[1]), name))
        end
    end
    print("")
    print("weakly imported, NULL on the release, and carried by the backports (%d):", #weak_carried)
    for _, line in ipairs(weak_carried) do
        print("  " .. line)
    end
    print("")
    print("weakly imported, NULL on the release, and not carried (%d):", #weak_absent)
    for _, line in ipairs(weak_absent) do
        print("  " .. line)
    end
end
