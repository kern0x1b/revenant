-- xmake l tools/image-exports.lua RELEASE ARCHITECTURE INSTALL_SUBSTRING [SYMBOL_SUBSTRING]
--
-- Every symbol one image of one release's shared cache exports whose name contains SYMBOL_SUBSTRING,
-- read from that image's own export trie through modules/apple/dyld.lua.
--
-- This is the check a whole-cache search cannot make. "Is AVAssetWriterCreateWithURL in the 6.1.3
-- cache?" has answer "no" whether the constructor was never compiled for that slice or is exported
-- under a spelling a search for the public name misses -- and on 6.1.3 the AVFoundation image
-- exports 75 symbols matching "AssetWriter" of which every single one is an _OBJC_CLASS_$,
-- _OBJC_METACLASS_$ or ivar symbol, which is a different fact from "the class is missing" and the
-- one that decides whether the public writer API can be used at all.
--
-- INSTALL_SUBSTRING picks the image(s) by install name (e.g. "AVFoundation.framework/AVFoundation",
-- "libIOAccessoryManager"); SYMBOL_SUBSTRING picks the symbols within it, and an empty
-- SYMBOL_SUBSTRING lists all of them. The image's total export count is printed either way, because
-- "0 of 1731" and "75 of 75" say very different things.
--
-- Usage:
--   xmake l tools/image-exports.lua 6.1.3 armv7 "AVFoundation.framework/AVFoundation" "AssetWriter"
--   xmake l tools/image-exports.lua 6.1.3 armv7 "IAPAuthentication.framework"

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
