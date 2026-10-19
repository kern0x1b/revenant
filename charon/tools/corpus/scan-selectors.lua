import("core.base.json")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})
import("aggregate", {rootdir = os.scriptdir()})
local dm = import("defined-methods", {rootdir = os.scriptdir()})

local function carried_names(binary)
    local names, index = {}, 0
    for line in (os.iorunv("otool", {"-v", "-s", "__TEXT", "__objc_methname", binary}) .. "\n"):gmatch("(.-)\n") do
        index = index + 1
        if index > 2 then
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
