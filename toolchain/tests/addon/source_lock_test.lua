import("fixtures")
import("core.base.process")

local PATCH = "diff --git a/data.txt b/data.txt\n--- a/data.txt\n+++ b/data.txt\n@@ -1 +1 @@\n-pristine\n+patched\n"

local PACKAGE = [[
package("racefix")
    set_kind("library")
    add_urls("%s")
    add_versions("1.0", "%s")
    add_configs("variant", {description = "the build of the package that this process installs", default = "a", type = "string"})
    on_download(function (package, opt)
        local checkout = import("checkout", {rootdir = "%s", anonymous = true})
        checkout.pinned(opt.sourcedir, {{url = opt.url, tag = "release-1", commit = package:revision(opt.url_alias) or package:commit()}})
        io.writefile(path.join(os.getenv("RACE_MARKERS"), package:config("variant") .. ".downloaded"), "downloaded")
    end)
    on_install(function (package)
        %s
        local markers = os.getenv("RACE_MARKERS")
        local variant = package:config("variant")
        local other = variant == "a" and "b" or "a"
        local held = 0
        while variant == "b" and not os.isfile(path.join(markers, "a.seen")) and held < 90000 do
            os.sleep(100)
            held = held + 100
        end
        os.vrunv("git", {"apply", path.join(package:scriptdir(), "patches", "fix.patch")})
        io.writefile(path.join(markers, variant .. ".patched"), "patched")
        local waited = 0
        while not os.isfile(path.join(markers, other .. ".downloaded")) and waited < 90000 do
            os.sleep(100)
            waited = waited + 100
        end
        io.writefile(path.join(markers, variant .. ".seen"), io.readfile("data.txt"))
        io.writefile(path.join(package:installdir("include"), "racefix.h"), "int racefix(void);\n")
    end)
]]

local IN_PLACE = ""
local KEYED = [[os.cd(import("checkout", {rootdir = "%s", anonymous = true}).keyed(os.curdir(), package:buildhash()))]]

local function origin(folder)
    local repository = path.join(folder, "origin")
    os.mkdir(repository)
    io.writefile(path.join(repository, "data.txt"), "pristine\n")
    local git = function (arguments) os.vrunv("git", table.join({"-C", repository}, arguments)) end
    git({"init", "-q"})
    git({"add", "-A"})
    git({"-c", "user.name=revenant", "-c", "user.email=revenant@example.invalid", "commit", "-q", "-m", "release"})
    git({"tag", "release-1"})
    return "file://" .. repository, os.iorunv("git", {"-C", repository, "rev-parse", "HEAD"}):trim()
end

local function project_of(folder, repo, variant)
    local project = path.join(folder, "project-" .. variant)
    os.mkdir(project)
    io.writefile(path.join(project, "xmake.lua"), table.concat({
        "add_repositories(\"fake " .. repo .. "\")",
        "add_requires(\"fake@racefix\", {alias = \"racefix\", configs = {variant = \"" .. variant .. "\"}})",
        "target(\"nop\")",
        "    set_kind(\"phony\")",
        "    add_packages(\"racefix\")",
        ""
    }, "\n"))
    return project
end

local function waited_for(file, limit)
    local waited = 0
    while not os.isfile(file) and waited < limit do
        os.sleep(100)
        waited = waited + 100
    end
    return os.isfile(file)
end

local function spawn(folder, project, envs, name)
    local done = path.join(folder, name .. ".done")
    local log = path.join(folder, name .. ".log")
    local wrapper = path.join(folder, name .. ".sh")
    io.writefile(wrapper, "#!/bin/sh\n\"$@\"\necho $? > \"$DONE\"\n")
    os.execv("chmod", {"755", wrapper})
    local environment = {}
    for key, value in pairs(table.join(os.getenvs(), envs, {DONE = done})) do
        table.insert(environment, key .. "=" .. value)
    end
    local child = process.openv(wrapper, {os.programfile(), "require", "-y", "-P", project},
                                {envs = environment, curdir = project, stdout = log, stderr = log})
    return {child = child, done = done, log = log}
end

local function finish(run, limit)
    local ended = waited_for(run.done, limit)
    run.child:close()
    local status = ended and io.readfile(run.done):trim() or nil
    return status, io.readfile(run.log) or ""
end

local function two_builds(opt, prelude)
    local report = {errors = {}, seen = {}}
    local folder = fixtures.scratch()
    local url, commit = origin(folder)
    local repo = path.join(folder, "repo")
    local package = path.join(repo, "packages", "r", "racefix")
    os.mkdir(path.join(package, "patches"))
    io.writefile(path.join(package, "patches", "fix.patch"), PATCH)
    io.writefile(path.join(package, "xmake.lua"), PACKAGE:format(url, commit, opt.modules, prelude))
    local store = path.join(folder, "store")
    local markers = path.join(folder, "markers")
    os.mkdir(store)
    os.mkdir(markers)
    local envs = {XMAKE_GLOBALDIR = store, XMAKE_MAIN_REPO = fixtures.empty_repository(folder), RACE_MARKERS = markers}

    local first = spawn(folder, project_of(folder, repo, "a"), envs, "a")
    if not waited_for(path.join(markers, "a.patched"), 120000) then
        table.insert(report.errors, "the first install did not reach its patch step: " .. (io.readfile(first.log) or ""))
    end
    local second = spawn(folder, project_of(folder, repo, "b"), envs, "b")
    local first_status, first_log = finish(first, 120000)
    local second_status, second_log = finish(second, 120000)
    if first_status ~= "0" then
        table.insert(report.errors, "the first install of the package did not succeed (" .. tostring(first_status) .. "): " .. first_log)
    end
    if second_status ~= "0" then
        table.insert(report.errors, "the second install of the package did not succeed (" .. tostring(second_status) .. "): " .. second_log)
    end
    for _, variant in ipairs({"a", "b"}) do
        local seen = path.join(markers, variant .. ".seen")
        report.seen[variant] = os.isfile(seen) and io.readfile(seen) or nil
    end
    os.tryrm(folder)
    return report
end

function failures(opt)
    local found = {}

    local control = two_builds(opt, IN_PLACE)
    for _, line in ipairs(control.errors) do
        table.insert(found, "the control, which builds in the shared source folder: " .. line)
    end
    if control.seen.a == "patched\n" and control.seen.b == "patched\n" then
        table.insert(found, "the control, which builds in the shared source folder, saw both builds patched: the race this test stands for did not happen, so a pass proves nothing")
    end

    local keyed = two_builds(opt, KEYED:format(opt.modules))
    for _, line in ipairs(keyed.errors) do
        table.insert(found, line)
    end
    for _, variant in ipairs({"a", "b"}) do
        if keyed.seen[variant] ~= "patched\n" then
            table.insert(found, "the install of build " .. variant .. " compiled the source as " .. string.format("%q", tostring(keyed.seen[variant])) ..
                ", not patched: another process's download of the same package reset the source folder this one was building in")
        end
    end
    return found
end
