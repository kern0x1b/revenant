-- Each example's xmake.lua is read by xmake in the description scope, which has neither import() nor io: the file cannot read host.json, so it
-- repeats the project name and the Backports list as literals. This test keeps the two in agreement and has xmake read each file.
import("core.base.json")

local ROOT = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
local EXAMPLES = path.join(ROOT, "frameworks", "ReactNative", "examples")

local function expect(name, condition, detail)
    if not condition then
        raise("%s: %s", name, detail)
    end
    print(name .. ": passes")
end

local function loads(example)
    local folder = path.join(os.tmpdir(), "example-project-" .. example .. "-" .. os.time())
    os.tryrm(folder)
    os.mkdir(folder)
    local source = path.join(EXAMPLES, example)
    os.vrunv("rsync", {"-aL", path.join(source, "xmake.lua"), path.join(source, "host.json"), folder .. "/"})
    local outfile = path.join(folder, "configure.txt")
    os.execv(os.programfile(), {"f", "-P", folder, "-p", "iphoneos", "-a", "armv7", "-y"}, {try = true, envs = {REVENANT_PATH = ROOT}, stdout = outfile, stderr = outfile})
    local output = io.readfile(outfile)
    os.tryrm(folder)
    return output
end

for _, example in ipairs({"paseo", "rn-probe"}) do
    local source = io.readfile(path.join(EXAMPLES, example, "xmake.lua"))
    local host = json.loadfile(path.join(EXAMPLES, example, "host.json"))
    expect("the " .. example .. " example's set_project names the project of its host.json", source:find('set_project("' .. host.project .. '")', 1, true) ~= nil, host.project)
    local listed = source:match('libraries = "([^"]*)"')
    expect("the " .. example .. " example's Backports list in xmake.lua is the backports of its host.json", listed == table.concat(host.backports, ","), tostring(listed) .. " against " .. table.concat(host.backports, ","))
    local output = loads(example)
    -- the configure goes on to fail without the build inputs of a host (unknown target rn-yoga); only an error raised in the project file itself counts
    expect("the " .. example .. " example's xmake.lua is read without an error of its own", output:find("xmake.lua:%d+:") == nil, output)
end
