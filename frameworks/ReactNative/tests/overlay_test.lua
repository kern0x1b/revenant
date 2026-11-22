local ROOT = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
local TOOLS = path.join(ROOT, "frameworks", "ReactNative", "tools")
local overlay = import("overlay", {rootdir = TOOLS, anonymous = true})

local function expect(name, condition, detail)
    if not condition then
        raise("%s: %s", name, detail)
    end
    print(name .. ": passes")
end

local function application(folder, script)
    os.mkdir(path.join(folder, "node_modules", ".bin"))
    os.mkdir(path.join(folder, "scripts"))
    io.writefile(path.join(folder, "src.txt"), "original\n")
    if script then
        io.writefile(path.join(folder, "scripts", "postinstall-patches.mjs"), script)
    end
end

local function kit(folder)
    os.mkdir(path.join(folder, "overlay"))
    io.writefile(path.join(folder, "overlay", "src.txt"), "overlaid\n")
end

local MARKER = [[
import { writeFileSync } from "node:fs";
writeFileSync("patched.txt", process.cwd() + "\n" + process.env.PATH.split(":")[0] + "\n" + process.argv[1].split("/").slice(-2).join("/") + "\n");
]]

local scratch = path.join(os.tmpdir(), "rn-overlay-test-" .. tostring(os.time()))
os.rm(scratch)
os.mkdir(scratch)

local app, kitdir = path.join(scratch, "app"), path.join(scratch, "kit")
application(app, MARKER)
kit(kitdir)
local target = path.join(scratch, "target")
overlay.apply(app, kitdir, target)
local lines = io.readfile(path.join(target, "patched.txt")):split("\n")
expect("the application's patch script runs in the clone", lines[1]:endswith("/target") and not lines[1]:find("/app", 1, true), "it ran in " .. tostring(lines[1]))
expect("the script runs with the clone's node_modules/.bin first on PATH", lines[2]:endswith("/target/node_modules/.bin"), "PATH began with " .. tostring(lines[2]))
expect("the script that runs is the application's", lines[3] == "scripts/postinstall-patches.mjs", "it ran " .. tostring(lines[3]))
expect("the application itself is not written", not os.exists(path.join(app, "patched.txt")), "patched.txt is in the application folder")
expect("the overlay is still applied", io.readfile(path.join(target, "src.txt")) == "overlaid\n", "src.txt is not the overlay's")

local plain, plain_target = path.join(scratch, "plain"), path.join(scratch, "plain-target")
application(plain, nil)
overlay.apply(plain, kitdir, plain_target)
expect("an application without the script is applied without patches", os.isfile(path.join(plain_target, "src.txt")) and not os.exists(path.join(plain_target, "patched.txt")), "the clone is wrong")

local failing, failing_target = path.join(scratch, "failing"), path.join(scratch, "failing-target")
application(failing, "process.exit(3);\n")
local message
try { function () overlay.apply(failing, kitdir, failing_target) end, catch { function (errors) message = tostring(errors) end } }
expect("a patch script that fails stops apply", message ~= nil, "apply returned although the script exited 3")

os.rm(scratch)
