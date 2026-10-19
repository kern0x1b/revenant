function main(release, ...)
    local binaries = {...}
    assert(release and #binaries > 0, "usage: corpus-scan.lua <release> <binary>...")
    local dyld = import("apple.dyld", {rootdir = path.join(os.getenv("REVENANT_ROOT"), "modules"), anonymous = true})
    local cache = path.join(os.getenv("HOME"), ".revenant", "dyld", release, "dyld_shared_cache_armv7")
    local missing = dyld.missing_imports(cache, binaries)
    for _, entry in ipairs(missing) do
        print(path.filename(entry[1]) .. "\t" .. entry[2])
    end
end
