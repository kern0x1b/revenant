local CONTROLS = {
    {name = "stdout-kept", number = 1, scenario = "noise", line = "a line the library printed reached the answer pipe", what = "descriptor 1 left where the library prints"},
    {name = "no-deadline", number = 2, scenario = "errors", line = "where the deadline of the request was due", what = "no deadline of the helper's own"},
    {name = "answered-twice", number = 3, scenario = "pending", line = "was answered 2 times", what = "an id that stays pending after its answer"},
    {name = "no-escapes", number = 4, scenario = "errors", line = "a line that is not of the protocol reached the answer pipe", what = "fields written without escapes"},
    {name = "end-ignored", number = 5, scenario = "closed", line = "the helper did not end: its answer pipe was still open", what = "the end of the request pipe ignored"},
    {name = "no-idle-exit", number = 6, scenario = "idle", line = "the helper did not end after its idle time", what = "no exit after the idle time"},
    {name = "duplicate-taken", number = 7, scenario = "pending", line = "the second request with a pending id was not rejected", what = "a pending id taken a second time"},
    {name = "pipe-signal", number = 8, scenario = "closed", line = "a helper whose answer pipe was closed ended with status 0xd", what = "an answer pipe that may raise SIGPIPE"}
}

function main(out, ...)
    local corpus = import("corpus", {rootdir = path.join(os.scriptdir(), "..", "..", "tools"), anonymous = true})
    local e
    e, out = corpus.setup("recaptchahelper", out)
    local here = os.scriptdir()
    local function o(file)
        return path.join(out, file)
    end
    local function helper(name, control)
        os.tryrm(o(name))
        os.execv("cc", table.join({"-O1", "-Wall", "-fobjc-arc", "-DRCHELPER_NATIVE"}, control and {"-DCONTROL=" .. control} or {},
                                  {"-framework", "Foundation", path.join(here, "helper.m"), "-o", o(name)}))
        return o(name)
    end
    local function drive(program, name, scenario)
        local state, log, said = o("state-" .. name), o("stderr-" .. name .. ".txt"), o("driver-" .. name .. ".txt")
        os.tryrm(state)
        os.tryrm(log)
        os.tryrm(said)
        os.mkdir(state)
        local code = os.execv(o("driver"), table.join({program, o("fixture.dylib"), state, log}, scenario and {scenario} or {}),
                              {stdout = said, stderr = said, try = true, timeout = 120000})
        return code, os.isfile(said) and io.readfile(said) or "", state
    end

    os.execv("cc", {"-O1", "-Wall", "-fobjc-arc", "-dynamiclib", "-framework", "Foundation", path.join(here, "fixture.m"), "-o", o("fixture.dylib")})
    os.execv("cc", {"-O1", "-Wall", path.join(here, "driver.c"), "-o", o("driver")})
    local code, text, state = drive(helper("rchelper"), "rchelper", nil)
    if code ~= 0 or not text:find("\nok: 12 scenarios\n", 1, true) then
        corpus.fail("the helper did not keep the protocol against the fixture library (exit %s):\n%s", tostring(code), text:sub(-2000))
    end
    local kept = os.iorunv("plutil", {"-p", path.join(state, "preferences.plist")})
    if not kept:find("RCA_client_events_fixture", 1, true) then
        corpus.fail("what the library stored in standardUserDefaults is not in the helper's own preferences file:\n%s", kept)
    end
    if not os.isfile(path.join(state, "cache", "Cache.db")) then
        corpus.fail("what the library stored in the shared URL cache is not in the helper's own cache folder %s", path.join(state, "cache"))
    end
    for _, control in ipairs(CONTROLS) do
        local control_code, said = drive(helper("control-" .. control.name, control.number), control.name, control.scenario)
        if control_code == 0 then
            corpus.fail("the control with %s passed: the check does not need that part", control.what)
        end
        if not said:find(control.line, 1, true) then
            corpus.fail("the control with %s failed, but not at '%s':\n%s", control.what, control.line, said:sub(-2000))
        end
    end

    local runtime = corpus.swift_armv7()
    corpus.armv7(e, {"-O2", "-w", "-fobjc-arc", "-I", path.join(e.recompiler, "include"), "-I", here,
                     "-L", path.join(runtime, "lib", "swift", "iphoneos"), "-lswiftFoundation", "-lswiftCore", "-framework", "Foundation", "-Wl,-rpath,@executable_path",
                     path.join(here, "helper.m"), path.join(e.recompiler, "src", "loader", "xl_loader.c"), "-o", o("rchelper-armv7")})
    corpus.sign(e, o("rchelper-armv7"))
    local imports = os.iorunv("nm", {"-u", o("rchelper-armv7")})
    for _, symbol in ipairs({"_posix_spawn", "_fork", "_system", "_popen"}) do
        if imports:find(symbol .. "\n", 1, true) then
            corpus.fail("the armv7 helper imports %s: it starts no process of its own", symbol)
        end
    end
    print("ok: the helper keeps the protocol in twelve scenarios against the fixture library, the library's preferences and URL cache land in the helper's own state, " ..
          "eight controls each fail at their own line, and the armv7 helper links with the loader")
end
