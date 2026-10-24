import("fixtures")

local DIGEST = "revenant-patch-set"

local RECIPE = [[
package("fake")
    set_kind("library")
    set_description("%s")
    add_urls("https://example.invalid/fake.git")
    add_versions("1.0", "8f860345dc590154a0b1c2d3e4f5061728394a5b")
    on_install(function (package)
    end)
]]

local PROBE = [[
import("core.package.package")

function main(repo)
    local file = path.join(repo, "packages", "f", "fake", "xmake.lua")
    local instance = package.load_from_repository("fake", path.directory(file), {packagefile = file})
    instance:_compute_buildhash()
    print("buildhash " .. instance:buildhash())
end
]]

local function key_of(program, envs, probe, repo)
    local found = nil
    try
    {
        function ()
            local out = os.iorunv(program, {"l", probe, repo}, {envs = envs})
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
    local prefix = path.directory(path.directory(os.programfile()))
    local probe = path.join(folder, "probe.lua")
    io.writefile(probe, PROBE)
    local repo = path.join(folder, "repo")
    local package = path.join(repo, "packages", "f", "fake")
    os.mkdir(package)
    local function recipe(description)
        io.writefile(path.join(package, "xmake.lua"), RECIPE:format(description))
    end
    recipe("the fixture")

    local store = path.join(folder, "store")
    os.mkdir(store)
    local envs = {XMAKE_GLOBALDIR = store}

    local function binary_with(name, digest)
        local copy = path.join(folder, name)
        os.cp(prefix, copy)
        local file = path.join(copy, "share", "xmake", DIGEST)
        if digest then
            io.writefile(file, digest .. "\n")
        else
            os.rm(file)
        end
        return path.join(copy, "bin", "xmake")
    end

    local digest = io.readfile(path.join(prefix, "share", "xmake", DIGEST)):trim()
    local original = key_of(os.programfile(), envs, probe, repo)
    local same = key_of(binary_with("same", digest), envs, probe, repo)
    local other = key_of(binary_with("other", "0123456789abcdef"), envs, probe, repo)
    local bare = key_of(binary_with("bare", nil), envs, probe, repo)

    recipe("a description that the patch set does not cover")
    local described = key_of(os.programfile(), envs, probe, repo)

    if not original or not original:match("^%x+$") then
        table.insert(found, "the original binary did not compute a build hash: " .. tostring(original))
    end
    if same ~= original then
        table.insert(found, "a copy of the binary with the same patch set keys the fixture as " .. tostring(same) .. ", not " .. tostring(original))
    end
    if other == original then
        table.insert(found, "a binary with another patch set keys the fixture as the original binary: a package does not move with the xmake patch set")
    end
    if described ~= original then
        table.insert(found, "a change to the fixture's description moved its build hash: the key must move with the patch set alone")
    end
    if not bare or not bare:find("patch set digest", 1, true) then
        table.insert(found, "a binary without the patch set digest did not refuse to compute a build hash: " .. tostring(bare))
    end

    os.tryrm(folder)
    return found
end
