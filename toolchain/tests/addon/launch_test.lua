import("fixtures")

local function stripped(text)
    return (text:gsub("\27%[[%d;]*m", ""))
end

local function mentions(text, ...)
    for _, needle in ipairs({...}) do
        if not text or not text:find(needle, 1, true) then
            return false
        end
    end
    return true
end

local function started(project, envs, log)
    local status = os.execv(os.programfile(), {"show", "-P", project, "-l", "targets"}, {try = true, curdir = project, stdout = log, stderr = log, envs = envs})
    return status, stripped(io.readfile(log) or "")
end

function failures(opt)
    local found = {}
    local launch = import("launch", {rootdir = opt.modules, anonymous = true})
    local folder = fixtures.scratch()
    local checkout = path.join(folder, "checkout")
    local launcher = path.join(checkout, "xmakew")

    for _, unset in ipairs({"", false}) do
        local problem = launch.launch_problem({checkout = checkout, store = unset or nil, globaldir = path.join(folder, "gd"), ceilings = folder})
        if not mentions(problem, "REVENANT_STORE is unset", launcher) then
            table.insert(found, "an xmake started without REVENANT_STORE, as an older xmakew starts it, is refused, naming the xmakew to start the build with: " .. tostring(problem))
        end
    end

    local clean = path.join(folder, "clean")
    os.mkdir(path.join(clean, "xmake-global"))
    local ordinary = launch.launch_problem({checkout = checkout, store = clean, globaldir = path.join(clean, "xmake-global"), ceilings = clean})
    if ordinary then
        table.insert(found, "a store kept out of reach of git by the ceiling of xmakew is accepted: " .. ordinary)
    end
    local unset_ceiling = launch.launch_problem({checkout = checkout, store = clean, globaldir = path.join(clean, "xmake-global"), ceilings = clean .. ":" .. path.join(folder, "elsewhere")})
    if unset_ceiling then
        table.insert(found, "a ceiling among several is found: " .. unset_ceiling)
    end

    local repository = path.join(folder, "repository")
    os.mkdir(path.join(repository, ".git"))
    local inside = path.join(repository, "store", "xmake-global")
    local problem = launch.launch_problem({checkout = checkout, store = path.join(repository, "store"), globaldir = inside, ceilings = ""})
    if not mentions(problem, inside, repository, "git apply", launcher) then
        table.insert(found, "a store inside a git work tree with no ceiling is refused, naming the folders and the cause: " .. tostring(problem))
    end
    if launch.work_tree_of(path.join(inside, ".xmake", "cache", "packages"), nil) ~= repository then
        table.insert(found, "the work tree of a folder that does not exist yet is the repository above it")
    end
    local elsewhere = launch.launch_problem({checkout = checkout, store = path.join(repository, "store"), globaldir = inside, ceilings = path.join(folder, "elsewhere") .. ":" .. folder})
    if not mentions(elsewhere, repository) then
        table.insert(found, "ceilings that are not between the store and the repository do not hide it: " .. tostring(elsewhere))
    end
    for label, ceiling in pairs({["the store"] = path.join(repository, "store"), ["the global folder itself"] = inside,
                                 ["the store among others"] = path.join(folder, "elsewhere") .. ":" .. path.join(repository, "store")}) do
        local accepted = launch.launch_problem({checkout = checkout, store = path.join(repository, "store"), globaldir = inside, ceilings = ceiling})
        if accepted then
            table.insert(found, "a ceiling at " .. label .. " keeps git from the work tree above it, as it does for git apply: " .. accepted)
        end
    end

    local linked = path.join(folder, "linked")
    os.mkdir(linked)
    io.writefile(path.join(linked, ".git"), "gitdir: /elsewhere/.git/worktrees/linked\n")
    local linked_problem = launch.launch_problem({checkout = checkout, store = linked, globaldir = path.join(linked, "xmake-global"), ceilings = ""})
    if not mentions(linked_problem, linked) then
        table.insert(found, "a linked worktree, whose .git is a file, is a work tree too: " .. tostring(linked_problem))
    end

    local repository_root = path.directory(path.directory(path.absolute(opt.modules)))
    local project = path.join(folder, "project")
    os.mkdir(project)
    io.writefile(path.join(project, "xmake.lua"), "add_addons(\"revenant\", {sourcedir = \"" .. path.join(repository_root, "toolchain") .. "\"})\nincludes(\"@addon/revenant/apple-ios\")\n")
    local log = path.join(folder, "start.log")
    local store = path.join(folder, "store")
    local status, output = started(project, {REVENANT_STORE = ""}, log)
    if status == 0 or not mentions(output, "REVENANT_STORE is unset", path.join(repository_root, "xmakew")) then
        table.insert(found, "a project that includes the apple-ios toolchain does not load when its xmake was not started by the xmakew of the checkout: " .. tostring(status) .. "\n" .. output)
    end
    local gitproject = path.join(folder, "gitproject")
    os.mkdir(path.join(gitproject, ".git"))
    status, output = started(project, {REVENANT_STORE = store, XMAKE_GLOBALDIR = path.join(gitproject, "xmake-global"), GIT_CEILING_DIRECTORIES = ""}, log)
    if status == 0 or not mentions(output, "git apply", gitproject) then
        table.insert(found, "a project does not load when the packages would be unpacked inside a git work tree: " .. tostring(status) .. "\n" .. output)
    end
    status, output = started(project, {REVENANT_STORE = store, XMAKE_GLOBALDIR = path.join(store, "xmake-global"), GIT_CEILING_DIRECTORIES = store}, log)
    if status ~= 0 then
        table.insert(found, "a project loads when xmakew started its xmake, with the store out of reach of git: " .. output)
    end

    os.tryrm(folder)
    return found
end
