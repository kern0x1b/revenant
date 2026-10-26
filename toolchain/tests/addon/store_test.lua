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
    local text, failure = nil, nil
    try
    {
        function ()
            text = os.isfile(file) and io.readfile(file) or nil
        end,
        catch
        {
            function (errors)
                failure = tostring(errors)
            end
        }
    }
    return text, failure
end

local function complete(dir)
    if not os.isdir(dir) then
        return false, "missing " .. dir .. " link " .. tostring(os.islink(dir))
    end
    local target = os.islink(dir) and os.readlink(dir)
    if not target then
        return false, dir .. " is not a link to a generation"
    end
    local generation = path.join(path.directory(dir), target)
    for index = 1, 40 do
        local file = path.join(generation, "payload", string.format("part-%02d", index))
        local text, failure = read(file)
        if not text or not (text:match("^old x+\n$") or text:match("^new x+\n$")) then
            return false, file .. " text " .. (text and string.format("%q", text:sub(1, 40)) or "nil") .. " error " .. tostring(failure) .. " isfile " .. tostring(os.isfile(file)) .. " link " .. tostring(os.islink(dir) and os.readlink(dir)) .. " generation " .. generation .. " generation exists " .. tostring(os.isdir(generation))
        end
    end
    return true
end

function main(dir, stop, ready)
    io.writefile(ready, "ready")
    local reads, violations, first = 0, 0, nil
    while not os.isfile(stop) do
        reads = reads + 1
        local ok, why = complete(dir)
        if not ok then
            violations = violations + 1
            first = first or why
        end
    end
    print("reads " .. reads .. " violations " .. violations)
    print("first " .. tostring(first))
end
]]

local function published(store)
    for _, dir in ipairs(os.dirs(path.join(store, ".xmake", "packages", "f", "fakeinstall", "latest", "*"))) do
        if not dir:match("%.g%x+$") then
            return dir
        end
    end
end

local function generation_of(installed)
    if not os.islink(installed) then
        return nil
    end
    return path.join(path.directory(installed), os.readlink(installed))
end

local function readable(file)
    local text = nil
    try
    {
        function ()
            text = io.readfile(file)
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

local function whole(dir, generation)
    if not dir or not os.isdir(dir) then
        return false
    end
    for index = 1, 40 do
        local text = readable(path.join(dir, "payload", string.format("part-%02d", index)))
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
    local envs = {XMAKE_GLOBALDIR = store, XMAKE_MAIN_REPO = fixtures.empty_repository(folder), REVENANT_GENERATION_GRACE = "0"}
    local log = path.join(folder, "xmake.log")
    local function xmake(argv, extra)
        return os.execv(os.programfile(), argv, {curdir = project, try = true, stdout = log, stderr = log,
                                                  envs = table.join(envs, extra or {})})
    end
    local function leftovers()
        return #os.dirs(path.join(store, ".xmake", "packages", "f", "fakeinstall", "latest", "*"))
    end
    local function uninstall()
        if xmake({"require", "--uninstall", "-y", "fakeinstall"}) ~= 0 then
            table.insert(found, "uninstalling the fake package failed: " .. (io.readfile(log) or ""))
        elseif leftovers() > 0 then
            table.insert(found, "uninstalling the fake package left its installed folder or a generation of it behind")
        end
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
    local first = generation_of(installed)
    if not first then
        table.insert(found, "the published install is not a link to a generation")
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
                " reads while a forced reinstall replaced it: a reader must see the old install or the new one, whole; " .. said)
        end
    end
    if not whole(published(store), "new") then
        table.insert(found, "after the forced reinstall the installed folder does not hold the whole new install")
    end
    if first and not whole(first, "old") then
        table.insert(found, "the generation that the publish replaced was not kept until the next publish")
    end

    if xmake({"require", "-f", "-y"}, {FAKE_GENERATION = "newest"}) ~= 0 then
        table.insert(found, "the second forced reinstall failed: " .. (io.readfile(log) or ""))
    end
    if first then
        local raised = false
        try
        {
            function ()
                io.readfile(path.join(first, "payload", "part-01"))
            end,
            catch
            {
                function ()
                    raised = true
                end
            }
        }
        if not raised then
            table.insert(found, "a generation two publishes old still reads: it must be gone, so a stale path fails")
        end
    end
    if not whole(published(store), "newest") then
        table.insert(found, "after the second forced reinstall the installed folder does not hold the whole install")
    end

    if xmake({"require", "-f", "-y"}, {FAKE_GENERATION = "newer", FAKE_FAIL = "yes"}) == 0 then
        table.insert(found, "a forced reinstall whose install fails was reported as a success")
    end
    if not whole(published(store), "newest") then
        table.insert(found, "a failed forced reinstall changed the installed folder: it must stay the install it was")
    end

    local exported = path.join(folder, "export")
    if xmake({"require", "--export", "--packagedir=" .. exported, "-y", "fakeinstall"}) ~= 0 then
        table.insert(found, "exporting the fake package failed: " .. (io.readfile(log) or ""))
    end
    uninstall()
    if xmake({"require", "--import", "--packagedir=" .. exported, "-y", "fakeinstall"}) ~= 0 then
        table.insert(found, "importing the fake package failed: " .. (io.readfile(log) or ""))
    else
        local imported = published(store)
        if not whole(imported, "newest") then
            table.insert(found, "after the import the installed folder does not hold the whole exported install")
        elseif not os.islink(imported) then
            table.insert(found, "after the import the installed folder is not a link to its generation")
        end
    end
    uninstall()

    os.tryrm(folder)
    return found
end
