import("fixtures")

local RECIPE = [[
package("fakefix")
    set_kind("library")
    set_description("requires sources test")
    add_urls("file://%s")
    add_versions("1.0", "%s")
    add_patches("1.0", "patches/p.patch", "%s")
    on_install(function (package)
        os.cp("a.txt", package:installdir())
    end)
]]

local PLAIN = [[
package("fakeplain")
    set_kind("library")
    set_description("requires sources test, with no patch")
    add_urls("file://%s")
    add_versions("1.0", "%s")
    on_install(function (package)
        os.cp("a.txt", package:installdir())
    end)
]]

local PROJECT = [[
add_repositories("expo %s")
add_requires("fakefix 1.0", "fakeplain 1.0")
target("t")
    set_kind("phony")
    add_packages("fakefix", "fakeplain")
]]

local function patch(content)
    return string.format([[
diff --git a/a.txt b/a.txt
--- a/a.txt
+++ b/a.txt
@@ -1 +1 @@
-base
+%s
]], content)
end

local function origin(folder)
    local repository = path.join(folder, "origin.git")
    os.mkdir(repository)
    io.writefile(path.join(repository, "a.txt"), "base\n")
    local git = function (arguments) os.vrunv("git", table.join({"-C", repository}, arguments)) end
    git({"init", "-q"})
    git({"add", "-A"})
    git({"-c", "user.name=revenant", "-c", "user.email=revenant@example.invalid", "commit", "-q", "-m", "release"})
    return repository, os.iorunv("git", {"-C", repository, "rev-parse", "HEAD"}):trim()
end

function failures(opt)
    local found = {}
    local folder = fixtures.scratch()
    local repository, commit = origin(folder)
    local repo = path.join(folder, "repo")
    local project = path.join(folder, "project")
    local global = path.join(folder, "global")
    local recipedir = path.join(repo, "packages", "f", "fakefix")
    local patchfile = path.join(recipedir, "patches", "p.patch")
    os.mkdir(path.join(recipedir, "patches"))
    os.mkdir(project)
    io.writefile(path.join(project, "xmake.lua"), string.format(PROJECT, repo))
    local plaindir = path.join(repo, "packages", "f", "fakeplain")
    os.mkdir(plaindir)
    io.writefile(path.join(plaindir, "xmake.lua"), string.format(PLAIN, repository, commit))

    local function publish(content)
        io.writefile(patchfile, patch(content))
        io.writefile(path.join(recipedir, "xmake.lua"), string.format(RECIPE, repository, commit, hash.sha256(patchfile)))
    end

    local function configure()
        os.vrunv(os.programfile(), {"f", "-y", "-P", project}, {curdir = project, envs = {XMAKE_GLOBALDIR = global, XMAKE_ADDONS_SOURCEDIRS = "{}"}})
    end

    local function installed_with(content)
        for _, file in ipairs(os.files(path.join(global, "**", "a.txt"))) do
            if not file:find("/source/", 1, true) and io.readfile(file):trim() == content then
                return true
            end
        end
        return false
    end

    publish("patched-1")
    configure()
    if not installed_with("patched-1") then
        table.insert(found, "the first configure installs the package with the patch it names")
    end

    publish("patched-2")
    configure()
    if not installed_with("patched-2") then
        table.insert(found, "a changed patch is installed by the next configure, without cleaning the configuration")
    end

    configure()

    os.tryrm(folder)
    return found
end
