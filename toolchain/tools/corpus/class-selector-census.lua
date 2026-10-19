import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

local objc_module = "apple.objc"

function main(cachefile, selector, image)
    assert(cachefile and selector,
           "usage: class-selector-census.lua <cache> <selector-as-objc.lua-stores-it> [image substring]")
    local objc = import(objc_module, {rootdir = path.join(os.getenv("REVENANT_ROOT"), "modules"), anonymous = true})
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
