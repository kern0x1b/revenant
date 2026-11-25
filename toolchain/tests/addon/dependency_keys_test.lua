import("fixtures")

local LIB = [[
package("fakelib")
    set_kind("library")
    set_description("dependency key test, a dependency its dependents are only compatible with as it was built")
    set_policy("package.strict_compatibility", true)
    add_urls("file://%s")
    add_versions("1.0", "%s")
    add_configs("variant", {description = "Another build of the library.", default = false, type = "boolean"})
    add_configs("sdk", {description = "A name the project gives, with no default.", type = "string"})
    on_install(function (package)
        os.cp("a.txt", package:installdir())
        io.writefile(path.join(package:installdir(), "seen.txt"), tostring(package:config("variant")))
    end)
]]

local USER = [[
package("%s")
    set_kind("library")
    set_description("dependency key test, a package that depends on %s")
    add_urls("file://%s")
    add_versions("1.0", "%s")
    %s
    on_install(function (package)
        os.cp("a.txt", package:installdir())
        io.writefile(path.join(package:installdir(), "seen.txt"), tostring(package:dep("%s"):config("variant")))
    end)
]]

local APART = [[
package("fakeapart")
    set_kind("library")
    set_description("dependency key test, a package that depends on nothing")
    add_urls("file://%s")
    add_versions("1.0", "%s")
    on_install(function (package)
        os.cp("a.txt", package:installdir())
    end)
]]

local PROJECT = [[
add_repositories("expo %s")
%s
add_requires("faketop 1.0", "fakemiddle 1.0", "fakegiven 1.0", "fakeapart 1.0")
target("t")
    set_kind("phony")
    add_packages("faketop", "fakemiddle", "fakegiven", "fakeapart")
    on_build(function (target)
        local file = path.join(target:pkg("fakemiddle"):installdir(), "seen.txt")
        io.writefile(path.join(os.projectdir(), "got.txt"), os.isfile(file) and io.readfile(file) or "-")
    end)
]]

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
    local global = path.join(folder, "global")

    local function recipe(name, text)
        local recipedir = path.join(repo, "packages", "f", name)
        os.mkdir(recipedir)
        io.writefile(path.join(recipedir, "xmake.lua"), text)
    end

    local function user(name, dependency, declaration)
        recipe(name, string.format(USER, name, dependency, repository, commit, declaration, dependency))
    end

    recipe("fakelib", string.format(LIB, repository, commit))
    recipe("fakeapart", string.format(APART, repository, commit))
    user("fakemiddle", "fakelib", "on_load(function (package)\n        package:add(\"deps\", \"fakelib\")\n    end)")
    user("faketop", "fakemiddle", "add_deps(\"fakemiddle\")")
    user("fakegiven", "fakelib", "add_deps(\"fakelib\", {configs = {variant = true}})")

    local function environment()
        return {XMAKE_GLOBALDIR = global, XMAKE_ADDONS_SOURCEDIRS = "{}"}
    end

    local function configure(name, requireconfs)
        local project = path.join(folder, name)
        os.mkdir(project)
        io.writefile(path.join(project, "xmake.lua"), string.format(PROJECT, repo, requireconfs))
        os.vrunv(os.programfile(), {"f", "-y", "-P", project}, {curdir = project, envs = environment()})
    end

    local function built(name)
        local project = path.join(folder, name)
        os.vrunv(os.programfile(), {"build", "-y", "-P", project}, {curdir = project, envs = environment()})
        local file = path.join(project, "got.txt")
        return os.isfile(file) and io.readfile(file):trim() or "nothing"
    end

    local function installs(name)
        local order, values = {}, {}
        for _, manifest in ipairs(os.files(path.join(global, ".xmake", "packages", "f", name, "1.0", "*", "manifest.txt"))) do
            local key = path.filename(path.directory(manifest)):match("^%x+")
            local file = path.join(path.directory(manifest), "seen.txt")
            local value = os.isfile(file) and io.readfile(file):trim() or "-"
            if not values[key] then
                values[key] = {}
                table.insert(order, key)
            end
            if not table.contains(values[key], value) then
                table.insert(values[key], value)
            end
        end
        local seen = {}
        for _, key in ipairs(order) do
            table.sort(values[key])
            table.insert(seen, table.concat(values[key], ","))
        end
        table.sort(seen)
        table.sort(order)
        return table.concat(seen, " "), table.concat(order, " ")
    end

    local function count()
        return #os.files(path.join(global, ".xmake", "packages", "f", "*", "1.0", "*", "manifest.txt"))
    end

    local function expect(name, wanted, what)
        local got = installs(name)
        if got ~= wanted then
            table.insert(found, string.format("%s: %s is installed as \"%s\", wanted \"%s\"", what, name, got, wanted))
        end
    end

    local variant = "add_requireconfs(\"**.fakelib\", {configs = {variant = true}})"
    configure("plain", "")
    local _, apart = installs("fakeapart")
    for _, name in ipairs({"fakemiddle", "faketop", "fakegiven"}) do
        local _, key = installs(name)
        if key ~= apart then
            table.insert(found, string.format("with nothing changed by the project %s has the key of a package without dependencies: it has %s, not %s", name, key, apart))
        end
    end

    configure("variant", variant)
    expect("fakemiddle", "false true", "a project that changes a configuration of a dependency installs the dependent beside the plain one")
    expect("faketop", "nil nil", "the dependents of a dependent follow it")
    expect("fakegiven", "true", "a configuration the package itself asks of its dependency does not move its key")
    expect("fakeapart", "-", "a package without the dependency keeps its key")

    local installed = count()
    configure("plain-again", "")
    configure("variant-again", variant)
    if count() ~= installed then
        table.insert(found, string.format("two projects that differ in a configuration of a dependency keep reinstalling its dependents: %d installs became %d", installed, count()))
    end

    for _, row in ipairs({{"plain", "false"}, {"variant", "true"}, {"plain-again", "false"}}) do
        local got = built(row[1])
        if got ~= row[2] then
            table.insert(found, string.format("the build of %s reads the dependent built with variant=%s, wanted variant=%s", row[1], got, row[2]))
        end
    end

    configure("named", "add_requireconfs(\"**.fakelib\", {configs = {sdk = \"one\"}})")
    expect("fakemiddle", "false true", "a configuration with no default does not move the keys of the dependents")

    os.tryrm(folder)
    return found
end
