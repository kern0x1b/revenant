-- surface.lua DYLIB: the names the gate's own check_registry reads out of a built dylib, printed one
-- per line, so that a registered row can be looked for in exactly the set the gate compares against.
import("apple.backports", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})
local backports = import("apple.backports", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})
function main(dylib)
    local found = backports.surface({ path.absolute(dylib) }, "armv7")
    for name in pairs(found.classes) do print("class\t" .. name) end
    for name in pairs(found.members) do print("member\t" .. name) end
    for name in pairs(found.answered) do print("answered\t" .. name) end
    for name in pairs(found.symbols) do print("symbol\t" .. name) end
end
