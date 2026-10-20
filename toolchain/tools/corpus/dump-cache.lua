local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})

function main(cachefile)
    assert(cachefile, "usage: dump-cache.lua <cache file>")
    local dyld = import("apple.dyld", {rootdir = path.join(workspace.root(), "toolchain", "modules"), anonymous = true})
    local cache = dyld.load(cachefile)
    for install, library in pairs(cache.libraries) do
        local fw = path.filename(install)
        for name in pairs(library.exports) do
            print(name .. "\t" .. fw)
        end
    end
end
