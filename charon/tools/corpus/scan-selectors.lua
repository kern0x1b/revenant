-- Per app: every selector name the bundle carries (__objc_methname strings -> corpus/selcache/<app>.json)
-- and every selector the bundle DEFINES (corpus/defcache/<app>.json, from defined-methods.lua's defined()).
-- crash-demand computes sends = carried - universe(iOS 6.0) - defined from these two files; this is the
-- one script that builds both from a real .app bundle, so the two stay from the same binary by construction.
--
-- Neither half duplicates aggregate.lua's ingest(): those operate on `nm -m`'s external symbol table, the
-- LINKER-visible surface (classes, protocols, C functions/constants) that builds store.json's `demand`.
-- Selector names (__objc_methname) are never linker symbols at all -- Objective-C messaging resolves them
-- dynamically, so `nm` never lists one -- an entirely different Mach-O section this script reads.
--
-- Usage:
--   xmake l tools/corpus/scan-selectors.lua <app-name> <path-to-.app>
import("core.base.json")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})
import("aggregate", {rootdir = os.scriptdir()})
local dm = import("defined-methods", {rootdir = os.scriptdir()})

-- The __objc_methname strings one binary's __TEXT carries -- sent OR defined, a name is a name regardless.
-- otool -v resolves each entry to (address, string); a bare address with no trailing text is a null-byte
-- padding continuation, not a second selector, and is skipped.
local function carried_names(binary)
    local names, index = {}, 0
    for line in (os.iorunv("otool", {"-v", "-s", "__TEXT", "__objc_methname", binary}) .. "\n"):gmatch("(.-)\n") do
        index = index + 1
        if index > 2 then   -- skip "<binary>:" and "Contents of (...)" header lines
            -- str.split(None, 1): the first whitespace-separated field, then the rest of the line
            local rest = line:match("^%s*%S+%s+(.*)$")
            if rest and rest ~= "" then
                names[rest] = true
            end
        end
    end
    return names
end

function main(app, appdir)
    assert(app and appdir, "usage: scan-selectors.lua <app-name> <path-to-.app>")
    local bins = aggregate.macho_binaries(appdir)
    if #bins == 0 then
        raise("scan-selectors.lua: no Mach-O binaries found under %s", appdir)
    end
    local carried, defined = {}, {}
    for _, binary in ipairs(bins) do
        for name in pairs(carried_names(binary)) do
            carried[name] = true
        end
        for name in pairs(dm.defined(binary)) do
            defined[name] = true
        end
    end
    local corpus = aggregate.corpus_dir()
    os.mkdir(path.join(corpus, "selcache"))
    os.mkdir(path.join(corpus, "defcache"))
    for _, part in ipairs({{"selcache", carried}, {"defcache", defined}}) do
        local text, err = json.encode(json.mark_as_array(byteorder.keys(part[2])))
        if not text then
            raise("scan-selectors.lua: cannot encode %s: %s", app, tostring(err))
        end
        io.writefile(path.join(corpus, part[1], app .. ".json"), text)
    end
    print(string.format("%s: %d binaries, %d carried selectors, %d defined", app, #bins,
        #byteorder.keys(carried), #byteorder.keys(defined)))
end
