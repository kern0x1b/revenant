import("bundle")
import("shared_runtime")

function publish(package, opt)
    local name = shared_runtime.package_name(opt.kind, package:buildhash())
    local folder = shared_runtime.folder_of(name)
    local leaf = path.filename(opt.library)
    bundle.retarget({opt.library}, {[opt.library] = folder .. "/" .. leaf}, {home = folder .. "/"})
    local needed = shared_runtime.package_name(opt.needs.kind, opt.needs.package:buildhash())
    shared_runtime.stage({packages = {{name = name, version = shared_runtime.package_version(package:buildhash()),
                                       title = opt.title .. " " .. package:buildhash():sub(1, 8), description = opt.description,
                                       depends = {string.format("%s (= %s)", needed, shared_runtime.package_version(opt.needs.package:buildhash()))},
                                       libraries = {}, extra = {{source = opt.library, leaf = leaf}}}},
                          root = path.join(package:installdir("share"), "root"),
                          metadata = path.join(package:installdir("share"), "shared-packages"), strip = {"-x"}})
    package:setenv("REVENANT_SHARED_PACKAGE", name .. "=" .. needed)
end
