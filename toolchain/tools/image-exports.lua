import("apple.dyld", {rootdir = path.join(os.scriptdir(), "..", "modules")})
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "modules")})

function main(release, architecture, where, want)
    release, architecture = release or "6.1.3", architecture or "armv7"
    where, want = where or "", want or ""
    local source = assert(dyld.held_source(path.join(dyld.root(), release), architecture),
                          "image-exports: no held cache for " .. release .. " " .. architecture)
    local cache = dyld.load(source)
    local installs = {}
    for install in pairs(cache.images) do
        table.insert(installs, install)
    end
    byteorder.sort(installs)
    local found = 0
    for _, install in ipairs(installs) do
        if install:find(where, 1, true) then
            local library = cache.libraries[install]
            local all, names = 0, {}
            for name in pairs(library.exports) do
                all = all + 1
                if want == "" or name:find(want, 1, true) then
                    table.insert(names, name)
                end
            end
            byteorder.sort(names)
            found = found + 1
            print("== %s: %d exports, %d matching %q", install, all, #names, want)
            for _, name in ipairs(names) do
                print("   %s", name)
            end
        end
    end
    if found == 0 then
        print("image-exports: no image of %s %s has %q in its install name", release, architecture, where)
    end
end
