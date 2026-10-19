import("core.base.option")
import("apple.dyld", {rootdir = path.join(os.scriptdir(), "..", "modules")})
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "modules")})

local POSITIVE = "_kVTProfileLevel_H264_Baseline_4_0"
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
    print(string.format("sdkdir: %s (a directory: %s)", tostring(sdkdir),
                        tostring(sdkdir and os.isdir(sdkdir))))
    print(string.format("asked: %d symbols, first %s, last %s", #asked, tostring(asked[1]),
                        tostring(asked[#asked])))
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
