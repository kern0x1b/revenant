-- Dump Objective-C classes (name, superclass, instance/class selectors, protocols) from a built
-- binary or a whole dyld shared cache, via the driver's own apple.objc reader.
-- Usage: CHARON_ROOT=<worktree> xmake l objc-inventory.lua <binary-or-cache> [architecture]
-- Prints one TSV line per class: class\t<name>\t<superclass-or-empty>\t<image>\t<instance selectors, comma-joined>\t<class selectors, comma-joined>\t<protocols, comma-joined>
-- With no architecture argument, <binary-or-cache> is read as a dyld shared cache file (apple.objc.inventory);
-- with one, it is read as a single Mach-O binary for that architecture (apple.objc.binary_inventory).

import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

function main(source, architecture)
    assert(source, "usage: objc-inventory.lua <binary-or-cache> [architecture]")
    local objc = import("apple.objc", {rootdir = path.join(os.getenv("CHARON_ROOT"), "modules"), anonymous = true})
    local found = architecture and objc.binary_inventory(source, architecture) or objc.inventory(source)
    assert(found, source .. " holds no readable Objective-C metadata")
    local function joined(set)
        local keys = table.keys(set or {})
        byteorder.sort(keys)
        return table.concat(keys, ",")
    end
    for name, class in pairs(found.classes) do
        print(table.concat({"class", name, class.superclass or "", class.image or "",
                            joined(class.instance), joined(class.class), joined(class.protocols)}, "\t"))
    end
    for name, protocol in pairs(found.protocols or {}) do
        print(table.concat({"protocol", name, "", "", joined(protocol.instance), joined(protocol.class), ""}, "\t"))
    end
end
