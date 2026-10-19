-- xmake l tools/symbol-first-release.lua SYMBOLFILE... [ARCHITECTURES]
--
-- For every symbol named in each file (one per line, blank lines and # comments ignored), the first
-- held release that exports it, read from that release's own dyld shared cache through
-- modules/apple/dyld.lua. The measurement is the one modules/apple/backports.lua and
-- tools/release-split.lua make, over the same held cache ladder, so an answer here and an answer there
-- cannot drift: what it reports is where a client can first bind the symbol, not what a header's
-- availability annotation says.
--
-- A symbol counts as exported only by one of the libraries the SDK's .tbd files put it in (the
-- newest iPhoneOS SDK in the shared store, found the way tools/release-split.lua finds it), or
-- anywhere in the cache when no .tbd names it. Without that, a same-named symbol of an unrelated
-- image reads as the API -- CNLabelHome is exported by AddressBookUI from 7.0 and by Contacts, where
-- a client binds it, only from 9.0.
--
-- A symbol no held release exports prints "none". That is the interesting answer: it is how this
-- port decides that an API is not in a release at all, rather than carrying it on the strength of a
-- header.
--
-- --any-library turns the .tbd owner filter off, so a symbol counts wherever in the cache it is
-- exported, and this script then walks the ladder itself rather than through dyld.first_releases()
-- (which owns the filter internally and caches its filtered answers under $CHARON_HOME/cache, so a
-- filtered run cannot be un-filtered afterwards). That mode is the one to use for a PRIVATE API, and
-- it is not a corner case: the SDK's .tbd names
-- '/System/Library/Frameworks/VideoToolbox.framework/VideoToolbox' and
-- '/System/Library/Frameworks/IOSurface.framework/IOSurface', but on 6.1.3 VideoToolbox is under
-- Frameworks and IOSurface is still under PrivateFrameworks, and on 4.3 both are. So for their
-- private symbols the filter cannot match the pre-6.0 releases and the filtered answer names a
-- release far later than the truth -- _VTCompressionSessionCreate measures as 6.0 filtered and is
-- exported by VideoToolbox in 4.0 unfiltered. For a private symbol, read the image itself with
-- tools/image-exports.lua: that measurement does not depend on where the framework happens to live,
-- and it is the one a band should quote.
--
-- The unfiltered walk reads every rung's cache: measured 111 s and a 2.2 GB peak RSS over 47 rungs
-- (almost all of it shared mmap of the caches themselves, one armv7 cache reads in about a second
-- and 94 MB). The filtered path reads only symbols it has not already measured and is kept under
-- $CHARON_HOME/cache between runs, so it is the cheap one. A full-ladder unfiltered run belongs in a
-- coordination/heavy.sh slot like any other whole-ladder pass.
--
-- ARCHITECTURES defaults to armv7,armv7s, the slices iOS 6 runs on; pass arm64,arm64e to walk the
-- later releases instead. The ladder is read oldest first, so the first hit is the first release.
--
-- Usage:
--   xmake l tools/symbol-first-release.lua symbols.txt
--   xmake l tools/symbol-first-release.lua symbols.txt --any-library
--   xmake l tools/symbol-first-release.lua symbols.txt $SDKDIR
--   xmake l tools/symbol-first-release.lua symbols.txt arm64 arm64e

import("apple.dyld", {rootdir = path.join(os.scriptdir(), "..", "modules")})

-- The SDK whose .tbd files say which library owns each symbol. tools/release-split.lua takes the one
-- its objects were compiled against, which is the right rule: the .tbd files decide which library a
-- client binds a symbol from, so the answer is only meaningful against the SDK the code is built
-- with. This script is also asked about symbols nothing is compiled against yet, so it falls back to
-- the newest in the shared store -- and takes an explicit SDKDIR for the case where the caller knows
-- which one matters.
local function newest_sdk()
    local found = os.dirs(path.join(os.getenv("HOME"), ".xmake", "packages", "i", "iphoneos-sdk", "*", "*", "Developer.app",
                                    "Contents", "Developer", "Platforms", "iPhoneOS.platform", "Developer", "SDKs", "iPhoneOS*.sdk"))
    table.sort(found, function (a, b) return os.mtime(a) > os.mtime(b) end)
    return found[1]
end

-- Every symbol named in a file, one per line, comments and blanks dropped, order kept and duplicates
-- collapsed: the same symbol in two files is one measurement, and printing it twice would suggest two.
local function symbols_in(file)
    local wanted, seen = {}, {}
    for line in io.readfile(file):gmatch("[^\n]+") do
        local name = line:match("^%s*(.-)%s*$")
        if name ~= "" and not name:match("^#") and not seen[name] then
            seen[name] = true
            table.insert(wanted, name)
        end
    end
    return wanted
end

function main(...)
    local files, architectures, sdkdir, any = {}, {}, nil, false
    for _, argument in ipairs({...}) do
        if argument == "--any-library" then
            any = true
        elseif os.isfile(argument) then
            table.insert(files, argument)
        elseif os.isdir(argument) then
            sdkdir = argument
        else
            table.insert(architectures, argument)
        end
    end
    assert(#files > 0, "usage: xmake l tools/symbol-first-release.lua SYMBOLFILE... [--any-library] [SDKDIR] [ARCHITECTURES]")
    if #architectures == 0 then
        architectures = {"armv7", "armv7s"}
    end

    local sdkdir
    if not any then
        sdkdir = sdkdir or newest_sdk()
        assert(sdkdir, "symbol-first-release: no iPhoneOS SDK found in the shared store")
    end
    local ladder = dyld.held_ladder(architectures)
    assert(#ladder > 0, "symbol-first-release: no held cache for " .. table.concat(architectures, ","))
    print("ladder: %d rungs, %s (%s) .. %s (%s)", #ladder,
          ladder[1].release, ladder[1].architecture, ladder[#ladder].release, ladder[#ladder].architecture)
    print("owner filter: %s", any and "off (--any-library)" or "on, the .tbd libraries of " .. sdkdir)

    local wanted = {}
    for _, file in ipairs(files) do
        for _, name in ipairs(symbols_in(file)) do
            wanted[name] = true
        end
    end

    if any then
        -- The ladder walked here, one cache at a time, asking each whether it exports the symbol at
        -- all. Nothing is kept between runs: the answer depends on the filter, and a kept file keyed
        -- only by the ladder and the SDK could not tell a filtered answer from an unfiltered one.
        local first = {}
        for _, rung in ipairs(ladder) do
            local cache = dyld.load(rung.source)
            for name in pairs(wanted) do
                if first[name] == nil and cache.exports[name] ~= nil then
                    first[name] = rung.release
                end
            end
        end
        for _, file in ipairs(files) do
            print("\n== %s", path.filename(file))
            for _, name in ipairs(symbols_in(file)) do
                print("  %-64s %s", name, first[name] and first[name] or "none")
            end
        end
        return
    end

    local first = dyld.first_releases(ladder, sdkdir, table.orderkeys(wanted))

    for _, file in ipairs(files) do
        print("\n== %s", path.filename(file))
        for _, name in ipairs(symbols_in(file)) do
            print("  %-64s %s", name, first[name] and first[name] or "none")
        end
    end
end
