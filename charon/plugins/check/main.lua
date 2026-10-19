import("core.base.option")
import("core.project.config")
import("core.project.project")
import("@self.checks")

local repository_variables = {"GIT_DIR", "GIT_INDEX_FILE", "GIT_WORK_TREE", "GIT_PREFIX", "GIT_OBJECT_DIRECTORY",
                              "GIT_ALTERNATE_OBJECT_DIRECTORIES", "GIT_COMMON_DIR", "GIT_NAMESPACE"}

local function leave_the_commit_environment()
    local envs = os.getenvs()
    for _, name in ipairs(repository_variables) do
        envs[name] = nil
    end
    os.setenvs(envs)
end

function main()
    if option.get("install-hook") then
        local hooks = os.iorunv("git", {"-C", os.projectdir(), "rev-parse", "--git-path", "hooks"}):trim()
        hooks = path.absolute(hooks, os.projectdir())
        os.mkdir(hooks)
        local hook = path.join(hooks, "pre-commit")
        io.writefile(hook, "#!/bin/sh\ntop=\"$(git rev-parse --show-toplevel)\"\nunset " .. table.concat(repository_variables, " ") .. "\nexec xmake check -P \"$top\" --staged\n")
        os.runv("chmod", {"755", hook})
        cprint("${bright green}hook${clear} %s", hook)
        return
    end
    local files
    if option.get("staged") or option.get("changed") then
        files = checks.changed({staged = option.get("staged")})
    end
    leave_the_commit_environment()
    if files and #files == 0 then
        cprint("${dim}nothing staged or changed, no check to run")
        return
    end
    config.load()
    project.load_targets()
    local wanted = option.get("names")
    local targets = {}
    for _, target in ipairs(project.ordertargets()) do
        if target:rule("@addon/charon/check") or target:values("check.command") or target:values("check.script") then
            if not wanted or table.contains(wanted, target:name()) then
                table.insert(targets, target)
            end
        end
    end
    if #targets == 0 then
        raise("the project declares no check; a check is a target with add_rules(\"@addon/charon/check\") and set_values(\"check.command\", ...)")
    end
    local ran, failed = checks.run(targets, {staged = option.get("staged"), changed = option.get("changed"), files = files})
    if #failed > 0 then
        raise("%d of %d checks failed: %s", #failed, ran, table.concat(failed, ", "))
    end
    if ran == 0 then
        cprint("${dim}no check names a file that changed")
    else
        cprint("${bright green}%d checks passed", ran)
    end
end
