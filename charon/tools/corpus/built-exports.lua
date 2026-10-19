-- Write what the canon's 6.1.3 band exports to the built-exports file, for gen-report.lua's LAUNCH-BLOCK.
--
-- usage: xmake l tools/corpus/built-exports.lua <canon-run>
--
-- <canon-run> is the output directory of coordination/canon-build.lua (workspace skill canon-install):
-- it holds one org.charon.apple-backports_*.deb and build/stage. The list is every name `nm -gUj` gives
-- over the stage's bands/6.1.3/*.dylib, under a first line naming the deb's Version, so a list older than
-- the canon it is read against says so in the report.
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})
import("aggregate", {rootdir = os.scriptdir()})

local BAND = path.join("build", "stage", "usr", "lib", "charon", "org.charon.apple-backports", "bands", "6.1.3")

function main(run)
    if not run then
        raise("usage: built-exports.lua <canon-run>")
    end
    local debs = os.files(path.join(run, "org.charon.apple-backports_*.deb"))
    if #debs ~= 1 then
        raise("built-exports.lua: %s holds %d canon packages, not one", run, #debs)
    end
    local version = os.iorunv("dpkg-deb", {"-f", debs[1], "Version"}):match("^%s*(.-)%s*$")
    local dylibs = os.files(path.join(run, BAND, "*.dylib"))
    if #dylibs == 0 then
        raise("built-exports.lua: no dylib under %s", path.join(run, BAND))
    end
    byteorder.sort(dylibs)
    local names, seen = {}, {}
    for _, dylib in ipairs(dylibs) do
        for line in os.iorunv("nm", {"-gUj", dylib}):gmatch("[^\n]+") do
            local name = line:match("^%s*(.-)%s*$")
            if name ~= "" and not seen[name] then
                seen[name] = true
                table.insert(names, name)
            end
        end
    end
    byteorder.sort(names)
    local out = aggregate.built_exports_file()
    local file = assert(io.open(out, "w"))
    file:write(aggregate.built_exports_header() .. version .. "\n")
    for _, name in ipairs(names) do
        file:write(name .. "\n")
    end
    file:close()
    print(string.format("built-exports.lua: %d names of %d libraries of canon %s -> %s", #names, #dylibs, version, out))
end
