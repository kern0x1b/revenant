import("fixtures")
import("core.base.process")

local PACKAGE = [[
package("fakeinstall")
    set_kind("library")
    on_install(function (package)
        local generation = os.getenv("FAKE_GENERATION") or "old"
        local payload = package:installdir("payload")
        for index = 1, 40 do
            io.writefile(path.join(payload, string.format("part-%02d", index)), generation .. " " .. string.rep("x", 200) .. "\n")
            os.sleep(25)
        end
    end)
]]

local READER = [[
local PACE = 300

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

local function word_of(text)
    return text and text:match("^(%a+) x+\n$")
end

local function per_pass(dir)
    if not os.isdir(dir) then
        return false, "the install is not a directory"
    end
    local folder = dir
    if os.islink(dir) then
        folder = path.join(path.directory(dir), os.readlink(dir))
    end
    local word = nil
    for index = 1, 40 do
        local found = word_of(read(path.join(folder, "payload", string.format("part-%02d", index))))
        if not found or (word and found ~= word) then
            return false, "pass part " .. index .. " of " .. folder .. " is " .. tostring(found) .. ", after " .. tostring(word)
        end
        word = found
        os.sleep(PACE)
    end
    return true
end

local function per_file(dir)
    for index = 1, 40 do
        if not word_of(read(path.join(dir, "payload", string.format("part-%02d", index)))) then
            return false, "file part " .. index .. " is unreadable or partial"
        end
        os.sleep(PACE)
    end
    return true
end

function main(dir, stop, ready, mode)
    io.writefile(ready, "ready")
    local check = mode == "pass" and per_pass or per_file
    local reads, violations, details = 0, 0, {}
    while not os.isfile(stop) do
        reads = reads + 1
        local whole, why = check(dir)
        if not whole then
            violations = violations + 1
            if #details < 4 then
                table.insert(details, why)
            end
        end
    end
    print("reads " .. reads .. " violations " .. violations)
    for _, line in ipairs(details) do
        print("DETAIL " .. line)
    end
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

local function whole(dir, word)
    if not dir or not os.isdir(dir) then
        return false
    end
    for index = 1, 40 do
        local text = readable(path.join(dir, "payload", string.format("part-%02d", index)))
        if text ~= word .. " " .. string.rep("x", 200) .. "\n" then
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
    local first = installed and generation_of(installed)
    if not first then
        table.insert(found, "the first install left no published folder that is a link to a generation")
        os.tryrm(folder)
        return found
    end

    local reader = path.join(folder, "reader.lua")
    io.writefile(reader, READER)
    local stop = path.join(folder, "stop")
    local children = {}
    for _, mode in ipairs({"pass", "file"}) do
        local ready, readerlog = path.join(folder, mode .. ".ready"), path.join(folder, mode .. ".log")
        local child = process.openv(os.programfile(), {"l", reader, installed, stop, ready, mode},
                                    {envs = envs, stdout = readerlog, stderr = readerlog})
        children[mode] = {child = child, ready = ready, log = readerlog}
    end
    for _, reader_state in pairs(children) do
        local waited = 0
        while not os.isfile(reader_state.ready) and waited < 60000 do
            os.sleep(100)
            waited = waited + 100
        end
        if not os.isfile(reader_state.ready) then
            table.insert(found, "a reader process did not start")
        end
    end

    if xmake({"require", "-f", "-y"}, {FAKE_GENERATION = "new"}) ~= 0 then
        table.insert(found, "the first forced reinstall failed: " .. (io.readfile(log) or ""))
    end
    if xmake({"require", "-f", "-y"}, {FAKE_GENERATION = "newer"}) ~= 0 then
        table.insert(found, "the second forced reinstall failed: " .. (io.readfile(log) or ""))
    end
    if not os.isdir(first) then
        table.insert(found, "the generation the first publish replaced is gone after the second publish, before its grace period has ended: a reader that resolved it cannot finish")
    end
    io.writefile(stop, "stop")

    for mode, reader_state in pairs(children) do
        if reader_state.child:wait(60000) == 0 then
            reader_state.child:kill()
        end
        reader_state.child:close()
        local said = os.isfile(reader_state.log) and io.readfile(reader_state.log) or ""
        local reads, violations = said:match("reads (%d+) violations (%d+)")
        if not reads then
            table.insert(found, mode .. " reader did not report its reads: " .. said)
        else
            if tonumber(violations) > 0 then
                table.insert(found, mode .. " reader saw an incomplete install in " .. violations .. " of " .. reads ..
                    " reads while two publishes ran: a generation must stay whole for a reader while its grace period lasts\n" .. said)
            end
        end
    end
    if not whole(published(store), "newer") then
        table.insert(found, "after the second forced reinstall the installed folder does not hold the whole install")
    end

    os.sleep(3000)
    envs.REVENANT_GENERATION_GRACE = "2"
    if xmake({"require", "-f", "-y"}, {FAKE_GENERATION = "newest"}) ~= 0 then
        table.insert(found, "the third forced reinstall failed: " .. (io.readfile(log) or ""))
    end
    if os.isdir(first) then
        table.insert(found, "the generation the first publish replaced is still there after its grace period ended")
    end
    if not whole(published(store), "newest") then
        table.insert(found, "after the third forced reinstall the installed folder does not hold the whole install")
    end

    os.tryrm(folder)
    return found
end
