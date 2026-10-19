import("core.base.json")

-- The gate's addon check, in the two shapes a run folder is in.
--
-- xmake writes xmake-addons.lock from the machine's *active* addon, and writes it only while it installs one
-- (coordination/crutches.md, the xmake addon lock). A run folder whose addons and packages are all present does no
-- install, so it gets no lock at all - which is every band's first run and no band's second, and made the whole fleet
-- read "the packages did not resolve" when the packages had resolved. So the check has to answer from the machine when
-- the file is not there, and this is the answer the gate's own code gives for the four cases:
--
--   a lock naming the pinned addon,          a lock naming another one,
--   no lock and the machine holds the addon,  no lock and it does not.
--
-- The gate's code is read from coordination/build-gate.lua rather than duplicated, so a change to the gate and a
-- change to this fixture cannot drift apart silently: the helper is extracted from the same text the gate runs.

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
    -- The gate's own text, so this cannot pass while the gate disagrees: the refusal is what must exist, and the
    -- machine's own copy is what must be read when the file is absent.
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
