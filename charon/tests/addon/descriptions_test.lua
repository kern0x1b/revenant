import("fixtures")
import("core.package.package")

function failures(opt)
    local found = {}
    local packages = path.join(opt.modules, "..", "packages")
    for _, recipe in ipairs(os.files(path.join(packages, "*", "*", "xmake.lua"))) do
        local root = path.directory(recipe)
        local name = path.filename(root)
        local instance, errors
        local raised = fixtures.refusal(function () instance, errors = package.load_from_repository(name, root) end)
        if not instance then
            table.insert(found, string.format("the description of package %s must load through the package interpreter, and it answered: %s",
                                              name, tostring(raised or errors or "no package")))
        end
    end
    return found
end
