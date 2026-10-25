import("fixtures")

local RECIPE = [[
package("fixpatch")
    set_kind("library")
    add_urls("%s")
    add_versions("1.0", "%s")
    add_patches("1.0", "%s", "%s")
    add_configs("recipe", {description = "The digest of this recipe and its patch.", default = "%s", type = "string", readonly = true})
    on_install(function (package)
        os.cp("value.txt", package:installdir())
    end)
    on_test(function (package)
        assert(io.readfile(package:installdir("value.txt")) == "%s\n", "value.txt is not the value of the recipe's patch")
    end)
]]

local PATCH = [[
diff --git a/value.txt b/value.txt
--- a/value.txt
+++ b/value.txt
@@ -1 +1 @@
-base
+%s
]]

local function git(folder, argv)
    return os.iorunv("git", table.join({"-C", folder, "-c", "user.name=revenant", "-c", "user.email=revenant@example.invalid"}, argv))
end

local function installed_value(project)
    for _, file in ipairs(os.files(path.join(project, ".xmake", "**", "cache", "package"))) do
        local installdir = (io.readfile(file) or ""):match('installdir = "([^"]+)"')
        if installdir then
            return io.readfile(path.join(installdir, "value.txt"))
        end
    end
end

function failures(opt)
    local found = {}
    local folder = fixtures.scratch()

    local upstream = path.join(folder, "upstream.git")
    os.mkdir(upstream)
    git(upstream, {"init", "-q"})
    io.writefile(path.join(upstream, "value.txt"), "base\n")
    git(upstream, {"add", "value.txt"})
    git(upstream, {"commit", "-q", "-m", "base"})
    local commit = (git(upstream, {"rev-parse", "HEAD"}) or ""):trim()

    local recipes = {}
    for _, name in ipairs({"a", "b"}) do
        local value = "patched by " .. name
        local patchfile = path.join(folder, "patch-" .. name .. ".patch")
        io.writefile(patchfile, PATCH:format(value))
        local repo = path.join(folder, "repo-" .. name)
        local package = path.join(repo, "packages", "f", "fixpatch")
        os.mkdir(package)
        local digest = hash.strhash128(table.concat({commit, hash.sha256(patchfile)}, ";"))
        io.writefile(path.join(package, "xmake.lua"), RECIPE:format(upstream, commit, patchfile, hash.sha256(patchfile), digest, value))
        local project = path.join(folder, "project-" .. name)
        os.mkdir(project)
        io.writefile(path.join(project, "xmake.lua"), table.concat({
            "add_repositories(\"" .. name .. " " .. repo .. "\")",
            "add_requires(\"" .. name .. "@fixpatch\", {alias = \"fixpatch\"})",
            "target(\"nop\")",
            "    set_kind(\"phony\")",
            "    add_packages(\"fixpatch\")",
            ""
        }, "\n"))
        table.insert(recipes, {name = name, project = project, value = value})
    end

    local store = path.join(folder, "store")
    os.mkdir(store)
    local envs = {XMAKE_GLOBALDIR = store, XMAKE_MAIN_REPO = fixtures.empty_repository(folder)}
    for _, recipe in ipairs(recipes) do
        local log = path.join(folder, recipe.name .. ".log")
        local ok = os.execv(os.programfile(), {"require", "-y"}, {curdir = recipe.project, try = true,
                                                                  stdout = log, stderr = log, envs = envs})
        if ok ~= 0 then
            table.insert(found, "the install from " .. recipe.name .. " failed: " .. (io.readfile(log) or ""))
        else
            local seen = installed_value(recipe.project)
            if seen ~= recipe.value .. "\n" then
                table.insert(found, "the project of " .. recipe.name .. " installed value.txt " .. tostring(seen) ..
                    " and not " .. recipe.value .. ": it used a patched source or install of another recipe")
            end
        end
    end

    os.tryrm(folder)
    return found
end
