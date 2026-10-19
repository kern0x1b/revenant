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
