import("core.base.task")
import("apple.platform")

function failures(opt)
    local found = {}

    task.run("config", {}, {disable_dump = true})
    import("apple.platform")

    local libsql = opt.libsql
    if not libsql then
        table.insert(found, "libsql package not provided to test")
        return found
    end

    local lib = path.join(libsql:installdir("lib"), "liblibsql.a")
    if not os.isfile(lib) then
        table.insert(found, "liblibsql.a not found at " .. lib)
        return found
    end

    local dyld = import("@addon.revenant.apple.dyld", {anonymous = true})
    local provided = {"apple-compat"}
    local missing = dyld.check(lib, provided, libsql:installdir(), {release = "6.0", platform = "ios", arch = "armv7"})
    if missing and #missing > 0 then
        table.insert(found, "liblibsql.a has missing imports for iOS 6.0: " .. table.concat(missing, ", "))
    end

    return found
end