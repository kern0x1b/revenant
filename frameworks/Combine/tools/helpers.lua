function locks(helpers, test, folder)
    os.tryrm(folder)
    os.mkdir(folder)
    local include = path.join(helpers, "include")
    local object = path.join(folder, "CombineHelpers.o")
    local binary = path.join(folder, "CombineHelpersTests")
    os.vrunv("xcrun", {"clang++", "-std=c++17", "-O1", "-I", include, "-c", path.join(helpers, "COpenCombineHelpers.cpp"), "-o", object})
    os.vrunv("xcrun", {"ar", "rcs", path.join(folder, "libCombineHelpers.a"), object})
    os.vrunv("xcrun", {"swiftc", "-O", "-I", include, "-L", folder, "-Xlinker", "-lc++", test, "-o", binary})
    local output = os.iorunv(binary)
    if not output:find("combinehelpers: every check held", 1, true) then
        raise("the helper's locks failed on the host:\n%s", output)
    end
    for line in output:gmatch("[^\n]+") do
        if line:startswith("FAIL") then
            raise("the helper's locks failed on the host:\n%s", output)
        end
    end
end

function autolink(install, probe, objectfile)
    local macho = import("@addon.revenant.apple.macho", {anonymous = true})
    for _, library in ipairs({"Combine", "CombineHelpers"}) do
        if table.contains(table.wrap(probe:get("links")), library) then
            raise("%s names -l%s, so the link does not show whether the objects record it", probe:name(), library)
        end
    end
    if probe:pkg("combine") then
        raise("%s takes the combine package, whose link list names the helper archive", probe:name())
    end
    if not os.isfile(objectfile) then
        raise("%s was not compiled: %s is missing", probe:name(), objectfile)
    end
    local recorded = {}
    for _, options in ipairs(macho.images(macho.read(objectfile))[1].linker_options) do
        if #options == 1 then
            recorded[options[1]] = true
        end
    end
    for _, library in ipairs({"-lCombine", "-lCombineHelpers"}) do
        if not recorded[library] then
            raise("the object of an importer of Combine records no %s, so a link that takes its archives from the objects leaves them out", library)
        end
    end
    if not os.isfile(path.join(install, "lib", "libCombineHelpers.a")) then
        raise("the combine package installs no libCombineHelpers.a in %s", path.join(install, "lib"))
    end
    local binary = probe:targetfile()
    if not os.isfile(binary) then
        raise("%s did not link: %s is missing", probe:name(), binary)
    end
    local undefined, defined = {}, {}
    for line in os.iorunv("nm", {"-u", binary}):gmatch("[^\n]+") do
        local name = line:match("^%s*(_opencombine_%S+)")
        if name then
            table.insert(undefined, name)
        end
    end
    for line in os.iorunv("nm", {"-g", binary}):gmatch("[^\n]+") do
        local name = line:match("^%x+ [Tt] (_opencombine_%S+)")
        if name then
            table.insert(defined, name)
        end
    end
    if #undefined > 0 then
        raise("%s links with %d undefined helper symbols: %s", probe:name(), #undefined, table.concat(undefined, " "))
    end
    if #defined == 0 then
        raise("%s defines no _opencombine_ symbol, so the helper archive was not linked", probe:name())
    end
end
