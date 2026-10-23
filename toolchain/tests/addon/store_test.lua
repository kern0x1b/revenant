import("fixtures")
import("core.base.process")

local PACKAGE = [[
package("fakeinstall")
    set_kind("library")
    on_install(function (package)
        if os.getenv("FAKE_FAIL") then
            raise("the fake install fails on request")
        end
        local generation = os.getenv("FAKE_GENERATION") or "old"
        local payload = package:installdir("payload")
        for index = 1, 40 do
            io.writefile(path.join(payload, string.format("part-%02d", index)), generation .. " " .. string.rep("x", 200) .. "\n")
            os.sleep(25)
        end
    end)
]]

local READER = [[
local function read(file)
    local text = nil
    try
    {
        function ()
            text = os.isfile(file) and io.readfile(file) or nil
        end,
        catch
        {
            function ()
                text = nil
            end
        }
    }
    return text
end

local function complete(dir)
    if not os.isdir(dir) then
        return false
    end
    for index = 1, 40 do
        local text = read(path.join(dir, "payload", string.format("part-%02d", index)))
        if not text or not (text:match("^old x+\n$") or text:match("^new x+\n$")) then
            return false
        end
    end
    return true
end

function main(dir, stop, ready)
    io.writefile(ready, "ready")
    local reads, violations = 0, 0
    while not os.isfile(stop) do
        reads = reads + 1
        if not complete(dir) then
            violations = violations + 1
        end
    end
    print("reads " .. reads .. " violations " .. violations)
end
]]

local function published(store)
    for _, dir in ipairs(os.dirs(path.join(store, ".xmake", "packages", "f", "fakeinstall", "latest", "*"))) do
        if not dir:match("%.g%x+$") then
            return dir
        end
    end
end

local function whole(dir, generation)
    if not dir or not os.isdir(dir) then
        return false
    end
    for index = 1, 40 do
        local text = io.readfile(path.join(dir, "payload", string.format("part-%02d", index)))
        if text ~= generation .. " " .. string.rep("x", 200) .. "\n" then
            return false
        end
    end
    return true
end

function failures(opt)
    local found = {}
    local folder = fixtures.scratch()
    local repo = path.join(folder, "repo")
    local package = path.join(repo, "packages", "f", "fakeinstall")
    os.mkdir(package)
    io.writefile(path.join(package, "xmake.lua"), PACKAGE)
    local project = path.join(folder, "project")
    os.mkdir(project)
    io.writefile(path.join(project, "xmake.lua"), table.concat({
        "add_repositories(\"fake " .. repo .. "\")",
        "add_requires(\"fake@fakeinstall\")",
        "target(\"nop\")",
        "    set_kind(\"phony\")",
        "    add_packages(\"fakeinstall\")",
        ""
    }, "\n"))
    local store = path.join(folder, "store")
    os.mkdir(store)
    local envs = {XMAKE_GLOBALDIR = store, XMAKE_MAIN_REPO = fixtures.empty_repository(folder)}
    local log = path.join(folder, "xmake.log")
    local function xmake(argv, extra)
        return os.execv(os.programfile(), argv, {curdir = project, try = true, stdout = log, stderr = log,
                                                  envs = table.join(envs, extra or {})})
    end

    if xmake({"require", "-y"}, {FAKE_GENERATION = "old"}) ~= 0 then
        table.insert(found, "the first install of the fake package failed: " .. (io.readfile(log) or ""))
        os.tryrm(folder)
        return found
    end
    local installed = published(store)
    if not installed then
        table.insert(found, "the first install left no installed folder to read")
        os.tryrm(folder)
        return found
    end

    local reader = path.join(folder, "reader.lua")
    io.writefile(reader, READER)
    local stop, ready = path.join(folder, "stop"), path.join(folder, "reader.ready")
    local readerlog = path.join(folder, "reader.log")
    local child = process.openv(os.programfile(), {"l", reader, installed, stop, ready},
                                {envs = envs, stdout = readerlog, stderr = readerlog})
    local waited = 0
    while not os.isfile(ready) and waited < 60000 do
        os.sleep(100)
        waited = waited + 100
    end
    if not os.isfile(ready) then
        table.insert(found, "the reader process did not start")
    end

    if xmake({"require", "-f", "-y"}, {FAKE_GENERATION = "new"}) ~= 0 then
        table.insert(found, "the forced reinstall failed: " .. (io.readfile(log) or ""))
    end
    io.writefile(stop, "stop")
    if child:wait(60000) == 0 then
        child:kill()
    end
    child:close()

    local said = os.isfile(readerlog) and io.readfile(readerlog) or ""
    local reads, violations = said:match("reads (%d+) violations (%d+)")
    if not reads then
        table.insert(found, "the reader did not report its reads: " .. said)
    else
        if tonumber(reads) < 20 then
            table.insert(found, "the reader made only " .. reads .. " reads during the forced reinstall, too few to mean anything")
        end
        if tonumber(violations) > 0 then
            table.insert(found, "readers saw an incomplete install in " .. violations .. " of " .. reads ..
                " reads while a forced reinstall replaced it: a reader must see the old install or the new one, whole")
        end
    end

    local now = published(store)
    if not whole(now, "new") then
        table.insert(found, "after the forced reinstall the installed folder does not hold the whole new install")
    end

    if xmake({"require", "-f", "-y"}, {FAKE_GENERATION = "newer", FAKE_FAIL = "yes"}) == 0 then
        table.insert(found, "a forced reinstall whose install fails was reported as a success")
    end
    if not whole(published(store), "new") then
        table.insert(found, "a failed forced reinstall changed the installed folder: it must stay the install it was")
    end

    if xmake({"require", "--uninstall", "-y", "fakeinstall"}) ~= 0 then
        table.insert(found, "uninstalling the fake package failed: " .. (io.readfile(log) or ""))
    elseif #os.dirs(path.join(store, ".xmake", "packages", "f", "fakeinstall", "latest", "*")) > 0 then
        table.insert(found, "uninstalling the fake package left its installed folder or a generation of it behind")
    end

    os.tryrm(folder)
    return found
end
