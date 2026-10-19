-- The pins of the snapshots (spec/snapshots.tsv, tools/gen/snapshot_pins.lua) and the constant record that holds no rows (check's
-- constant_record_problem), Round 14 decisions 1 and 4. A fixture spec folder under .agent-work/runs holds protocols.tsv and functions.tsv
-- in two frameworks (one nested). The pins are recorded through pin_record; each way a snapshot can drift is then a problem, and the
-- command that removes a snapshot records its removal. Run from anywhere: xmake l tests/gen/snapshot_pins_test.lua (exits 1 on failure).

local ROOT = path.absolute(path.join(os.scriptdir(), "..", ".."))
local TOOLS = path.join(ROOT, "tools")
local TREE = path.join(ROOT, ".agent-work", "runs", "snapshot-pins-test")
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

-- The problems of the pins, as a set of their texts
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

-- a snapshot changed after its command wrote it
write("Fa", "functions.tsv", "api\tintroduced\nf\t13.1\n")
expect("a changed snapshot differs from its pin", problems()["Fa functions.tsv: differs from its pin (re-run the command that writes it)"])
write("Fa", "functions.tsv", "api\tintroduced\nf\t13.0\n")
expect("the snapshot restored holds its pin again", #pins.pin_problems(TREE) == 0)

-- the same drift named through a relative tree (check --tree .): the glob returns relative paths, and the problems must match
write("Fa", "functions.tsv", "api\tintroduced\nf\t13.1\n")
local REL = "./" .. path.relative(TREE, os.curdir())
expect("a relative tree names the same drifted snapshot", #pins.pin_problems(REL) == 1 and table.concat(pins.pin_problems(REL), "|") == table.concat(pins.pin_problems(TREE), "|"))
write("Fa", "functions.tsv", "api\tintroduced\nf\t13.0\n")
expect("a relative tree holds the restored snapshot to its pin", #pins.pin_problems(REL) == 0)

-- a snapshot no command pinned (a file added by hand, or a nested one never recorded)
write("Fb/Inner", "functions.tsv", "api\tintroduced\ng\t15.0\n")
expect("an unpinned snapshot is a problem", problems()["Fb/Inner functions.tsv: not pinned (the command that writes it records the pin)"])
pins.pin_record(TREE, "Fb/Inner", "functions.tsv")
expect("the recorded snapshot holds its pin", #pins.pin_problems(TREE) == 0)

-- a snapshot removed without its command recording it: the pin has no file
os.rm(path.join(SPEC, "Fa", "protocols.tsv"))
expect("a pin whose file is gone is a problem", problems()["Fa protocols.tsv: pinned, but the file is gone"])
-- the command that removes a snapshot records its removal
pins.pin_record(TREE, "Fa", "protocols.tsv")
expect("the removal recorded: no problem", #pins.pin_problems(TREE) == 0)

-- a constant record: a header with no row is stale (input writes no record for a framework with no constant); one with rows is fine
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
