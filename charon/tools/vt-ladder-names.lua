-- vt-ladder-names.lua — measure a list of VideoToolbox constant names against the HELD CACHES.
--
--   xmake l tools/vt-ladder-names.lua <names file> [SDKDIR]
--   prints constant<TAB>release, or constant<TAB>- where no held cache exports it
--
-- WHY: ladder.tsv is read by place-by-ladder.py to place the port's 135 constants, and it used to be
-- built from the port's OWN objects. So it held those 135 and nothing else, and "the table says nothing"
-- could be read as "no held cache exports it" - two different claims, and 13 registry rows (the
-- kVTProfileLevel levels, which the release exports itself) were unaccountable for. The table must hold
-- EVERY constant row the registry has, each with a release or an explicit '-', and a row absent from it
-- is a failure rather than a silence.
--
-- IT CALLS THE SAME MODULE tools/release-split.lua CALLS and has no exports reader of its own:
--   dyld.held_ladder({"armv7", "armv7s"})   the real cache ladder, oldest rung first
--   dyld.first_releases(ladder, sdkdir, ...)  the first release that EXPORTS a symbol
-- A second reader is the two-implementations failure this family has produced four times, and the export
-- tries are exactly why a byte search cannot answer this: modules/apple/dyld.lua walks them.
--
-- TWO CONTROLS, because without them nothing it prints is a result: a symbol KNOWN to be exported at 7.0,
-- which must come back with a rung, and a name in no header and no cache, which must come back '-'.

import("core.base.option")
import("apple.dyld", {rootdir = path.join(os.scriptdir(), "..", "modules")})
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "modules")})

-- FOUND: one of the profile levels the ladder places at 7.0.
local POSITIVE = "_kVTProfileLevel_H264_Baseline_4_0"
-- ABSENT: no header declares it and no cache exports it.
local NEGATIVE = "_kVTCharonNegativeControlNameThatIsInNothing"

function names_from(path)
    local names = {}
    for line in io.lines(path) do
        local name = line:match("^%s*([%w_]+)%s*$")
        if name and name ~= "" then table.insert(names, "_" .. name) end
    end
    byteorder.sort(names)
    return names
end


function main(namesfile, sdkdir)
    local file = namesfile
    if not file or not os.isfile(file) then
        print("usage: xmake l tools/vt-ladder-names.lua <names file> [SDKDIR]")
        os.exit(1)
    end
    if not sdkdir or not os.isdir(sdkdir) then
        print("no SDK directory given, and first_releases keys its kept measurement on it")
        os.exit(1)
    end
    local names = names_from(file)
    local ladder = dyld.held_ladder({"armv7", "armv7s"})
    print(string.format("the ladder: %d rungs held", #ladder))
    local asked = {}
    for _, name in ipairs(names) do table.insert(asked, name) end
    table.insert(asked, POSITIVE)
    table.insert(asked, NEGATIVE)
    -- WHAT THE MEASUREMENT IS ABOUT TO BE ASKED, printed because an empty value in EITHER place makes
    -- first_releases hash nothing, and the error does not say which: "cannot generate hash128 for ".
    print(string.format("sdkdir: %s (a directory: %s)", tostring(sdkdir),
                        tostring(sdkdir and os.isdir(sdkdir))))
    print(string.format("asked: %d symbols, first %s, last %s", #asked, tostring(asked[1]),
                        tostring(asked[#asked])))
    -- Lua's assert is a FUNCTION: assert(v, message), not a statement form. `assert v, "m"` parses as a
    -- call to assert with two expressions and is a syntax error, which is what it was.
    assert(sdkdir and os.isdir(sdkdir), "the SDK directory is what first_releases keys on, and it must be the .sdk itself")
    for index, symbol in ipairs(asked) do
        assert(symbol and symbol ~= "", "symbol " .. index .. " is empty")
    end
    local first = dyld.first_releases(ladder, sdkdir, asked)
    for _, name in ipairs(names) do
        local release = first[name]
        if type(release) == "string" then
            print(string.format("%s\t%s", name:sub(2), release))
        else
            print(string.format("%s\t-", name:sub(2)))
        end
    end
    local failures = 0
    if type(first[POSITIVE]) ~= "string" then
        print(string.format("FAIL the positive control %s was not found", POSITIVE:sub(2)))
        failures = failures + 1
    else
        print(string.format("CONTROL FOUND  %s first exported at %s", POSITIVE:sub(2), first[POSITIVE]))
    end
    if first[NEGATIVE] then
        print(string.format("FAIL the negative control %s came back with %s", NEGATIVE:sub(2),
                            tostring(first[NEGATIVE])))
        failures = failures + 1
    else
        print(string.format("CONTROL ABSENT %s, as it must be", NEGATIVE:sub(2)))
    end
    if failures > 0 then os.exit(1) end
end
