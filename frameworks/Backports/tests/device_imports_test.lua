local byteorder = import("@addon.revenant.byteorder", {anonymous = true})
local dyld = import("@addon.revenant.apple.dyld", {anonymous = true})
local dyld_caches = import("@addon.revenant.apple.dyld_caches", {anonymous = true})
local firmware = import("@addon.revenant.apple.firmware", {anonymous = true})
local macho = import("@addon.revenant.apple.macho", {anonymous = true})

local ROOT = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
local ARCHITECTURE = "armv7"
local USAGE = [=[usage: ./xmakew l -P . frameworks/Backports/tests/device_imports_test.lua [FOLDER]

Runs the check the deb writer runs on every image it packs (dyld.missing_imports) on the Backports libraries in FOLDER,
against the system libraries of the oldest release they claim to run on, and fails with the deb writer's message when one
imports, or re-exports, a symbol that release does not export. A library that loads another package's image (ffmpeg,
libc++) is not judged on that load: the deb that packs the other package provides it.
FOLDER  defaults to REVENANT_BACKPORTS_LIBRARIES, then to the gate tree's build/iphoneos/armv7/release]=]

local function default_folder()
    local named = os.getenv("REVENANT_BACKPORTS_LIBRARIES")
    if named and named ~= "" then
        return named
    end
    return path.join(ROOT, "build", "backports-gate", "tree", "build", "iphoneos", ARCHITECTURE, "release")
end

local function libraries(folder)
    local found = os.files(path.join(folder, "lib*Backports.dylib"))
    assert(#found > 0, folder .. " holds no lib*Backports.dylib: build the Backports libraries first")
    byteorder.sort(found)
    return found
end

local function floor(files)
    local lowest
    for _, file in ipairs(files) do
        for _, recorded in ipairs(macho.recorded_minimums(file, ARCHITECTURE)) do
            if recorded.minimum and (not lowest or recorded.minimum < lowest) then
                lowest = recorded.minimum
            end
        end
    end
    assert(lowest, "none of the libraries records an iOS minimum for " .. ARCHITECTURE)
    return macho.version_text(lowest)
end

local function floor_cache(minimum)
    for _, entry in ipairs((dyld_caches.provision())) do
        print(string.format("device imports: cloned the iOS %s system libraries from %s (copy on write, no disk)", entry.release, entry.from))
    end
    local own = path.join(dyld.root(), minimum, "dyld_shared_cache_" .. ARCHITECTURE)
    if os.isfile(own) then
        return own, minimum
    end
    local cachefile, release = firmware.source(ARCHITECTURE, minimum)
    assert(os.exists(cachefile), string.format("the iOS %s system libraries are under %s and in no other checkout of this repository: the deb writer fetches the same folder, and so does ./xmakew firmware -P . --arch=%s fetch %s", release, dyld.root(), ARCHITECTURE, minimum))
    return cachefile, release
end

local function problems(cachefile, files, folder)
    local missing, count = dyld.missing_imports(cachefile, files, folder)
    local found = {}
    for _, entry in ipairs(missing) do
        if not entry[2]:startswith("(loads ") then
            table.insert(found, string.format("%s  %s", entry[1], entry[2]))
        end
    end
    return found, count
end

function main(folder)
    if folder == "-h" or folder == "--help" then
        print(USAGE)
        return
    end
    folder = folder or default_folder()
    assert(os.isdir(folder), folder .. " is not built: build the Backports libraries first")
    local files = libraries(folder)
    local cachefile, release = floor_cache(floor(files))
    print(string.format("device imports: %d libraries of %s against the iOS %s system libraries (%s)", #files, folder, release, cachefile))
    local found, count = problems(cachefile, files, folder)
    assert(#found == 0, "these imports are not exported by the device's iOS:\n  " .. table.concat(found, "\n  "))
    print(string.format("device imports: %d libraries checked, ok", count))
end
