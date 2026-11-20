import("fixtures")

local LINE = "recalled light suites memo (ran 297 s in w at 0123456789, 3 min ago)"
local KEY = "a1b2c3"

local function counted(key)
    local calls = {n = 0}
    calls.fn = function (root)
        calls.n = calls.n + 1
        calls.root = root
        return key
    end
    return calls
end

function failures(opt)
    local recalled = import("recalled", {rootdir = opt.modules, anonymous = true})
    local home = fixtures.scratch()
    local failures = 0
    local function check(name, got, want)
        if got ~= want then
            print(string.format("  %s FAIL: got %s, wanted %s", name, tostring(got), tostring(want)))
            failures = failures + 1
        end
    end
    local function run(label)
        local folder = path.join(home, label)
        os.mkdir(folder)
        return folder
    end

    local folder = run("valid")
    local value = recalled.issue(folder, KEY, "/the/root", LINE)
    local current = counted(KEY)
    check("a value that names its file carries a nonce and the path", value:match("^%x+@" .. folder:gsub("%p", "%%%0")) ~= nil, true)
    check("the value is not the line", value:find(LINE, 1, true), nil)
    check("a valid verdict is read", recalled.read(value, current.fn), LINE)
    check("the key is asked of the root the verdict names", current.root, "/the/root")
    check("the key is computed once for a first read", current.n, 1)
    local again = counted(KEY)
    check("a second read of the same verdict is the same line", recalled.read(value, again.fn), LINE)
    check("a second read does not compute the key again", again.n, 0)

    local forged = counted(KEY)
    check("a forged value is no verdict", recalled.read("anything", forged.fn), nil)
    check("a forged value does not ask for the key", forged.n, 0)
    check("a recall line in the variable is no verdict", recalled.read(LINE, forged.fn), nil)
    check("an empty value is no verdict", recalled.read("", forged.fn), nil)
    check("no value is no verdict", recalled.read(nil, forged.fn), nil)

    local file = value:match("^%x+@(.+)$")
    local wrong = ("0"):rep(32) .. "@" .. file
    check("a value with another nonce is no verdict", recalled.read(wrong, forged.fn), nil)
    check("a value that names a missing file is no verdict", recalled.read(value:match("^%x+") .. "@" .. path.join(home, "none"), forged.fn), nil)
    check("a made-up value never computed a key", forged.n, 0)

    local other = run("other")
    local second = recalled.issue(other, KEY, "/the/root", LINE)
    check("two runs have two nonces", value:match("^%x+") ~= second:match("^%x+"), true)
    check("the nonce of one run does not open the file of another", recalled.read(value:match("^%x+") .. "@" .. second:match("^%x+@(.+)$"), forged.fn), nil)

    local moved = run("moved")
    local stale = recalled.issue(moved, KEY, "/the/root", LINE)
    local changed = counted("ffffff")
    check("a key that is no longer the current one is no verdict", recalled.read(stale, changed.fn), nil)
    check("the key was asked once for it", changed.n, 1)
    local after = counted(KEY)
    check("a refused verdict leaves no marker that a later read would trust", recalled.read(stale, after.fn), LINE)
    check("and the later read computes the key itself", after.n, 1)

    local raising = run("raising")
    local raised = recalled.issue(raising, KEY, "/the/root", LINE)
    check("a key that cannot be computed is no verdict", recalled.read(raised, function () raise("no git here") end), nil)

    local marked = run("marked")
    local value_marked = recalled.issue(marked, KEY, "/the/root", LINE)
    recalled.read(value_marked, counted(KEY).fn)
    local marker = path.join(marked, "light-suites.verdict.verified")
    io.writefile(marker, "someone else\nffffff")
    local forged_marker = counted("ffffff")
    check("a marker that does not hold this nonce and key is not trusted", recalled.read(value_marked, forged_marker.fn), nil)
    check("the key is computed when the marker is not its own", forged_marker.n, 1)

    local tampered = run("tampered")
    local value_tampered = recalled.issue(tampered, KEY, "/the/root", LINE)
    local tampered_file = value_tampered:match("^%x+@(.+)$")
    io.writefile(tampered_file, (io.readfile(tampered_file):gsub(KEY, "ffffff")))
    local honest = counted(KEY)
    check("a file edited after it was written does not match the key", recalled.read(value_tampered, honest.fn), nil)

    local cleared = run("cleared")
    local value_cleared = recalled.issue(cleared, KEY, "/the/root", LINE)
    recalled.read(value_cleared, counted(KEY).fn)
    recalled.clear(value_cleared)
    check("clearing removes the file", os.isfile(value_cleared:match("^%x+@(.+)$")), false)
    check("clearing removes the marker", os.isfile(value_cleared:match("^%x+@(.+)$") .. ".verified"), false)
    check("a cleared verdict is no verdict", recalled.read(value_cleared, counted(KEY).fn), nil)
    recalled.clear(value_cleared)
    recalled.clear("anything")
    recalled.clear(nil)

    local line, key = recalled.parse("\27[0mnoise\n" .. LINE .. "\nkey " .. KEY .. "\n")
    check("the line is taken from prepush's output", line, LINE)
    check("the key is taken from prepush's output", key, KEY)
    check("another check's recall is not the light suites'", (recalled.parse("recalled comments memo (ran 1 s in w at h, 1 s ago)\nkey " .. KEY .. "\n")), nil)
    check("a line without a key is not a verdict", (recalled.parse(LINE .. "\n")), nil)
    check("no output is no verdict", (recalled.parse(nil)), nil)

    local out = {}
    if failures > 0 then
        out[#out + 1] = string.format("%d failures", failures)
    end
    return out
end
