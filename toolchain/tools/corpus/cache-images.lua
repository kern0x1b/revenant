local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})

function main(cachefile)
    assert(cachefile, "usage: cache-images.lua <cache file>")
    local dyld = import("apple.dyld", {rootdir = path.join(workspace.root(), "toolchain", "modules"), anonymous = true})
    local cache = dyld.load(cachefile)
    for install, library in pairs(cache.libraries) do
        local count = 0
        for _ in pairs(library.exports) do
            count = count + 1
        end
        print(install .. "\t" .. count)
    end
end
