local CONTROLS = {
    {name = "one-counter", define = "-DCONTROL=1", line = "FAIL stats.total", what = "one set of counters for all threads and no lock"},
    {name = "no-fold", define = "-DXL_STATS_FOLD_TICKS=0xffffffffu", line = "FAIL stats.wrap", what = "a thread that never adds its own time to the total"},
    {name = "miscounted", define = "-DCONTROL=2", line = "the windows give a class and selector more messages than were sent to it",
     what = "one message in a thousand counted for another class and selector"}
}

function main(out)
    local corpus = import("corpus", {rootdir = path.join(os.scriptdir(), "..", "..", "tools"), anonymous = true})
    local _
    _, out = corpus.setup("statsthreads", out)
    local runtime = path.join(os.scriptdir(), "..", "..", "src", "runtime")
    local source = path.join(os.scriptdir(), "main.c")
    local function run(name, define, envs)
        local binary, log = path.join(out, name), path.join(out, name .. ".txt")
        os.tryrm(binary)
        os.tryrm(log)
        os.execv("cc", table.join({"-O1", "-Wall", "-I", runtime}, define and {define} or {}, {source, "-o", binary}))
        local code = os.execv(binary, {}, {envs = envs, stdout = log, stderr = log, try = true, timeout = 180000})
        return code, os.isfile(log) and io.readfile(log) or ""
    end
    local code, text = run("statsthreads", nil, {MallocScribble = "1", MallocGuardEdges = "1"})
    if code ~= 0 or not text:find("ok: ", 1, true) then
        corpus.fail("the per-thread counters of xl-stats did not add up (exit %s):\n%s", tostring(code), text:sub(1, 2000))
    end
    for _, control in ipairs(CONTROLS) do
        local control_code, said = run("control-" .. control.name, control.define, nil)
        if control_code == 0 then
            corpus.fail("the control with %s passed: the test does not need that part", control.what)
        end
        if not said:find(control.line, 1, true) then
            corpus.fail("the control with %s failed, but not at %s:\n%s", control.what, control.line, said:sub(1, 2000))
        end
    end
    print(text:match("ok: [^\n]*") .. "; the controls with one unlocked set of counters, without a thread's own fold and with messages counted for another class each failed at their own line")
end
