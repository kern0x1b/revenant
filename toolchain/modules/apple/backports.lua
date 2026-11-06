import("macho")

local PACKAGES = {
    Network = "network", CryptoKit = "cryptokit", RealityKit = "realitykit", RealityFoundation = "realityfoundation",
    Spatial = "spatial", CloudKit = "cloudkit", WeatherKit = "weatherkit", UniformTypeIdentifiers = "uniformtypeidentifiers",
    StoreKit = "storekit", AuthenticationServices = "authenticationservices",
    IOSurface = "iosurface"
}

local FOUNDATION = "backports"

local function swift_imports(file)
    local lines = try { function () return os.iorunv("grep", {"-E", "^[[:space:]]*import[[:space:]]", file}) end } or ""
    local modules = {}
    for module in lines:gmatch("import%s+([%w_]+)") do
        table.insert(modules, module)
    end
    return modules
end

function attach(target, project)
    local wanted = {}
    for _, framework in ipairs(table.wrap(target:get("frameworks"))) do
        if PACKAGES[framework] then
            wanted[PACKAGES[framework]] = "links " .. framework
        end
    end
    local inside = path.absolute(target:scriptdir()):find(path.join("frameworks", "Backports"), 1, true)
    for _, file in ipairs(target:sourcefiles()) do
        if file:endswith(".swift") then
            for _, module in ipairs(swift_imports(file)) do
                if PACKAGES[module] then
                    wanted[PACKAGES[module]] = "imports " .. module
                elseif module == "Foundation" and not inside then
                    wanted[FOUNDATION] = "imports Foundation"
                end
            end
        end
    end
    for name, cause in pairs(wanted) do
        if not target:pkg(name) then
            if not project.required_package(name) then
                raise("target(%s) %s, which is the backport package %s: the project must add_requires(\"revenant@%s\", {alias = \"%s\"})",
                      target:name(), cause, name, name, name)
            end
            target:add("packages", name)
        end
    end
end

function link_orders(backport_links, links)
    local backported = {}
    for _, name in ipairs(backport_links) do
        backported[name] = true
    end
    local orders = {}
    for _, name in ipairs(backport_links) do
        for _, other in ipairs(links) do
            if not backported[other] then
                table.insert(orders, {name, other})
            end
        end
    end
    return orders
end

function weak_frameworks(images)
    local names = {}
    for _, image in ipairs(images) do
        for index, library in ipairs(image.libraries) do
            local name = library:match("^/System/Library/Frameworks/([^/]+)%.framework/")
            if name and not image.library_strength[index] then
                names[name] = true
            end
        end
    end
    return table.orderkeys(names)
end

function linked_images(target)
    local files = {}
    local package = target:pkg("backports")
    if package then
        local folder = path.join(package:installdir(), "share", "root", "usr", "lib", "revenant", "org.revenant.backports")
        for _, name in ipairs(table.wrap(package:get("links"))) do
            table.insert(files, path.join(folder, "lib" .. name .. ".dylib"))
        end
    end
    for _, dependency in ipairs(target:orderdeps()) do
        if dependency:name():endswith("Backports") and dependency:is_shared() then
            table.insert(files, dependency:targetfile())
        end
    end
    local images = {}
    for _, file in ipairs(files) do
        if os.isfile(file) then
            table.insert(images, macho.images(macho.read(file))[1])
        end
    end
    return images
end
