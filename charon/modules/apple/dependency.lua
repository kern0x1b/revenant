-- The dependency of a package that is built for the package's own platform and architecture.
--
-- package:dep(name) is keyed by the name of the package, and the ordered dependencies of a package hold the dependencies of
-- all its dependencies, whatever their kind: a host tool in the graph (ldid) brings its own (libplist, openssl of the host),
-- and when the graph also holds the target's openssl the two meet at one key, of which the later wins. A recipe that hands a
-- dependency's folder to CMake or to a linker would hand it the host's build. Take the one of the package's platform.
function target_dependency(package, name)
    for _, dep in ipairs(package:orderdeps() or {}) do
        if dep:name() == name and dep:plat() == package:plat() and dep:arch() == package:arch() then
            return dep
        end
    end
    return package:dep(name)
end
