import("fixtures")

local DIGEST = "revenant-patch-set"
local COMMIT = "8f860345dc590154a0b1c2d3e4f5061728394a5b"
local OTHER = "0123456789abcdef0123456789abcdef01234567"

local RECIPE = [[
package("fake")
    set_kind("library")
    set_description("%s")
    add_urls("https://example.invalid/fake.git")
    add_versions("1.0", "%s")
%s    on_install(function (package)
    end)
]]

local PLAIN = [[
package("plain")
    set_kind("library")
    set_description("%s")
    add_urls("https://example.invalid/plain.git")
    add_versions("1.0", "%s")
    on_install(function (package)
    end)
]]

local LOOSE = [[
package("loose")
    set_kind("library")
    set_description("%s")
    add_urls("https://example.invalid/loose.git")
    add_versions("1.0", "%s")
    add_patches("1.0", "patches/loose.patch")
    on_install(function (package)
    end)
]]

local PATCH_LINE = "    add_patches(\"1.0\", \"patches/fake.patch\", \"%s\")\n"

local PROBE = [[
import("core.package.addon")
import("core.package.package")

-- an argument installs name@version, and pin:name@version also pins it
function main(repo, name, ...)
    for _, arg in ipairs({...}) do
        local spec = arg:match("^pin:(.+)$")
        local addonname, version = (spec or arg):match("^(.-)@(.+)$")
        addon.register(addonname, version, {})
        if spec then
            addon.pin(addonname, version)
        end
    end
    local file = path.join(repo, "packages", "f", name, "xmake.lua")
    local instance = package.load_from_repository(name, path.directory(file), {packagefile = file})
    instance:version_set("1.0")
    instance:_compute_buildhash()
    print("buildhash " .. instance:buildhash())
end
]]

local function root()
    return path.directory(path.directory(path.directory(path.absolute(os.scriptdir()))))
end

local function digest_script()
    return path.join(root(), "tools", "xmake-patchset.sh")
end

local function patch_list(dir, names)
    local lines = {}
    for _, name in ipairs(names) do
        table.insert(lines, name .. " " .. hash.sha256(path.join(dir, name)))
    end
    return table.concat(lines, "\n")
end

local function digest_of(dir, commit, names)
    local out = os.iorunv("sh", {digest_script(), dir, commit, patch_list(dir, names)})
    return (out or ""):trim()
end

local function accepted(dir, commit, names)
    local ok = false
    try
    {
        function ()
            digest_of(dir, commit, names)
            ok = true
        end,
        catch
        {
            function ()
                ok = false
            end
        }
    }
    return ok
end

local function patch_file(dir, name, declared, body)
    local lines = {"From: revenant <revenant@example.invalid>", "Subject: [PATCH] " .. name}
    if declared then
        table.insert(lines, "")
        table.insert(lines, "Changes-build-output: " .. declared)
    end
    table.insert(lines, "")
    table.insert(lines, "---")
    table.insert(lines, body)
    io.writefile(path.join(dir, name), table.concat(lines, "\n") .. "\n")
end

local function key_of(program, envs, repo, name, ...)
    local found = nil
    local args = table.join({"l", path.join(repo, "probe.lua"), repo, name}, {...})
    try
    {
        function ()
            local out = os.iorunv(program, args, {envs = envs})
            found = out:match("buildhash (%x+)")
        end,
        catch
        {
            function (errors)
                found = "failed: " .. tostring(errors)
            end
        }
    }
    return found
end

function failures(opt)
    local found = {}
    local folder = fixtures.scratch()

    local digests = path.join(folder, "digests")
    os.mkdir(digests)
    patch_file(digests, "a.patch", "yes", "a")
    patch_file(digests, "b.patch", "no", "b")
    patch_file(digests, "c.patch", "no", "c")
    local base = digest_of(digests, COMMIT, {"a.patch", "b.patch", "c.patch"})
    if not base:match("^%x+$") then
        table.insert(found, "a patch set with a marked patch gives no digest: " .. base)
    end

    patch_file(digests, "b.patch", "no", "b changed")
    if digest_of(digests, COMMIT, {"a.patch", "b.patch", "c.patch"}) ~= base then
        table.insert(found, "a change to an unmarked patch moved the digest: an unmarked patch must not move any key")
    end

    patch_file(digests, "a.patch", "yes", "a changed")
    if digest_of(digests, COMMIT, {"a.patch", "b.patch", "c.patch"}) == base then
        table.insert(found, "a change to a marked patch did not move the digest")
    end
    patch_file(digests, "a.patch", "yes", "a")

    if digest_of(digests, OTHER, {"a.patch", "b.patch", "c.patch"}) == base then
        table.insert(found, "another xmake commit with the same marked patches did not move the digest")
    end

    patch_file(digests, "a.patch", "no", "a")
    if digest_of(digests, COMMIT, {"a.patch", "b.patch", "c.patch"}) ~= "" then
        table.insert(found, "a patch set with no marked patch gives a digest: that would move every key with no output change")
    end
    patch_file(digests, "a.patch", "yes", "a")

    patch_file(digests, "d.patch", nil, "d")
    if accepted(digests, COMMIT, {"a.patch", "d.patch"}) then
        table.insert(found, "a patch without a Changes-build-output trailer was accepted")
    end

    local repo = path.join(folder, "repo")
    local package = path.join(repo, "packages", "f", "fake")
    local plain = path.join(repo, "packages", "f", "plain")
    os.mkdir(package)
    os.mkdir(path.join(package, "patches"))
    os.mkdir(plain)
    io.writefile(path.join(repo, "probe.lua"), PROBE)
    io.writefile(path.join(package, "patches", "fake.patch"), "first\n")
    io.writefile(path.join(package, "xmake.lua"), RECIPE:format("the fixture", COMMIT,
        PATCH_LINE:format(hash.sha256(path.join(package, "patches", "fake.patch")))))
    io.writefile(path.join(plain, "xmake.lua"), PLAIN:format("the plain fixture", COMMIT))
    local loose = path.join(repo, "packages", "f", "loose")
    os.mkdir(path.join(loose, "patches"))
    io.writefile(path.join(loose, "patches", "loose.patch"), "first\n")
    io.writefile(path.join(loose, "xmake.lua"), LOOSE:format("the loose fixture", COMMIT))

    local store = path.join(folder, "store")
    os.mkdir(store)
    local envs = {XMAKE_GLOBALDIR = store}
    local program = os.programfile()
    local prefix = path.directory(path.directory(program))

    local function binary_with(name, value)
        local copy = path.join(folder, name)
        os.cp(prefix, copy)
        local file = path.join(copy, "share", "xmake", DIGEST)
        if value then
            io.writefile(file, value .. "\n")
        else
            os.rm(file)
        end
        return path.join(copy, "bin", "xmake")
    end

    local digest = io.readfile(path.join(prefix, "share", "xmake", DIGEST)):trim()
    local recipe_text = io.readfile(path.join(root(), "packages", "x", "xmake", "xmake.lua"))
    local recipe_commit = recipe_text:match('add_versions%("[^"]*", "(%x+)"%)')
    local recipe_patches = {}
    for name in recipe_text:gmatch('{"([^"]+%.patch)"') do
        table.insert(recipe_patches, name)
    end
    local recipe_dir = path.join(root(), "packages", "x", "xmake", "patches")
    local expected = digest_of(recipe_dir, recipe_commit, recipe_patches)
    if digest ~= expected then
        table.insert(found, "the binary's patch set digest " .. digest .. " is not the digest of the recipe's marked patches " .. expected .. ": the binary was built from other patches")
    end

    local original = key_of(program, envs, repo, "fake")
    local same = key_of(binary_with("same", digest), envs, repo, "fake")
    local other = key_of(binary_with("other", OTHER), envs, repo, "fake")
    local empty = key_of(binary_with("empty", ""), envs, repo, "fake")
    local bare = key_of(binary_with("bare", nil), envs, repo, "fake")

    local function computed(label, key)
        if not key or not key:match("^%x+$") then
            table.insert(found, label .. " did not compute a build hash: " .. tostring(key))
            return false
        end
        return true
    end
    computed("the original binary", original)
    computed("a binary with the same patch set", same)
    computed("a binary with another patch set", other)
    computed("a binary whose patch set digest is empty", empty)
    if same ~= original then
        table.insert(found, "a copy of the binary with the same patch set keys the fixture as " .. tostring(same) .. ", not " .. tostring(original))
    end
    if other == original then
        table.insert(found, "a binary with another patch set keys the fixture as the original binary: a marked patch does not move the key")
    end
    if not bare or not bare:find("patch set digest", 1, true) then
        table.insert(found, "a binary without the patch set digest did not refuse to compute a build hash: " .. tostring(bare))
    end

    local fake_then = key_of(program, envs, repo, "fake")
    local plain_then = key_of(program, envs, repo, "plain")
    io.writefile(path.join(package, "patches", "fake.patch"), "second\n")
    io.writefile(path.join(package, "xmake.lua"), RECIPE:format("the fixture", COMMIT,
        PATCH_LINE:format(hash.sha256(path.join(package, "patches", "fake.patch")))))
    local fake_patched = key_of(program, envs, repo, "fake")
    local plain_patched = key_of(program, envs, repo, "plain")
    io.writefile(path.join(package, "xmake.lua"), RECIPE:format("a description the patch does not cover", COMMIT,
        PATCH_LINE:format(hash.sha256(path.join(package, "patches", "fake.patch")))))
    local fake_described = key_of(program, envs, repo, "fake")

    computed("the fixture with patches", fake_then)
    computed("the fixture with a patch changed", fake_patched)
    computed("the fixture with a description changed", fake_described)
    computed("the fixture without patches", plain_then)
    computed("the fixture without patches after another package's patch changed", plain_patched)

    local loose_then = key_of(program, envs, repo, "loose")
    io.writefile(path.join(loose, "patches", "loose.patch"), "second\n")
    local loose_patched = key_of(program, envs, repo, "loose")
    io.writefile(path.join(loose, "xmake.lua"), LOOSE:format("another description", COMMIT))
    local loose_described = key_of(program, envs, repo, "loose")
    computed("the fixture with a patch declared without a sha256", loose_then)
    computed("the fixture with such a patch changed", loose_patched)
    computed("the fixture with such a patch and a new description", loose_described)
    if loose_patched == loose_then then
        table.insert(found, "a patch declared without a sha256 that changed keeps its build hash: its file must be in the key")
    end
    if loose_described ~= loose_patched then
        table.insert(found, "a change to the description of a package with such a patch moved its build hash")
    end

    if fake_patched == fake_then then
        table.insert(found, "a package whose applied patch changed keeps its build hash: the patch set must be in the key")
    end

    -- the addons which a project pins are in the key: a build under another version is another build,
    -- an installed addon which the project does not pin and an addon from a folder of the project are not.
    -- The fixture is in its last state here, so fake_described is the key it has without any addon
    local source = path.join(folder, "srcaddon")
    os.mkdir(path.join(source, "plugins"))
    io.writefile(path.join(source, "addon.lua"), "addon(\"srcaddon\")\n    set_description(\"a fixture\")\n")
    local idle = key_of(program, envs, repo, "fake", "idle@1.0.0")
    local pinned_1 = key_of(program, envs, repo, "fake", "pin:pinned@1.0.0")
    local pinned_2 = key_of(program, envs, repo, "fake", "pin:pinned@2.0.0")
    local sourced_envs = {XMAKE_GLOBALDIR = store, XMAKE_ADDONS_SOURCEDIRS = string.serialize({srcaddon = source}, {strip = true, indent = false})}
    local sourced = key_of(program, sourced_envs, repo, "fake", "pin:srcaddon@latest")
    computed("the fixture with an installed addon which no project pins", idle)
    computed("the fixture with a pinned addon", pinned_1)
    computed("the fixture with another version of the pinned addon", pinned_2)
    computed("the fixture with an addon from a folder which is pinned", sourced)
    if idle ~= fake_described then
        table.insert(found, "an installed addon which the project does not pin moved the build hash: only the pinned versions may move it")
    end
    if pinned_1 == fake_described then
        table.insert(found, "a pinned addon keeps the build hash of the fixture without it: a build under another addon version is another build")
    end
    if pinned_2 == pinned_1 then
        table.insert(found, "another version of a pinned addon keeps its build hash: the version a build runs under must be in the key")
    end
    if sourced ~= fake_described then
        table.insert(found, "an addon from a folder of the project moved the build hash: it has no version to pin")
    end
    if fake_described ~= fake_patched then
        table.insert(found, "a change to a package's description moved its build hash: only its patch set may move the key")
    end
    if plain_patched ~= plain_then then
        table.insert(found, "a package without patches moved when another package's patch changed")
    end

    os.tryrm(folder)
    return found
end
