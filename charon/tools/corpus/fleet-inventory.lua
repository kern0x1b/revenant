import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

function main(directory, architecture)
    assert(directory, "usage: fleet-inventory.lua <directory> [architecture]")
    local objc = import("apple.objc", {rootdir = path.join(os.getenv("CHARON_ROOT"), "modules"), anonymous = true})
    local macho = import("apple.macho", {rootdir = path.join(os.getenv("CHARON_ROOT"), "modules"), anonymous = true})
    local arch = architecture or "armv7"
    local function joined(set)
        local keys = table.keys(set or {})
        byteorder.sort(keys)
        return table.concat(keys, ",")
    end
    local binaries = 0
    for _, binary in ipairs(macho.binaries_under(directory)) do
        local found = objc.binary_inventory(binary, arch)
        if found then
            binaries = binaries + 1
            for name, class in pairs(found.classes) do
                print(table.concat({"class", name, joined(class.instance), joined(class.class)}, "\t"))
            end
            for name, protocol in pairs(found.protocols or {}) do
                print(table.concat({"protocol", name, joined(protocol.instance), joined(protocol.class)}, "\t"))
            end
        end
    end
    print(string.format("#%d binaries under %s", binaries, directory))
end
