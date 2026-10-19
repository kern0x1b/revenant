import("core.base.option")
import("core.base.task")
import("core.project.project")

function main()
    task.run("config", {}, {disable_dump = true})
    local name = option.get("package")
    local required = project.required_package(name)
    if not required then
        raise("the project requires no package named %s; it requires %s", name, table.concat(table.orderkeys(project.required_packages()), ", "))
    end
    print(required:installdir())
end
