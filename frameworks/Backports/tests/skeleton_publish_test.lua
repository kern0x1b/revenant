local ROOT = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
local TOOLS = path.join(ROOT, "frameworks", "Backports", "tools")
import("core.base.process")
local generate = import("generate", {rootdir = TOOLS, anonymous = true})
local memo = import("memo", {rootdir = TOOLS, anonymous = true})
local skeleton = import("skeleton", {rootdir = TOOLS, anonymous = true})
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
    for round = 1, tonumber(count) do
        if round % 2 == 1 then
            generate.publish_skeleton(root, writer({["a.m"] = "one\n", ["b.weak"] = "-Wl,-U,_x\n"}))
        else
            generate.publish_skeleton(root, writer({["a.m"] = "two\n", ["b.weak"] = "-Wl,-U,_y\n"}))
        end
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
    local child = process.openv(os.programfile(), {"l", "-P", ROOT, path.join(os.scriptdir(), "skeleton_publish_test.lua"), "loop", root, "300"}, {outpath = log, errpath = log})
    local missing = 0
    local seen = {}
    local looked = 0
    local finished = 0
    while finished == 0 or looked == 0 do
        finished = child:wait(1)
        looked = looked + 1
        local first = os.isfile(path.join(live, "a.m")) and io.readfile(path.join(live, "a.m"))
        local second = os.isfile(path.join(live, "b.weak")) and io.readfile(path.join(live, "b.weak"))
        local good = (first == "one\n" or first == "two\n") and (second == "-Wl,-U,_x\n" or second == "-Wl,-U,_y\n")
        if not good then
            missing = missing + 1
        end
        seen[tostring(first)] = true
    end
    child:close()
    expect("a reader never finds the live folder missing or partial while another process replaces it with other content again and again", missing == 0 and looked > 1
        and seen["one\n"] and seen["two\n"], string.format("%d of %d looks found a missing or partial folder, saw %s, wait gave %s; child log: %s", missing, looked,
        table.concat(table.keys(seen), ","), tostring(finished), io.readfile(log) or ""))
    expect("a replaced folder keeps the current and the previous version only", #os.dirs(path.join(root, "skeleton.*")) == 2, "wrong number of versions: " .. table.concat(os.dirs(path.join(root, "skeleton.*")), ", "))
    local held = path.join(root, path.filename(os.readlink(live)))
    local held_text = io.readfile(path.join(held, "a.m"))
    generate.publish_skeleton(root, writer({["a.m"] = "four\n", ["c.m"] = "five\n"}))
    expect("a reader holding the resolved path of the previous version keeps its files after the next publish",
        io.readfile(path.join(held, "a.m")) == held_text and io.readfile(path.join(live, "a.m")) == "four\n" and #os.dirs(path.join(root, "skeleton.*")) == 2,
        "the held version lost its files")
    local failing = path.join(root, "skeleton")
    os.rm(failing)
    os.mkdir(failing)
    io.writefile(path.join(failing, "a.m"), "plain\n")
    generate.publish_skeleton(root, writer({["a.m"] = "plain\n"}))
    expect("a live folder that is a plain folder becomes the pointer to a version", os.islink(failing) and io.readfile(path.join(failing, "a.m")) == "plain\n", "the live folder is not a pointer")
    local raised
    try {
        function ()
            generate.publish_skeleton(root, function (folder)
                os.mkdir(folder)
                io.writefile(path.join(folder, "a.m"), "other\n")
                os.vrunv("chmod", {"000", path.join(folder, "a.m")})
                return {}
            end)
        end,
        catch {
            function (errors)
                raised = tostring(errors)
            end
        }
    }
    os.vrunv("chmod", {"-R", "u+rwx", root})
    expect("a diff that cannot read a file raises and keeps the live folder", raised and raised:find("diff", 1, true) and io.readfile(path.join(failing, "a.m")) == "plain\n",
        "got " .. tostring(raised))
    os.tryrm(root)
end

local function memo_test()
    local root = workspace.fresh("rn-skeleton-memo")
    local tools = path.join(root, "tools")
    local src = path.join(root, "src")
    local modules = path.join(root, "modules")
    local facts = path.join(root, "facts")
    local xmake = path.join(root, "xmake.lua")
    local inventory = path.join(root, "classes.json")
    for _, folder in ipairs({tools, src, modules, facts}) do
        os.mkdir(folder)
    end
    io.writefile(path.join(tools, "generate.lua"), "one\n")
    io.writefile(path.join(src, "revenant_alias.h"), "two\n")
    io.writefile(path.join(modules, "dyld.lua"), "three\n")
    io.writefile(path.join(facts, "Framework.tsv"), "four\n")
    io.writefile(path.join(facts, "install_names.tsv"), "Framework\t/System/Library/Frameworks/Framework.framework/Framework\n")
    io.writefile(xmake, "five\n")
    io.writefile(inventory, "six\n")
    local opt = {root = root, tools = tools, src = src, modules = modules, facts = facts, xmake = xmake,
                 inventory = inventory, names = {"Framework"}, env = {REVENANT_GEN_SDK = "", REVENANT_BACKPORTS_LIBRARIES = ""}}
    local key = memo.compute(opt)
    expect("the memo key has a value", key ~= nil and #key == 32, tostring(key))
    local function changed(file, text, field)
        io.writefile(file, text)
        local other = memo.compute(opt)
        expect("a change of " .. field .. " changes the key", other ~= key, tostring(other))
        key = other
    end
    changed(path.join(facts, "Framework.tsv"), "seven\n", "a facts file")
    changed(path.join(src, "revenant_alias.h"), "eight\n", "a source")
    changed(path.join(tools, "generate.lua"), "nine\n", "a tool")
    changed(path.join(modules, "dyld.lua"), "ten\n", "an addon module")
    changed(xmake, "eleven\n", "the configuration")
    changed(inventory, "twelve\n", "the device inventory")
    opt.env.REVENANT_GEN_SDK = "/another/sdk"
    local environment_key = memo.compute(opt)
    expect("a change of the SDK selection changes the key", environment_key ~= key, tostring(environment_key))
    key = environment_key
    local published = path.join(root, "published")
    generate.publish_skeleton(published, writer({["a.m"] = "one\n"}), key)
    local live = path.join(published, "skeleton")
    expect("the published skeleton carries its input key", (io.readfile(memo.key_file(published)) or ""):trim() == key, tostring(io.readfile(memo.key_file(published))))
    expect("a read of the key finds the published one", memo.read(published) == key and memo.unchanged(published, key), "the key was not read")
    local calls = 0
    local function build()
        calls = calls + 1
        return {built = true}
    end
    local skipped = generate.generate_if_changed(published, key, build)
    expect("an unchanged key skips the build", skipped == nil and calls == 0, tostring(calls))
    local result = generate.generate_if_changed(published, key .. "x", build)
    expect("a moved key runs the build", result ~= nil and result.built and calls == 1, tostring(calls))
    local generated = path.join(root, "generated")
    skeleton.write(generated, {{name = "Framework", unavailable = {}, rows = {{kind = "class", name = "FWThing", container = "FWThing", signature = "", intro = nil, flags = ""}}}},
        {}, {}, {}, {}, {}, {})
    local source = io.readfile(path.join(generated, "Framework.m")) or ""
    expect("the generated source includes the alias header by a relative path", source:find('#include "../..', 1, true) ~= nil and not source:find(root, 1, true), source:sub(1, 160))
    os.tryrm(root)
end

function main(command, ...)
    if command == "loop" then
        loop(...)
    else
        test()
        memo_test()
    end
end
