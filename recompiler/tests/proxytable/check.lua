function main(out)
    local corpus = import("corpus", {rootdir = path.join(os.scriptdir(), "..", "..", "tools"), anonymous = true})
    local _
    _, out = corpus.setup("proxytable", out)
    local runtime = path.join(os.scriptdir(), "..", "..", "src", "runtime")
    local binary = path.join(out, "proxytable")
    local flags = {"-O1", "-Wall", "-fno-objc-arc", "-fobjc-weak", "-I", runtime}
    os.execv("cc", table.join(flags, {"-c", path.join(runtime, "proxy.m"), "-o", path.join(out, "proxy.o")}))
    os.execv("cc", table.join(flags, {path.join(os.scriptdir(), "main.m"), path.join(out, "proxy.o"), "-framework", "Foundation", "-o", binary}))
    os.execv(binary, {}, {envs = {MallocScribble = "1", MallocGuardEdges = "1"}, timeout = 600000})
    local log = path.join(out, "control.txt")
    local code = os.execv(binary, {"1000"}, {envs = {XL_PROXY = "0"}, stdout = log, stderr = log, try = true})
    if code == 0 then
        corpus.fail("the control with XL_PROXY=0 passed: the test does not need the proxy")
    end
    if not io.readfile(log):find("FAIL proxy.in", 1, true) then
        corpus.fail("the control with XL_PROXY=0 failed, but not at proxy.in:\n%s", io.readfile(log))
    end
    local owned_log = path.join(out, "control-owned.txt")
    local owned_code = os.execv(binary, {"1000"}, {envs = {XL_OWNED = "0"}, stdout = owned_log, stderr = owned_log, try = true})
    if owned_code == 0 then
        corpus.fail("the control with XL_OWNED=0 passed: the test does not need xl_proxy_owned")
    end
    if not io.readfile(owned_log):find("FAIL proxy.owned.alive", 1, true) then
        corpus.fail("the control with XL_OWNED=0 failed, but not at proxy.owned.alive:\n%s", io.readfile(owned_log))
    end
    print("ok: the proxy table made, found, released and raced proxies of guest objects, a result the guest returned at +1 stayed alive through two pool entries, and the controls without the proxy and without the owned result failed")
end
