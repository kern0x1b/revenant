import("core.base.json")

local function held_by(machine, locked, addon)
    if locked then
        return locked
    end
    if machine[addon] then
        return addon
    end
    return nil
end

function failures(opts)
    local failures = 0
    local function check(name, got, want)
        if got ~= want then
            print(string.format("  %s FAIL: the gate would hold %s, not %s", name, tostring(got), tostring(want)))
            failures = failures + 1
        end
    end
    local gate = io.readfile(path.join(os.getenv("HOME") or "", "Git/projects/ios/coordination/build-gate.lua"))
    if gate and not gate:find("addons.conf", 1, true) then
        print("  lock_test FAIL: the gate does not read the machine's own addon copy when xmake writes no lock")
        failures = failures + 1
    end
    if gate and not gate:find("xmake%-addons%.lock") then
        print("  lock_test FAIL: the gate does not look at the lock at all")
        failures = failures + 1
    end

    local addon = "v0.8.13"
    local machine = {[addon] = {version = addon}}
    check("a lock naming the pinned addon", held_by(machine, addon, addon), addon)
    check("a lock naming another one", held_by(machine, "v0.1.0", addon), "v0.1.0")
    check("no lock, the machine holds it", held_by(machine, nil, addon), addon)
    check("no lock, the machine does not", held_by({}, nil, addon), nil)

    local out = {}
    if failures > 0 then
        out[#out + 1] = string.format("%d failures", failures)
    end
    return out
end
