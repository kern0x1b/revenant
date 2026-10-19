-- ObjC inventory of every binary under a directory, in one run.
-- Usage: CHARON_ROOT=<worktree> xmake l fleet-inventory.lua <directory> [architecture]
--
-- One xmake startup per band rather than one per library: 34 bands x 28 libraries is 952 starts
-- at about 0.3 s each, which is five minutes for a view meant to be run every hour. One run over
-- the directory is 0.2 s.
--
-- Prints, per class and per protocol found:
--   class<TAB><name><TAB><instance selectors, comma-joined><TAB><class selectors, comma-joined>
--
-- The exported symbols are not here: modules/apple/macho.lua keeps no symbol reader to call, so the
-- caller gets those from `nm -gU` per library, which is a few milliseconds each.

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
    -- A `#` line, which the caller skips: this dialect has no os.stderr.
    print(string.format("#%d binaries under %s", binaries, directory))
end
