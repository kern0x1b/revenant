import("core.package.package")

local HEAVY = {"llvm", "swift", "swift-bootstrap", "swift-runtime", "libcxx", "apple-compat", "iphoneos-sdk", "ld64"}

local function inputs(name, root)
    local dir = path.join(root, "packages", name:sub(1, 1), name)
    if not os.isfile(path.join(dir, "xmake.lua")) then
        raise("keys: %s has no recipe at %s", name, dir)
    end
    local instance = package.load_from_repository(name, dir, {packagefile = path.join(dir, "xmake.lua")})
    local found = {}
    for _, config in ipairs(table.wrap(instance:get("configs"))) do
        if instance:extraconf("configs", config, "readonly") then
            table.insert(found, config .. "=" .. tostring(instance:extraconf("configs", config, "default")))
        end
    end
    table.sort(found)
    local versions = table.orderkeys(instance:get("versions") and instance:get("versions") or {})
    return found, versions[#versions] or "latest"
end

function main(...)
    local root = path.directory(os.scriptdir())
    local names = {...}
    if #names == 0 then
        names = HEAVY
    end
    for _, name in ipairs(names) do
        local found, version = inputs(name, root)
        local key = hash.strhash128(table.concat(table.join({name, version}, found), ";"))
        print("%s %s %s %s", name, version, key, table.concat(found, " "))
    end
end
