import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})
local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})

function main(source, architecture)
    assert(source, "usage: objc-inventory.lua <binary-or-cache> [architecture]")
    local objc = import("apple.objc", {rootdir = path.join(workspace.root(), "toolchain", "modules"), anonymous = true})
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
