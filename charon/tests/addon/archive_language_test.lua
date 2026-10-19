-- archive_language_test.lua: is every library's static library reachable by a band that keeps no
-- C++ object?
--
-- `link()` used to link a library's archives only when the band had kept an Objective-C++ object,
-- because every archive in these packages was C++ and a C++ archive needs the C++ runtime. A C
-- archive is the case that rule gets wrong: charon-coding holds the secure coding and the copying
-- the Intents, IntentsUI and Accessibility classes share, and none of those libraries keeps a .mm
-- object in any band, so an unmarked archive entry would be dropped from every band and the classes
-- would be built with no implementation behind them - which is what the link said, on
-- `_charon_intents_decode` referenced from -[AXBrailleTable initWithCoder:].
--
-- So an archive entry may say `c = true`, and this test fails on any library whose archives cannot
-- be reached that way: a band keeps the library's objects, so the link must keep the library's
-- archives too, whatever language the band's objects are written in.

function main()
    local root = os.scriptdir() .. "/../.."
    -- Loaded the way backports_test.lua loads it: as a module of the repository's own modules
    -- folder.
    local backports = import("apple.backports", {rootdir = path.join(root, "modules"),
                                                anonymous = true})
    -- The module lives beside this file, under the repository's modules/ folder, which the
    -- import above finds only when the test is run from the checkout the light guard runs.
    local failures = {}
    for _, library in ipairs(backports.libraries()) do
        local entries = library.archives or {}
        if #entries > 0 then
            local cxx = false
            local folder = path.join(root, "packages", "a", "apple-backports", library.folder)
            for _, source in ipairs(os.files(path.join(folder, "*.mm"))) do
                cxx = true
            end
            for _, wanted in ipairs(entries) do
                local marked = false
                for _, name in ipairs(library.c_archives or {}) do
                    if name == wanted then marked = true end
                end
                if not marked and not cxx then
                    table.insert(failures, string.format(
                        "%s links the archive %s and keeps no .mm object in any band, so link()'s "
                        .. "cxx rule would drop it from every band; an archive whose API is C says "
                        .. "c_archives",
                        library.name, tostring(wanted)))
                end
            end
        end
    end
    if #failures > 0 then
        for _, failure in ipairs(failures) do
            print("FAIL: " .. failure)
        end
        raise("%d library archive(s) a band with no C++ object could not link", #failures)
    end
    print("archive_language: every library's archives are reachable in every band that keeps an object")
    return true
end
