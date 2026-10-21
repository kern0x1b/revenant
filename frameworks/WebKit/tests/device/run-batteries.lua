local USAGE = [[usage: ./xmakew l frameworks/WebKit/tests/device/run-batteries.lua [--batteries DIR] [BATTERY...]
  runs the JavaScript batteries in tests/device/js under jsc on the phone, with the engine just built.
  DIR is the batteries folder the webkit-engine package installs, holding jsc, its JavaScriptCore
  and the C++ runtime it was built against; by default it is the installed package's. Every file is
  compared with the phone's copy by content and pushed when it differs, so a battery never runs
  against a stale engine. A battery that prints no verdict line died partway and fails.]]

local remote = "/tmp/jscrun"

local function verdict_of(output)
    local body, status = output:match("^(.*)EXIT=(%d+)%s*$")
    if not body then
        body, status = output, "?"
    end
    local lines, verdict, broken, reported = {}, "", false, {}
    for line in body:gmatch("[^\n]+") do
        if line:trim() ~= "" then
            table.insert(lines, line)
            local lower = line:lower()
            if lower:find("all ok", 1, true) or lower:find("failure", 1, true) then
                verdict = line
            end
            local bad = lower:startswith("fail") or lower:find("exception", 1, true) or lower:find("segmentation", 1, true)
            if bad then
                broken = true
            end
            if (bad or lower:find("failure", 1, true)) and #reported < 10 then
                table.insert(reported, line)
            end
        end
    end
    return {status = status, line = verdict, failed = status ~= "0" or verdict == "" or broken, reported = reported}
end

local function remote_hashes(phone)
    local listing = phone:run("for f in " .. remote .. "/jsc " .. remote .. "/Frameworks/*.dylib " .. remote ..
                              "/Frameworks/*.framework/*; do if [ -f \"$f\" ]; then openssl md5 \"$f\"; fi; done")
    local hashes = {}
    for line in listing:gmatch("[^\n]+") do
        local name, digest = line:match("^MD5%((.-)%)= (%x+)")
        if name then
            hashes[name] = digest:lower()
        end
    end
    return hashes
end

local function push_if_changed(phone, localfile, destination, hashes)
    if hashes[destination] == hash.md5(localfile):lower() then
        return
    end
    print("  syncing %s (%d KB)", path.filename(destination), os.filesize(localfile) // 1024)
    phone:copy(localfile, destination)
end

function main(...)
    local tree = import("tree", {rootdir = path.join(os.scriptdir(), "..", "..", "tools", "lib"), anonymous = true})
    local harness = import("harness", {rootdir = os.scriptdir(), anonymous = true})
    local given, named = tree.arguments({...}, {batteries = "value", help = "switch"})
    if given.help then
        print(USAGE)
        return
    end
    local batteries = given.batteries and path.absolute(given.batteries) or path.join(tree.where("webkit-engine"), "batteries")
    local jsc = path.join(batteries, "jsc")
    local frameworks = path.join(batteries, "Frameworks")
    if not os.isfile(jsc) then
        raise("%s holds no jsc: install the webkit-engine package for iphoneos, or name a batteries folder", batteries)
    end
    local scripts = {}
    if #named > 0 then
        for _, name in ipairs(named) do
            table.insert(scripts, path.absolute(name))
        end
    else
        scripts = os.files(path.join(os.scriptdir(), "js", "*.js"))
        table.sort(scripts)
    end
    if #scripts == 0 then
        raise("no batteries under %s", path.join(os.scriptdir(), "js"))
    end
    local phone = harness.phone()
    if not phone:reachable() then
        raise("the phone is not reachable: check device.env (see tests/data/device.env.example)")
    end
    phone:run("mkdir -p " .. remote .. "/Frameworks/JavaScriptCore.framework")
    local hashes = remote_hashes(phone)
    push_if_changed(phone, jsc, remote .. "/jsc", hashes)
    for _, file in ipairs(os.files(path.join(frameworks, "**"))) do
        local relative = path.relative(file, frameworks)
        local destination = remote .. "/Frameworks/" .. relative:gsub("\\", "/")
        phone:run("mkdir -p " .. path.directory(destination))
        push_if_changed(phone, file, destination, hashes)
    end
    for _, script in ipairs(scripts) do
        phone:copy(script, remote .. "/")
    end
    local failures = 0
    for _, script in ipairs(scripts) do
        local name = path.filename(script)
        local output = phone:run("cd " .. remote .. " && DYLD_FRAMEWORK_PATH=" .. remote .. "/Frameworks ./jsc " .. name ..
                                 " 2>&1; echo EXIT=$?")
        local verdict = verdict_of(output)
        if verdict.failed then
            failures = failures + 1
            print("== %s FAILED (exit %s) ==", name, verdict.status)
            for _, line in ipairs(verdict.reported) do
                print(line)
            end
            if verdict.line == "" then
                print("  no verdict line: battery did not finish")
            end
        else
            print("%s: %s", name, verdict.line)
        end
    end
    print("")
    if failures > 0 then
        raise("batteries: FAILED (%d)", failures)
    end
    print("batteries: PASSED")
end
