import("fixtures")

local LINE = "recalled light suites memo (ran 297 s in w at 0123456789, 3 min ago)"
local KEY = "a1b2c3"
local OTHER_KEY = "ffffff"

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
    local function folder_of(label)
        local folder = path.join(home, label)
        os.mkdir(folder)
        return folder
    end
    local memo = folder_of("memo")
    local function remember(key, verdict)
        os.mkdir(path.join(memo, "light-suites"))
        io.writefile(path.join(memo, "light-suites", key), "verdict " .. (verdict or "ok") .. "\nseconds 297\nworktree w\nhead 0123456789\nat 1\n")
    end
    local function forget(key)
        os.tryrm(path.join(memo, "light-suites", key))
    end
    local function process(pid)
        local text = try { function () return os.iorunv("ps", {"-ww", "-o", "lstart=", "-p", tostring(pid)}) end } or ""
        return (text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
    end
    local function real(folder)
        return os.iorunv("sh", {"-c", "cd \"$1\" && pwd -P", "sh", folder}):trim()
    end
    local function forged(folder, nonce, key, tree, pid, began, where)
        local file = path.join(folder, string.format("light-suites-%s-%s.verdict", pid, nonce))
        io.writefile(file, table.concat({nonce, key, tree, tostring(pid), began, where or folder, LINE}, "\n") .. "\n")
        return nonce .. "@" .. file
    end

    local pidfile = path.join(home, "owner.pid")
    os.execv("/bin/sh", {"-c", "echo $$ > \"$1\"; while :; do sleep 1; done", "ci_local.lua", pidfile}, {detach = true})
    for _ = 1, 100 do
        if os.isfile(pidfile) and #io.readfile(pidfile):trim() > 0 then
            break
        end
        os.sleep(100)
    end
    local owner = tonumber(io.readfile(pidfile):trim())
    local began = process(owner)
    local me = os.getpid()

    local tree = folder_of("tree")
    local folder = folder_of("valid")
    remember(KEY)
    local value = recalled.issue(folder, KEY, tree, LINE, owner)
    local named = value:match("^%x+@(.+)$")
    check("a value that names its file carries a nonce and the path", (value or ""):find("^%x+@" .. folder:gsub("%p", "%%%0") .. "/") ~= nil, true)
    check("the file is named for its owner and its nonce", path.filename(named), string.format("light-suites-%d-%s.verdict", owner, value:match("^%x+")))
    check("the value is not the line", (value or ""):find(LINE, 1, true), nil)
    check("a verdict the memo holds, for this checkout, from a live ci_local, is read", recalled.read(value, tree, memo), LINE)
    check("it is read again by the next suite", recalled.read(value, tree, memo), LINE)
    check("reading writes nothing beside the verdict file", #os.files(path.join(folder, "*")), 1)

    local link = path.join(home, "tree-link")
    os.ln(tree, link)
    check("the checkout is told by where it really is", recalled.read(value, link, memo), LINE)
    check("another checkout is no verdict", recalled.read(value, folder_of("elsewhere"), memo), nil)
    check("no checkout is no verdict", recalled.read(value, nil, memo), nil)

    check("a forged value is no verdict", recalled.read("anything", tree, memo), nil)
    check("a recall line in the variable is no verdict", recalled.read(LINE, tree, memo), nil)
    check("an empty value is no verdict", recalled.read("", tree, memo), nil)
    check("no value is no verdict", recalled.read(nil, tree, memo), nil)
    check("a value with another nonce is no verdict", recalled.read(("0"):rep(32) .. "@" .. named, tree, memo), nil)
    check("a value that names a missing file is no verdict", recalled.read(value:match("^%x+") .. "@" .. path.join(home, "none"), tree, memo), nil)

    local second = recalled.issue(folder_of("other"), KEY, tree, LINE, owner)
    check("two runs have two nonces", value:match("^%x+") ~= second:match("^%x+"), true)
    check("the nonce of one run does not open the file of another", recalled.read(value:match("^%x+") .. "@" .. second:match("^%x+@(.+)$"), tree, memo), nil)

    local copied_to = folder_of("copied")
    os.cp(named, copied_to)
    check("a file copied to another folder is no verdict", recalled.read(value:match("^%x+") .. "@" .. path.join(copied_to, path.filename(named)), tree, memo), nil)
    local renamed = path.join(folder, "light-suites.verdict")
    os.cp(named, renamed)
    check("a file under another name is no verdict", recalled.read(value:match("^%x+") .. "@" .. renamed, tree, memo), nil)

    local invented = forged(folder_of("invented"), "0123456789abcdef", "deadbeef", real(tree), owner, began)
    check("a file that is consistent in itself but whose key the memo does not hold is no verdict", recalled.read(invented, tree, memo), nil)
    local failed_key = "badbad"
    remember(failed_key, "FAIL")
    check("a key the memo holds as anything but ok is no verdict", recalled.read(forged(folder_of("failed"), "0123456789abcdef", failed_key, real(tree), owner, began), tree, memo), nil)
    check("the same file with a key the memo holds is read", recalled.read(forged(folder_of("honest"), "0123456789abcdef", KEY, real(tree), owner, began), tree, memo), LINE)

    local refused = recalled.issue(folder_of("refused"), OTHER_KEY, tree, LINE, owner)
    check("a key the memo does not hold is refused", recalled.read(refused, tree, memo), nil)
    remember(OTHER_KEY)
    check("a refused verdict is asked again, and the memo's answer is the answer", recalled.read(refused, tree, memo), LINE)
    forget(OTHER_KEY)
    check("a verdict the memo no longer holds is refused again", recalled.read(refused, tree, memo), nil)

    local mine = process(me)
    check("a live process that is not ci_local is no owner", recalled.read(forged(folder_of("not-ci"), "0123456789abcdef", KEY, real(tree), me, mine), tree, memo), nil)
    check("a hand-off cannot be issued for a process that is not running", recalled.issue(folder_of("none"), KEY, tree, LINE, 999999), nil)
    local finished = os.iorunv("sh", {"-c", "echo $$"}):trim()
    check("the process that made the file is gone", process(finished), "")
    check("a run that has ended is no verdict", recalled.read(forged(folder_of("dead"), "0123456789abcdef", KEY, real(tree), finished, began), tree, memo), nil)
    check("a process number that another process has taken is no verdict", recalled.read(forged(folder_of("reused"), "0123456789abcdef", KEY, real(tree), owner, "Mon Jan 1 00:00:00 2001"), tree, memo), nil)

    local tampered = recalled.issue(folder_of("tampered"), KEY, tree, LINE, owner)
    local tampered_file = tampered:match("^%x+@(.+)$")
    io.writefile(tampered_file, (io.readfile(tampered_file):gsub(KEY, OTHER_KEY)))
    check("a file edited after it was written does not match the memo", recalled.read(tampered, tree, memo), nil)
    local short = forged(folder_of("short"), "0123456789abcdef", KEY, real(tree), owner, began)
    local short_file = short:match("^%x+@(.+)$")
    io.writefile(short_file, "0123456789abcdef\n" .. KEY .. "\n")
    check("a file that stops short is no verdict", recalled.read(short, tree, memo), nil)

    local cleared = recalled.issue(folder_of("cleared"), KEY, tree, LINE, owner)
    recalled.clear(cleared)
    check("clearing removes the file", os.isfile(cleared:match("^%x+@(.+)$")), false)
    check("a cleared verdict is no verdict", recalled.read(cleared, tree, memo), nil)
    recalled.clear(cleared)
    recalled.clear("anything")
    recalled.clear(nil)
    local kept = recalled.issue(folder_of("kept"), KEY, tree, LINE, owner)
    recalled.clear(("0"):rep(32) .. "@" .. kept:match("^%x+@(.+)$"))
    check("a value with another nonce clears nothing", os.isfile(kept:match("^%x+@(.+)$")), true)

    check("the memo holds an ok verdict of a check by its name", recalled.holds(memo, "light suites", KEY), true)
    check("the memo does not hold a verdict it has none of", recalled.holds(memo, "light suites", "000000"), false)
    check("the memo does not hold another check's verdict as this one's", recalled.holds(memo, "comments", KEY), false)
    check("the memo does not hold a verdict that is not ok", recalled.holds(memo, "light suites", failed_key), false)

    local line, key = recalled.parse("\27[0mnoise\n" .. LINE .. "\nkey " .. KEY .. "\n")
    check("the line is taken from prepush's output", line, LINE)
    check("the key is taken from prepush's output", key, KEY)
    check("another check's recall is not the light suites'", (recalled.parse("recalled comments memo (ran 1 s in w at h, 1 s ago)\nkey " .. KEY .. "\n")), nil)
    check("a line without a key is not a verdict", (recalled.parse(LINE .. "\n")), nil)
    check("no output is no verdict", (recalled.parse(nil)), nil)

    os.execv("kill", {tostring(owner)}, {try = true})

    local out = {}
    if failures > 0 then
        out[#out + 1] = string.format("%d failures", failures)
    end
    return out
end
