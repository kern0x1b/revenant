-- Per app: selectors the bundle DEFINES (method_t entries: name, then types, then imp), from
-- `otool -arch arm64 -oV` over every Mach-O. A method entry is `name` immediately followed by a `types`
-- line; ivars carry `type` and properties `attributes`, so they do not match. Selectors an app defines
-- are override points/callbacks (UIKit calls them, the app does not send them) -> used to separate SENDS
-- from IMPLEMENTS.
--
-- Usage:
--   defined(binary)             (import this file: scan-selectors.lua does) -> set of selectors
--   xmake l tools/corpus/defined-methods.lua    batch over the apps that have an extracted bundle under
--                                               corpus/<app>/extracted/Payload, written to corpus/defcache/<app>.json
import("core.base.json")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})
import("aggregate", {rootdir = os.scriptdir()})

local NAME = "^%s+name%s+0x[0-9a-f]+%s+(%S.*)$"
local TYPES = "^%s+types%s+0x"

-- The selectors one binary defines, as a set.
function defined(binary)
    local names, pending = {}, nil
    for line in (os.iorunv("otool", {"-arch", "arm64", "-oV", binary}) .. "\n"):gmatch("(.-)\n") do
        local name = line:match(NAME)
        if name then
            pending = (name:gsub("%s+$", ""))
        elseif pending ~= nil then
            if line:match(TYPES) then
                names[pending] = true
            end
            pending = nil
        end
    end
    return names
end

-- The batch the script runs with no arguments. The app list is the set of extracted bundles it knew of.
local BATCH_APPS = {"ish", "ppsspp", "pojav", "provenance", "delta", "utm", "aidoku", "yattee", "session", "telegram"}

function main(...)
    if select("#", ...) > 0 then
        print("usage: xmake l tools/corpus/defined-methods.lua   (batch; scan-selectors.lua does one app)")
        return
    end
    local defcache = path.join(aggregate.corpus_dir(), "defcache")
    os.mkdir(defcache)
    for _, app in ipairs(BATCH_APPS) do
        local base = path.join(aggregate.corpus_dir(), app, "extracted", "Payload")
        local bundle = nil
        if os.isdir(base) then
            local bundles = os.dirs(path.join(base, "*.app"))
            byteorder.sort(bundles)
            bundle = bundles[1]
        end
        if bundle then
            local seen = {}
            for _, binary in ipairs(aggregate.macho_binaries(bundle)) do
                for selector in pairs(defined(binary)) do
                    seen[selector] = true
                end
            end
            local list = byteorder.keys(seen)
            local text, err = json.encode(json.mark_as_array(list))
            if not text then
                raise("defined-methods.lua: cannot encode %s: %s", app, tostring(err))
            end
            io.writefile(path.join(defcache, app .. ".json"), text)
            print(string.format("%s: %d defined selectors", app, #list))
        end
    end
    print("DEF-DONE")
end
