import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

local SELECTOR_CONTROLS = {"-isEqual:", "-description", "-initWithFrame:"}
local SELECTOR_NEGATIVE = "-charonNoSuchSelectorAnywhere:"

function main(prefix, ...)
    local objc = import("apple.objc", {rootdir = path.join(os.getenv("CHARON_ROOT"), "modules"), anonymous = true})
    local dyld = import("apple.dyld", {rootdir = path.join(os.getenv("CHARON_ROOT"), "modules"), anonymous = true})
    local root = dyld.root()

    if prefix == "--selectors" then
        local asked = {...}
        assert(#asked > 0, "usage: cache-census.lua --selectors <name>...")
        for _, pair in ipairs({{"4.3", "armv7"}, {"6.1.3", "armv7"}, {"11.0", "arm64"}}) do
            local release, arch = pair[1], pair[2]
            local cache = path.join(root, release, "dyld_shared_cache_" .. arch)
            local known = objc.known_selectors(cache)
            local total = 0
            for _ in pairs(known) do
                total = total + 1
            end
            print(string.format("== %s  %s", release, cache))
            print(string.format("   selectors the cache registers: %d", total))
            for _, name in ipairs(SELECTOR_CONTROLS) do
                print(string.format("   control  %-52s %s", name, known[name] and "known" or "ABSENT (wrong)"))
            end
            print(string.format("   control  %-52s %s", SELECTOR_NEGATIVE,
                                known[SELECTOR_NEGATIVE] and "known (wrong)" or "unknown, as it must be"))
            for _, name in ipairs(asked) do
                print(string.format("   ask      %-52s %s", name, known[name] and "known" or "absent"))
            end
        end
        return
    end

    assert(prefix, "usage: cache-census.lua <name-prefix> [release...] | --selectors <name>...")

    local wanted = {...}
    if #wanted == 0 then
        wanted = {"6.1.3", "4.3", "11.0"}
    end
    local held = {}
    for _, rung in ipairs(dyld.held_ladder({"armv7", "armv7s"})) do
        held[rung.release] = rung
    end

    local function count(set)
        local n = 0
        for _ in pairs(set or {}) do
            n = n + 1
        end
        return n
    end

    local found_anywhere = 0
    for _, release in ipairs(wanted) do
        local rung = held[release]
        if not rung then
            print(string.format("%-8s  not held: no cache for any architecture this package keeps", release))
        else
            local found = objc.inventory(rung.source)
            local opened = dyld.open_cache(rung.source)
            local images, images_named = 0, 0
            for _, loaded in ipairs(opened.images) do
                images = images + 1
                if (loaded.install or ""):find(prefix, 1, true) then
                    images_named = images_named + 1
                end
            end
            opened.close()
            local classes, protocols = {}, {}
            for name in pairs(found.classes) do
                if name:startswith(prefix) then
                    table.insert(classes, name)
                end
            end
            for name in pairs(found.protocols or {}) do
                if name:startswith(prefix) then
                    table.insert(protocols, name)
                end
            end
            byteorder.sort(classes)
            byteorder.sort(protocols)
            found_anywhere = found_anywhere + #classes + #protocols
            print(string.format("%-8s  %s", release, rung.source))
            print(string.format("         images %d, of which naming %s %d", images, prefix, images_named))
            print(string.format("         classes %d, of which %s* %d%s", count(found.classes), prefix, #classes,
                                #classes > 0 and (" (" .. table.concat(classes, " ") .. ")") or ""))
            print(string.format("         protocols %d, of which %s* %d%s", count(found.protocols or {}), prefix, #protocols,
                                #protocols > 0 and (" (" .. table.concat(protocols, " ") .. ")") or ""))
        end
    end
    if found_anywhere == 0 then
        print("CONTROL FAILED: no rung read carried a name beginning " .. prefix ..
              ", so this run cannot show that the reader finds one; an absence from it is not evidence")
    else
        print("control: " .. found_anywhere .. " name(s) beginning " .. prefix ..
              " found in this run, so a zero on another rung is the release's and not the reader's")
    end
end
