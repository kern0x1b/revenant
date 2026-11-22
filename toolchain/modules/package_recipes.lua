function dependency_flags(dep)
    local fetched = dep:fetch()
    local root = dep:installdir()
    return {
        includedirs = table.wrap(fetched and (fetched.includedirs or fetched.sysincludedirs) or path.join(root, "include")),
        defines = table.wrap(fetched and fetched.defines or dep:get("defines")),
        linkdirs = table.wrap(fetched and fetched.linkdirs or path.join(root, "lib")),
        links = table.wrap(fetched and fetched.links or dep:get("links"))
    }
end

function compat_project(package)
    return path.absolute(path.join(package:builddir(), "compat"))
end

function missing_inventory_error(release, file)
    return string.format("the iOS %s class inventory %s is missing: fill it with ./xmakew firmware --arch=armv7 classes %s, or clone a cache that holds it (docs/guides/machine.md, \"Which cache to clone\"); the generator decides which SDK classes get a proxy from exactly that release's inventory and does not fall back to another one", release, file, release)
end
