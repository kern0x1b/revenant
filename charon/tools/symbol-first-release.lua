import("apple.dyld", {rootdir = path.join(os.scriptdir(), "..", "modules")})

local function newest_sdk()
    local found = os.dirs(path.join(os.getenv("HOME"), ".xmake", "packages", "i", "iphoneos-sdk", "*", "*", "Developer.app",
                                    "Contents", "Developer", "Platforms", "iPhoneOS.platform", "Developer", "SDKs", "iPhoneOS*.sdk"))
    table.sort(found, function (a, b) return os.mtime(a) > os.mtime(b) end)
    return found[1]
end

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
