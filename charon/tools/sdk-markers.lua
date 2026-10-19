-- xmake l tools/sdk-markers.lua SDKDIR OLDSDKDIR [OUTPUT]
--
-- Which symbols of libSystem an SDK has that an older SDK of the same platform has not, and the first
-- release the held dyld caches (dyld.held_ladder) export each from. The `iphoneos-sdk` package gives an SDK
-- whose stubs carry no `$ld$` markers the markers of the older one (packages/i/iphoneos-sdk), and for a
-- symbol the older one does not know, the hide markers this file's release implies: one for each release
-- below it that the older SDK's markers name. OUTPUT is what the package reads,
-- packages/i/iphoneos-sdk/markers/iPhoneOS<version>.tsv: `symbol<TAB>release` per line, `-` for a symbol
-- none of the held caches exports (it is newer than they are).
--
-- SDKDIR and OLDSDKDIR are iPhoneOS SDK folders as their archives extract them, OLDSDKDIR untouched by
-- the package's own additions. Reading the caches takes a few minutes, so run it through
-- coordination/heavy.sh; what it measured is kept in $CHARON_HOME/cache like release-split's.

import("apple.dyld", {rootdir = path.join(os.scriptdir(), "..", "modules")})
import("apple.sdkstubs", {rootdir = path.join(os.scriptdir(), "..", "modules")})
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "modules")})

local function libsystem_documents(sdk)
    local found = {}
    for _, file in ipairs(table.join({path.join(sdk, "usr", "lib", "libSystem.B.tbd")}, os.files(path.join(sdk, "usr", "lib", "system", "*.tbd")))) do
        if os.isfile(file) then
            for _, text in ipairs(sdkstubs.documents(io.readfile(file))) do
                local doc = sdkstubs.read(text)
                if sdkstubs.in_libsystem(doc.install) then
                    table.insert(found, doc)
                end
            end
        end
    end
    return found
end

function main(sdkdir, oldsdkdir, output)
    assert(sdkdir and oldsdkdir, "usage: xmake l tools/sdk-markers.lua SDKDIR OLDSDKDIR [OUTPUT]")
    local known = {}
    for _, doc in ipairs(libsystem_documents(oldsdkdir)) do
        for symbol in pairs(sdkstubs.exported(doc)) do
            known[symbol] = true
        end
        for _, marker in ipairs(sdkstubs.markers(doc)) do
            known[marker.token:match("^%$ld%$%a+%$os[%d%.]+%$(.+)$") or ""] = true
        end
    end
    local new = {}
    for _, doc in ipairs(libsystem_documents(sdkdir)) do
        for symbol, archs in pairs(sdkstubs.exported(doc)) do
            if not known[symbol] and (archs.armv7 or archs.armv7s) then
                new[symbol] = true
            end
        end
    end
    local ladder = dyld.held_ladder({"armv7", "armv7s"})
    local first = dyld.first_releases(ladder, sdkdir, table.orderkeys(new))
    local lines = {}
    for symbol in pairs(new) do
        table.insert(lines, symbol .. "\t" .. (first[symbol] or "-"))
    end
    byteorder.sort(lines)
    local releases = {}
    for _, rung in ipairs(ladder) do
        table.insert(releases, rung.release)
    end
    local function named(folder)
        return import("core.base.json").loadfile(path.join(folder, "SDKSettings.json")).CanonicalName
    end
    local text = string.format("# libSystem symbols of %s that %s lacks, and the first of the held releases that exports each (- for none).\n" ..
                               "# Written by tools/sdk-markers.lua; the releases held: %s.\n%s\n",
                               named(sdkdir), named(oldsdkdir), table.concat(releases, " "), table.concat(lines, "\n"))
    if output then
        io.writefile(output, text)
    else
        io.write(text)
    end
    print(string.format("%d new symbols, %d with no held release exporting them", #lines, #lines - #table.keys(first)))
end
