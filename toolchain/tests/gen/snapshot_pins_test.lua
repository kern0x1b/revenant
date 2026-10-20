local ROOT = path.absolute(path.join(os.scriptdir(), "..", ".."))
local TOOLS = path.join(ROOT, "tools")
local TREE = import("workspace", {rootdir = path.join(ROOT, "modules"), anonymous = true}).run("snapshot-pins-test")
local SPEC = path.join(TREE, "packages", "a", "apple-backports", "spec")
local pins = import("gen.snapshot_pins", {rootdir = TOOLS, anonymous = true})
local check = import("gen.cmd_check", {rootdir = TOOLS, anonymous = true})

local failures = 0

local function expect(what, ok)
    if not ok then
        failures = failures + 1
        print("snapshot pins FAIL: " .. what)
    end
end

local function problems()
    local out = {}
    for _, p in ipairs(pins.pin_problems(TREE)) do
        out[p] = true
    end
    return out
end

local function write(framework, file, text)
    local dir = path.join(SPEC, framework)
    if not os.isdir(dir) then
        os.mkdir(dir)
    end
    io.writefile(path.join(dir, file), text)
end

os.tryrm(TREE)
write("Fa", "protocols.tsv", "protocol\tintroduced\nP\t12.0\n")
write("Fa", "functions.tsv", "api\tintroduced\nf\t13.0\n")
write("Outer/Inner", "protocols.tsv", "protocol\tintroduced\nQ\t14.0\n")
pins.pin_record(TREE, "Fa", "protocols.tsv")
pins.pin_record(TREE, "Fa", "functions.tsv")
pins.pin_record(TREE, "Outer/Inner", "protocols.tsv")
expect("recorded pins hold: no problem", #pins.pin_problems(TREE) == 0)

write("Fa", "functions.tsv", "api\tintroduced\nf\t13.1\n")
expect("a changed snapshot differs from its pin", problems()["Fa functions.tsv: differs from its pin (re-run the command that writes it)"])
write("Fa", "functions.tsv", "api\tintroduced\nf\t13.0\n")
expect("the snapshot restored holds its pin again", #pins.pin_problems(TREE) == 0)

write("Fa", "functions.tsv", "api\tintroduced\nf\t13.1\n")
local REL = "./" .. path.relative(TREE, os.curdir())
expect("a relative tree names the same drifted snapshot", #pins.pin_problems(REL) == 1 and table.concat(pins.pin_problems(REL), "|") == table.concat(pins.pin_problems(TREE), "|"))
write("Fa", "functions.tsv", "api\tintroduced\nf\t13.0\n")
expect("a relative tree holds the restored snapshot to its pin", #pins.pin_problems(REL) == 0)

write("Fb/Inner", "functions.tsv", "api\tintroduced\ng\t15.0\n")
expect("an unpinned snapshot is a problem", problems()["Fb/Inner functions.tsv: not pinned (the command that writes it records the pin)"])
pins.pin_record(TREE, "Fb/Inner", "functions.tsv")
expect("the recorded snapshot holds its pin", #pins.pin_problems(TREE) == 0)

os.rm(path.join(SPEC, "Fa", "protocols.tsv"))
expect("a pin whose file is gone is a problem", problems()["Fa protocols.tsv: pinned, but the file is gone"])
pins.pin_record(TREE, "Fa", "protocols.tsv")
expect("the removal recorded: no problem", #pins.pin_problems(TREE) == 0)

write("Fa", "constants.tsv", "kind\tapi\n")
expect("a constant record with no rows is a problem", check.constant_record_problem(TREE, "Fa") ~= nil)
write("Fa", "constants.tsv", "kind\tapi\nconstant\tf\n")
expect("a constant record with a row is no problem", check.constant_record_problem(TREE, "Fa") == nil)
os.rm(path.join(SPEC, "Fa", "constants.tsv"))
expect("no constant record is no problem", check.constant_record_problem(TREE, "Fa") == nil)

os.tryrm(TREE)
print("snapshot pins test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
if failures > 0 then
    os.exit(1)
end
