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
        io.writefile(path.join(package:installdir("include"), "fake.h"), "int fake(void);\n")
        io.writefile(path.join(package:installdir("lib"), "libfake.a"), "!<arch>\n")
    end)
    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("include"), "fake.h")), "fake.h is missing from the installed package")
        assert(os.isfile(path.join(package:installdir("lib"), "libfake.a")), "libfake.a is missing from the installed package")
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

local function per_include(dir)
    local text = read(path.join(dir, "fake.h"))
    os.sleep(PACE)
    if text ~= "int fake(void);\n" then
        return false, "the include folder " .. dir .. " does not hold fake.h: " .. tostring(text)
    end
    return true
end

function main(dir, stop, ready, mode)
    io.writefile(ready, "ready")
    local checks = {pass = per_pass, file = per_file, include = per_include}
    local check = checks[mode]
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

local function generation_in_cache(project)
    for _, file in ipairs(os.files(path.join(project, ".xmake", "**"))) do
        local text = io.readfile(file, {encoding = "binary"}) or ""
        local generation = text:match("fakeinstall/latest/%x+%.g%x+")
        if generation then
            return file, generation
        end
    end
end

local function cached_include(project)
    for _, file in ipairs(os.files(path.join(project, ".xmake", "**", "cache", "package"))) do
        local include = (io.readfile(file) or ""):match('sysincludedirs = "([^"]+)"')
        if include then
            return include
        end
    end
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
        "add_requires(\"fake@fakeinstall\", {alias = \"fakeinstall\"})",
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
        return os.execv(os.programfile(), table.join(argv, {"-P", project}), {curdir = project, try = true, stdout = log, stderr = log,
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
    local include = cached_include(project)
    if not include then
        table.insert(found, "the project's package cache names no include folder for fakeinstall after the first install")
        os.tryrm(folder)
        return found
    end

    local reader = path.join(folder, "reader.lua")
    io.writefile(reader, READER)
    local stop = path.join(folder, "stop")
    local children = {}
    local stop_pass = path.join(folder, "stop-pass")
    local specs = {{name = "pass", mode = "pass", dir = installed, stop = stop_pass},
                   {name = "file", mode = "file", dir = installed, stop = stop},
                   {name = "generation", mode = "pass", dir = first, stop = stop},
                   {name = "cached", mode = "include", dir = include, stop = stop}}
    for _, spec in ipairs(specs) do
        local ready, readerlog = path.join(folder, spec.name .. ".ready"), path.join(folder, spec.name .. ".log")
        local child = process.openv(os.programfile(), {"l", "-P", project, reader, spec.dir, spec.stop, ready, spec.mode},
                                    {envs = envs, stdout = readerlog, stderr = readerlog})
        children[spec.name] = {child = child, ready = ready, log = readerlog}
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
    if not whole(published(store), "newer") then
        table.insert(found, "after the second forced reinstall the installed folder does not hold the whole install")
    end

    local function finish(name, reader_state)
        if reader_state.child:wait(60000) == 0 then
            reader_state.child:kill()
        end
        reader_state.child:close()
        local said = os.isfile(reader_state.log) and io.readfile(reader_state.log) or ""
        local reads, violations = said:match("reads (%d+) violations (%d+)")
        if not reads then
            table.insert(found, name .. " reader did not report its reads: " .. said)
        elseif name == "generation" then
            if tonumber(violations) == 0 then
                table.insert(found, "the reader that held the first generation's path read it whole past the grace period: the grace no longer ends for a reader that holds a generation path")
            end
        elseif tonumber(violations) > 0 then
            table.insert(found, name .. " reader saw an incomplete install in " .. violations .. " of " .. reads ..
                " reads: a published install must stay whole for a reader of the link or of a path the project cache names, across publishes and past the grace period\n" .. said)
        end
    end
    io.writefile(stop_pass, "stop")
    finish("pass", children.pass)
    children.pass = nil

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
    if not whole(installed, "newest") then
        table.insert(found, "after the grace period a path through the published link no longer holds the whole install: a build must reference the link, which every publish keeps current")
    end
    os.sleep(2000)
    local cached, generation = generation_in_cache(project)
    if cached then
        table.insert(found, "the project's package cache " .. cached .. " holds the generation " .. generation .. ": a build that reads the cache keeps a path the grace period retires; the cache must hold the published link")
    end

    io.writefile(stop, "stop")
    for name, reader_state in pairs(children) do
        finish(name, reader_state)
    end

    os.tryrm(folder)
    return found
end
