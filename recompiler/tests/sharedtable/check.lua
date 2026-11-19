local CONTROLS = {
    {define = "1", line = "FAIL shared.exclusion", what = "no lock around the tables"},
    {define = "2", line = "FAIL shared.claim", what = "no second look after the write side is taken"},
    {define = "3", line = "FAIL shared.atomic", what = "the lookups of one class each in a read section of their own"}
}

function main(out)
    local corpus = import("corpus", {rootdir = path.join(os.scriptdir(), "..", "..", "tools"), anonymous = true})
    local _
    _, out = corpus.setup("sharedtable", out)
    local runtime = path.join(os.scriptdir(), "..", "..", "src", "runtime")
    local source = path.join(os.scriptdir(), "main.c")
    local function build(name, defines)
        local binary = path.join(out, name)
        os.tryrm(binary)
        os.execv("cc", table.join({"-O1", "-Wall", "-I", runtime}, defines, {source, "-framework", "CoreFoundation", "-o", binary}))
        return binary
    end
    local log = path.join(out, "run.txt")
    os.tryrm(log)
    local code = os.execv(build("sharedtable", {}), {}, {envs = {MallocScribble = "1", MallocGuardEdges = "1"}, stdout = log, stderr = log, try = true, timeout = 180000})
    local text = os.isfile(log) and io.readfile(log) or ""
    if code ~= 0 or not text:find("ok: ", 1, true) then
        corpus.fail("the tables behind the module's lock did not hold (exit %s):\n%s", tostring(code), text:sub(1, 2000))
    end
    for _, control in ipairs(CONTROLS) do
        local control_log = path.join(out, "control-" .. control.define .. ".txt")
        os.tryrm(control_log)
        local control_code = os.execv(build("control-" .. control.define, {"-DCONTROL=" .. control.define}), {},
                                      {stdout = control_log, stderr = control_log, try = true, timeout = 180000})
        local said = os.isfile(control_log) and io.readfile(control_log) or ""
        if control_code == 0 then
            corpus.fail("the control with %s passed: the test does not need that part of the discipline", control.what)
        end
        if not said:find(control.line, 1, true) then
            corpus.fail("the control with %s failed, but not at %s:\n%s", control.what, control.line, said:sub(1, 2000))
        end
    end
    local classes = io.readfile(path.join(runtime, "swift_classes.m"))
    local direct = classes:match("CFDictionary%u%w*%(")
    if direct then
        corpus.fail("swift_classes.m calls %s itself: every table of that file is shared between threads and goes through xl_shared_table.h", direct:sub(1, -2))
    end
    local number = 0
    for line in io.readfile(path.join(runtime, "objc_bridge.m")):gmatch("[^\n]*") do
        number = number + 1
        if line:find("xl_variant_cache", 1, true) and not line:find("xl_shared_", 1, true) then
            corpus.fail("objc_bridge.m line %d reaches the variant cache without xl_shared_table.h: %s", number, line)
        end
    end
    print(text:match("ok: [^\n]*") .. "; the controls without the lock, without the second look and with split lookups each failed at their own line")
end
