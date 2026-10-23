local PACKAGES = {
    Network = "network", CryptoKit = "cryptokit", RealityKit = "realitykit", RealityFoundation = "realityfoundation",
    Spatial = "spatial", CloudKit = "cloudkit", WeatherKit = "weatherkit", UniformTypeIdentifiers = "uniformtypeidentifiers"
}

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
    for _, file in ipairs(target:sourcefiles()) do
        if file:endswith(".swift") then
            for _, module in ipairs(swift_imports(file)) do
                if PACKAGES[module] then
                    wanted[PACKAGES[module]] = "imports " .. module
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
