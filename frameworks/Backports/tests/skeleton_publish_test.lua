local ROOT = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
local TOOLS = path.join(ROOT, "frameworks", "Backports", "tools")
import("core.base.process")
local generate = import("generate", {rootdir = TOOLS, anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

local function expect(name, condition, detail)
    if not condition then
        raise("%s: %s", name, detail)
    end
    print(name .. ": passes")
end

local function writer(contents)
    return function (folder)
        os.mkdir(folder)
        for name, text in pairs(contents) do
            io.writefile(path.join(folder, name), text)
        end
        return {written = true}
    end
end

local function inode(file)
    return (os.iorunv("ls", {"-i", file}):match("^%s*(%d+)"))
end

local function loop(root, count)
    for _ = 1, tonumber(count) do
        generate.publish_skeleton(root, writer({["a.m"] = "one\n", ["b.weak"] = "-Wl,-U,_x\n"}))
    end
end

local function test()
    local root = workspace.fresh("rn-skeleton-publish")
    local live = path.join(root, "skeleton")
    local totals = generate.publish_skeleton(root, writer({["a.m"] = "one\n"}))
    expect("a first publish puts the files in skeleton and returns what the writer returned", io.readfile(path.join(live, "a.m")) == "one\n" and totals.written == true
        and not os.isdir(path.join(root, "skeleton.staged")), "the folder holds " .. tostring(io.readfile(path.join(live, "a.m"))))
    local before = inode(path.join(live, "a.m"))
    generate.publish_skeleton(root, writer({["a.m"] = "one\n"}))
    expect("a publish of the same content leaves the live files alone", inode(path.join(live, "a.m")) == before and not os.isdir(path.join(root, "skeleton.staged")),
        "the file was written again")
    generate.publish_skeleton(root, writer({["a.m"] = "two\n", ["c.m"] = "three\n"}))
    expect("a publish of other content replaces the folder", io.readfile(path.join(live, "a.m")) == "two\n" and os.isfile(path.join(live, "c.m")), "the old content is still there")
    generate.publish_skeleton(root, writer({["a.m"] = "one\n", ["b.weak"] = "-Wl,-U,_x\n"}))
    local log = path.join(root, "loop.log")
    local child = process.openv(os.programfile(), {"l", "-P", ROOT, path.join(os.scriptdir(), "skeleton_publish_test.lua"), "loop", root, "40"}, {outpath = log, errpath = log})
    local missing = 0
    local looked = 0
    local finished = 0
    while finished == 0 or looked == 0 do
        finished = child:wait(20)
        looked = looked + 1
        if io.readfile(path.join(live, "a.m")) ~= "one\n" or not os.isfile(path.join(live, "b.weak")) then
            missing = missing + 1
        end
        os.sleep(5)
    end
    child:close()
    expect("a reader never finds the live folder missing or partial while another process publishes the same content again and again", missing == 0 and looked > 1,
        string.format("%d of %d looks found a missing file, wait gave %s; child log: %s", missing, looked, tostring(finished), io.readfile(log) or ""))
    os.tryrm(root)
end

function main(command, ...)
    if command == "loop" then
        loop(...)
    else
        test()
    end
end
