-- Count, over every class of a real dyld shared cache, the classes whose OWN method list carries a
-- selector. Two lists are counted separately, because the reader stores a selector under one key in
-- both of them and a search that does not know that answers 0 for a selector that is really there.
--
--     CHARON_ROOT=<worktree> xmake l class-selector-census.lua <cache> <selector> [image substring]
--
-- `<selector>` is the key **as modules/apple/objc.lua stores it**: `method_list` writes
-- `names["-" .. name]`, so an instance method and a class method of the same name share one key and
-- the two lists are the only thing that tells them apart. Asking for `new` or `+new` answers 0 in
-- every class of every cache, which is not a finding about the world: it is the shape of the key.
--
-- What is counted is a class's own list plus any category any image of the cache adds to it, and NOT
-- the superclass chain: `collect` in modules/apple/objc.lua reads `data.methods` and the metaclass's
-- `methods` and never walks a superclass, so a class that inherits a selector does not own it and
-- does not appear here. That is the distinction a `+new` question needs, because `+new` is NSObject's
-- and is inherited rather than redeclared by almost every class in a cache.
--
-- Output, one line per class that owns the selector in the list named, then the two counts:
--
--     #cache   arm64e
--     class    <name>  <image>  own=<instance|class|both>
--     #own instance <n>  class <n>  both <n>  of <total> classes
--
-- The control is in the output and not in this comment: the two counts are printed whatever they are,
-- and a run whose `class` count is 0 for a selector a release is known to define has found a defect in
-- the search, not a fact about the release.

import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

local objc_module = "apple.objc"

function main(cachefile, selector, image)
    assert(cachefile and selector,
           "usage: class-selector-census.lua <cache> <selector-as-objc.lua-stores-it> [image substring]")
    local objc = import(objc_module, {rootdir = path.join(os.getenv("CHARON_ROOT"), "modules"), anonymous = true})
    local found = objc.inventory(cachefile)
    assert(found, cachefile .. " holds no readable Objective-C metadata")
    print(string.format("#cache %s", found.architecture))
    local instance_owners, class_owners, both = {}, {}, {}
    local total = 0
    for name, class in pairs(found.classes) do
        if not image or (class.image and class.image:find(image, 1, true)) then
            total = total + 1
            local in_instance = class.instance[selector] == true
            local in_class = class.class[selector] == true
            if in_instance or in_class then
                local where = in_instance and in_class and "both" or (in_instance and "instance" or "class")
                table.insert(in_instance and in_class and both or (in_instance and instance_owners or class_owners),
                             string.format("%s\t%s\t%s", name, class.image or "-", where))
            end
        end
    end
    local function sorted(list)
        byteorder.sort(list)
        for _, line in ipairs(list) do
            print("class\t" .. line)
        end
    end
    sorted(instance_owners)
    sorted(class_owners)
    sorted(both)
    print(string.format("#own instance %d  class %d  both %d  of %d classes",
                        #instance_owners, #class_owners, #both, total))
end