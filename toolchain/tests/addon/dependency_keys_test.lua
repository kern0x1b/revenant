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

local BASE = [[
package("fakeruntime")
    set_kind("library")
    set_description("dependency key test, a runtime whose one configuration matters only to linked images")
    set_policy("package.strict_compatibility", true)
    add_urls("file://%s")
    add_versions("1.0", "%s")
    add_configs("packaged", {description = "Another install name.", default = false, type = "boolean", images_only = true})
    on_install(function (package)
        os.cp("a.txt", package:installdir())
        os.mkdir(package:installdir("lib"))
        io.writefile("runtime.c", "int fake_runtime(void) { return 1; }\n")
        os.vrunv("xcrun", {"clang", "-dynamiclib", "-install_name", "@rpath/libfakeruntime.dylib", "runtime.c", "-o",
                           path.join(package:installdir("lib"), "libfakeruntime.dylib")})
    end)
]]

local LINKS = [[
        io.writefile("image.c", "int fake_runtime(void);\nint fake_image(void) { return fake_runtime(); }\n")
        os.vrunv("xcrun", {"clang", "-dynamiclib", "image.c", "-o", path.join(package:installdir(), "image.dylib"),
                           path.join(package:dep("fakeruntime"):installdir("lib"), "libfakeruntime.dylib")})
]]

local LINKER = [[
package("%s")
    set_kind("library")
    set_description("dependency key test, a package that depends on %s")
    set_policy("package.strict_compatibility", true)
    add_urls("file://%s")
    add_versions("1.0", "%s")
    add_deps("%s")
    %s
    on_install(function (package)
        os.cp("a.txt", package:installdir())
%s
        local log = io.open("%s", "a")
        log:write(package:name() .. "\n")
        log:close()
    end)
]]

local CONSUMER = [[
add_repositories("expo %s")
%s
add_requires("fakestatic 1.0", "fakeover 1.0", "fakeimage 1.0", "fakeshared 1.0", "fakethrough 1.0")
target("t")
    set_kind("phony")
    add_packages("fakestatic", "fakeover", "fakeimage", "fakeshared", "fakethrough")
]]

local NAMESAKE = [[
package("fakenamesake")
    set_kind("library")
    set_description("dependency key test, a dependent whose own configuration is called as the one of its dependency")
    add_urls("file://%s")
    add_versions("1.0", "%s")
    add_configs("variant", {description = "The dependent's own build.", default = false, type = "boolean"})
    add_deps("fakelib")
    on_install(function (package)
        os.cp("a.txt", package:installdir())
        package:setenv("FAKE_BUILT_WITH", "with-" .. tostring(package:dep("fakelib"):config("variant")))
    end)
]]

local READER = [[
package("fakereader")
    set_kind("library")
    set_description("dependency key test, what a package reads of an installed dependency which is a variant")
    set_policy("package.install_always", true)
    add_urls("file://%s")
    add_versions("1.0", "%s")
    add_deps("fakenamesake")
    on_install(function (package)
        os.cp("a.txt", package:installdir())
        local dep = package:dep("fakenamesake")
        local recorded = dep:manifest_load().deps.fakelib.buildhash
        local log = io.open("%s", "a")
        log:write(string.format("%%s %%s %%s\n", recorded == dep:dep("fakelib"):buildhash() and "own" or "other",
                                path.filename(table.wrap(dep:envs().FAKE_BUILT_WITH)[1] or "none"), tostring(dep:dep("fakelib"):config("variant"))))
        log:close()
    end)
]]

local ASKING = [[
add_repositories("expo %s")
%s
add_requires(%s)
target("t")
    set_kind("phony")
    add_packages("%s")
]]

local function namesakes(folder, repo, repository, commit, found)
    local log = path.join(folder, "reader.log")
    local global = path.join(folder, "global-namesake")
    for name, text in pairs({fakenamesake = string.format(NAMESAKE, repository, commit), fakereader = string.format(READER, repository, commit, log)}) do
        local recipedir = path.join(repo, "packages", "f", name)
        os.mkdir(recipedir)
        io.writefile(path.join(recipedir, "xmake.lua"), text)
    end

    local function configure(name, requireconfs, required, used)
        local project = path.join(folder, name)
        os.mkdir(project)
        io.writefile(path.join(project, "xmake.lua"), string.format(ASKING, repo, requireconfs, required, used))
        os.vrunv(os.programfile(), {"f", "-y", "-P", project}, {curdir = project, envs = {XMAKE_GLOBALDIR = global, XMAKE_ADDONS_SOURCEDIRS = "{}"}})
    end

    local function keys()
        local seen = {}
        for _, manifest in ipairs(os.files(path.join(global, ".xmake", "packages", "f", "fakenamesake", "1.0", "*", "manifest.txt"))) do
            seen[path.filename(path.directory(manifest)):match("^%x+")] = true
        end
        return #table.keys(seen)
    end

    local variant = "add_requireconfs(\"**.fakelib\", {configs = {variant = true}})"
    local asked = "\"fakenamesake 1.0\", {configs = {variant = true}}"
    configure("namesake-plain", "", asked, "fakenamesake")
    configure("namesake-variant", variant, asked, "fakenamesake")
    if keys() ~= 2 then
        table.insert(found, string.format("a configuration of a dependency which the project gives under the name and value of one of the dependent: %d keys, wanted 2", keys()))
    end

    local function key(name)
        local files = os.files(path.join(global, ".xmake", "packages", "f", name, "1.0", "*", "manifest.txt"))
        return #files == 1 and path.filename(path.directory(files[1])):match("^%x+") or string.format("%d installs", #files)
    end
    global = path.join(folder, "global-inherited")
    configure("inherited", "", "\"fakemiddle 1.0\", \"fakeapart 1.0\", {configs = {pic = false}}", "fakemiddle")
    if key("fakemiddle") ~= key("fakeapart") then
        table.insert(found, string.format("a configuration the dependency takes from the dependent is no choice of the project's: fakemiddle has %s, a package without dependencies %s", key("fakemiddle"), key("fakeapart")))
    end
    global = path.join(folder, "global-namesake")

    configure("reader-plain", "", "\"fakereader 1.0\"", "fakereader")
    configure("reader-variant", variant, "\"fakereader 1.0\"", "fakereader")
    os.tryrm(log)
    configure("reader-variant-again", variant, "\"fakereader 1.0\"", "fakereader")
    local read = os.isfile(log) and io.readfile(log):trim() or "nothing"
    if read ~= "own with-true true" then
        table.insert(found, string.format("what a package reads of an installed variant of its dependency: \"%s\", wanted \"own with-true true\"", read))
    end
end

local function images(folder, repository, commit, found)
    local repo = path.join(folder, "images")
    local log = path.join(folder, "installs.log")
    local function recipe(name, text)
        local recipedir = path.join(repo, "packages", "f", name)
        os.mkdir(recipedir)
        io.writefile(path.join(recipedir, "xmake.lua"), text)
    end
    local function linker(name, dependency, declaration, links)
        recipe(name, string.format(LINKER, name, dependency, repository, commit, dependency, declaration, links and LINKS or "", log))
    end

    recipe("fakeruntime", string.format(BASE, repository, commit))
    linker("fakestatic", "fakeruntime", "")
    linker("fakeimage", "fakeruntime", "set_policy(\"package.links_dependencies\", true)", true)
    linker("fakeshared", "fakeruntime", "add_configs(\"shared\", {description = \"A shared library.\", default = true, type = \"boolean\"})", true)
    linker("fakeover", "fakeimage", "")
    linker("fakethrough", "fakestatic", "set_policy(\"package.links_dependencies\", true)", true)
    linker("fakeforgetful", "fakeruntime", "", true)

    local packaged = "add_requireconfs(\"**.fakeruntime\", {configs = {packaged = true}})"
    local global
    local function configure(name, requireconfs)
        local project = path.join(folder, name)
        os.mkdir(project)
        io.writefile(path.join(project, "xmake.lua"), string.format(CONSUMER, repo, requireconfs))
        os.vrunv(os.programfile(), {"f", "-y", "-P", project}, {curdir = project, envs = {XMAKE_GLOBALDIR = global, XMAKE_ADDONS_SOURCEDIRS = "{}"}})
    end

    local function manifests(name)
        return os.files(path.join(global, ".xmake", "packages", "f", name, "1.0", "*", "manifest.txt"))
    end

    local function keys(name)
        local seen = {}
        for _, manifest in ipairs(manifests(name)) do
            seen[path.filename(path.directory(manifest)):match("^%x+")] = true
        end
        return #table.keys(seen)
    end

    local function installs()
        local counted = {}
        for line in (os.isfile(log) and io.readfile(log) or ""):gmatch("[^\n]+") do
            counted[line] = (counted[line] or 0) + 1
        end
        return counted
    end

    local function expect(what, wanted)
        local counted = installs()
        for _, name in ipairs({"fakestatic", "fakeover", "fakeimage", "fakeshared", "fakethrough"}) do
            local want = wanted[name]
            if keys(name) ~= want[1] or counted[name] ~= want[2] then
                table.insert(found, string.format("%s: %s has %d keys after %s installs, wanted %d after %d", what, name, keys(name), tostring(counted[name]), want[1], want[2]))
            end
        end
    end

    local once, twice = {1, 1}, {2, 2}
    local both = {fakestatic = once, fakeover = once, fakeimage = twice, fakeshared = twice, fakethrough = twice}

    global = path.join(folder, "global-plain-first")
    configure("images-plain", "")
    expect("a project that changes nothing", {fakestatic = once, fakeover = once, fakeimage = once, fakeshared = once, fakethrough = once})
    configure("images-packaged", packaged)
    expect("a configuration which matters only to images gives a folder of its own to what links one and reinstalls nothing else", both)
    configure("images-plain-again", "")
    configure("images-packaged-again", packaged)
    expect("switching between the two installs nothing again", both)

    local forgetful = path.join(folder, "forgetful")
    os.mkdir(forgetful)
    io.writefile(path.join(forgetful, "xmake.lua"), string.format("add_repositories(\"expo %s\")\nadd_requires(\"fakeforgetful 1.0\")\n", repo))
    global = path.join(folder, "global-forgetful")
    local said
    try { function ()
        os.iorunv(os.programfile(), {"f", "-y", "-P", forgetful}, {curdir = forgetful, envs = {XMAKE_GLOBALDIR = global, XMAKE_ADDONS_SOURCEDIRS = "{}"}})
        said = "installed"
    end, catch { function (errors) said = tostring(errors) end } }
    if #manifests("fakeforgetful") ~= 0 or not said:find("package.links_dependencies", 1, true) then
        table.insert(found, string.format("a package which links a dependency's library and does not say so: %d installs, and the configure said \"%s\"", #manifests("fakeforgetful"), said:sub(-300)))
    end
    os.tryrm(log)
    global = path.join(folder, "global-packaged-first")
    configure("older-packaged", packaged)
    for _, name in ipairs({"fakestatic", "fakeover"}) do
        for _, file in ipairs(manifests(name)) do
            local manifest = io.load(file)
            for _, info in pairs(manifest.deps or {}) do
                info.unlinked = nil
            end
            io.save(file, manifest)
        end
    end
    configure("older-plain", "")
    local counted = installs()
    if counted.fakestatic ~= 1 then
        table.insert(found, string.format("a manifest written before the record of what an image takes: fakestatic was installed %s times, wanted 1", tostring(counted.fakestatic)))
    end
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

    images(folder, repository, commit, found)
    namesakes(folder, repo, repository, commit, found)

    os.tryrm(folder)
    return found
end
