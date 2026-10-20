function target_dependency(package, name)
    for _, dep in ipairs(package:orderdeps() or {}) do
        if dep:name() == name and dep:plat() == package:plat() and dep:arch() == package:arch() then
            return dep
        end
    end
    return package:dep(name)
end
