-- A class-prefix census of the held armv7/arm64 caches, with a control in the same run.
--
-- Usage:
--   CHARON_ROOT=<worktree> xmake l tools/corpus/cache-census.lua <name-prefix> [release...]
--   CHARON_ROOT=<worktree> xmake l tools/corpus/cache-census.lua --selectors <name>...
--
-- `objc-inventory.lua` dumps every class and protocol of one cache. This answers the narrower
-- question a registry row's `source` usually has to settle - "does the release carry any name like
-- this?" - and it answers it in a form a reviewer can check without a second tool and without
-- trusting the number in a facts page. Per release it prints the images, the classes and the
-- protocols that name the prefix, and the cache path it read.
--
-- **The control is the point, and it is in every run.** A census that prints 0 is ambiguous: the
-- name may really be absent, or the reader may be looking at the wrong thing, and a zero cannot
-- tell those apart. So each release is read, and every one prints its image count, its class and
-- protocol counts and the names found - a rung that carries the name is the control that makes the
-- zero on another rung mean something. A run in which no rung finds anything is reported as
-- CONTROL FAILED, not as an absence: it is the reader that is wrong, and a row may not be written
-- from it.
--
-- `--selectors` asks the OTHER question, through the other reader: `objc.known_selectors` reads the
-- selector table, which is a different part of the image from the class and protocol metadata
-- `objc.inventory` reads. It is kept here because the two together are what settles a member row,
-- and because the second reader does not merely confirm the first - a selector belongs to no named
-- class, so a name it reports can be registered by something else entirely. Each release prints its
-- selector count and three controls (`-isEqual:`, `-description`, `-initWithFrame:`, which every
-- release has, and one name none has) beside the answers.
--
-- Releases default to the two the package deploys on (6.1.3 and 4.3, both armv7) plus 11.0
-- (arm64), the first held rung that carries CoreNFC: with the three, the facts page's own claim is
-- reproducible by pasting the command and nothing else. Name releases to read others; the
-- architecture is the one `dyld.held_ladder` picks for that release, so 16.0 and 18.0 are read as
-- arm64e and 11.0 and 12.0 as arm64 - a split that is silent otherwise.

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
    -- the cache each named release is actually held for, read through the ladder's own choice
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
            -- the images the cache holds, which is the coarser question: a framework can be in a
            -- cache and contribute no class, and a row about a framework wants the image count
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
