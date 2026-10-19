-- Structured wrapper over the canonical apple.dyld.missing_imports.
-- Prints one TSV line per missing entry: <importer-basename>\t<raw message>
-- Usage: CHARON_ROOT=<worktree> xmake l corpus-scan.lua <release> <binary>...
-- Pass the app's main binary PLUS every embedded framework/appex binary so
-- intra-app and 3rd-party-defined symbols resolve out; what remains is demand
-- against the stock shared cache of <release>. Add band dylibs to the binary
-- list to fold the current backports in (remaining-gap pass).
function main(release, ...)
    local binaries = {...}
    assert(release and #binaries > 0, "usage: corpus-scan.lua <release> <binary>...")
    local dyld = import("apple.dyld", {rootdir = path.join(os.getenv("CHARON_ROOT"), "modules"), anonymous = true})
    local cache = path.join(os.getenv("HOME"), ".charon", "dyld", release, "dyld_shared_cache_armv7")
    local missing = dyld.missing_imports(cache, binaries)
    for _, entry in ipairs(missing) do
        print(path.filename(entry[1]) .. "\t" .. entry[2])
    end
end
