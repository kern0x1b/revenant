import("fixtures")
import("core.package.package")

-- A package description is Lua the package interpreter runs while it loads the
-- repository, before anything is configured or built, and that interpreter
-- offers none of the project-scope calls: an import() at the top of a recipe,
-- or any other slip that only shows when the description is evaluated, breaks
-- the config of every port that requires the package, yet builds nothing here
-- and so passes a suite that never loads a description. This asks xmake to load
-- every recipe in the repository the way a consuming port would, and fails the
-- one that does not answer.
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
