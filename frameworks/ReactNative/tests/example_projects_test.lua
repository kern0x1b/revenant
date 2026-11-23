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
    expect("the " .. example .. " example's set_project names the project of its host.json", source:match('HOST_PROJECT = "([^"]*)"') == host.project, host.project)
    local listed = source:match('HOST_BACKPORTS = "([^"]*)"')
    expect("the " .. example .. " example's Backports list in xmake.lua is the backports of its host.json", listed == table.concat(host.backports, ","), tostring(listed) .. " against " .. table.concat(host.backports, ","))
    local output = loads(example)
    expect("the " .. example .. " example's project files are read without an error of their own", output:find("%.lua:%d+:") == nil, output)
end
