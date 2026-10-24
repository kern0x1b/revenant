local tree = import("lib.tree", {rootdir = os.scriptdir(), anonymous = true})
local driver = import("driver", {rootdir = path.join(os.scriptdir(), "..", "tests", "package"), anonymous = true})

local USAGE = [[usage: ./xmakew l frameworks/SwiftUI/tools/emulate.lua tests|snapshots|perf|package [options]
  tests                     the engine tests (SwiftUITests) as the guest's first process
  snapshots [--accept] [--only=NAME]
                            the snapshot bundle through SpringBoard, its trees against tests/data/snapshots/
  perf                      the demo's timing scenarios through SpringBoard
  package                   the platform and demo packages installed as dpkg installs them, the demo launched and checked to draw
  --device=ID --release=V   the emulated device and release (tests: iPhone4,1 6.1.3; the others: iPod4,1 6.0)
  --seconds=N --timeout=N   xmake emulate's -s and -t]]

local function options(arguments, defaults)
    local chosen = table.copy(defaults)
    for _, argument in ipairs(arguments) do
        local key, value = argument:match("^%-%-([%w%-]+)=(.*)$")
        if key and chosen[key] ~= nil then
            chosen[key] = value
        elseif argument == "--accept" then
            chosen.accept = true
        else
            raise("%s is not an option here\n%s", argument, USAGE)
        end
    end
    return chosen
end

local function xmake(out, name, argv)
    local log = path.join(out, name .. ".log")
    local file = io.open(log, "w")
    local status = os.execv(os.programfile(), argv, {curdir = tree.revenant(), stdout = file, stderr = file, try = true})
    file:close()
    return status, log
end

local function configure(out, settings)
    local argv = {"f", "-c", "-P", ".", "-p", "iphoneos", "-a", "armv7", "--emulate=y", "-y"}
    for key, value in pairs(settings or {}) do
        table.insert(argv, "--" .. key .. "=" .. value)
    end
    local status, log = xmake(out, "configure", argv)
    if status ~= 0 then
        raise("the configure failed with %s; its log is %s", status, log)
    end
end

local function restore(out, settings)
    local argv = {"f", "-P", ".", "-y"}
    for key, value in pairs(settings) do
        table.insert(argv, "--" .. key .. "=" .. value)
    end
    local status, log = xmake(out, "restore", argv)
    if status ~= 0 then
        raise("putting the project's options back failed with %s; its log is %s", status, log)
    end
end

local function emulate(out, name, chosen, ...)
    local argv = {"emulate", "-P", ".", "-d", chosen.device, "-r", chosen.release, "-s", chosen.seconds, "-t", chosen.timeout, ...}
    local status, log = xmake(out, name, argv)
    local text = io.readfile(log)
    io.write(text)
    local folder = nil
    for line in text:gmatch("[^\n]+") do
        folder = line:gsub("\27%[[%d;]*m", ""):match("^run folder (.+)$") or folder
    end
    return status, folder, log
end

local function lines_with(file, words)
    if not os.isfile(file) then
        return
    end
    for line in io.readfile(file, {encoding = "binary"}):gmatch("[^\n]+") do
        for _, word in ipairs(words) do
            if line:find(word, 1, true) then
                print(line)
                break
            end
        end
    end
end

local function tests(arguments)
    local chosen = options(arguments, {device = "iPhone4,1", release = "6.1.3", seconds = "240", timeout = "1500"})
    local out = tree.fresh("tests")
    configure(out)
    local installed, install_log = xmake(out, "install", {"emulate", "-P", ".", "-d", chosen.device, "-r", chosen.release, "install"})
    if installed ~= 0 then
        raise("xmake emulate install failed with %s; its log is %s", installed, install_log)
    end
    local status, folder, log = emulate(out, "run", chosen, "run", "/usr/libexec/SwiftUITests")
    print("the run itself exited %s", status)
    if not folder or not os.isdir(path.join(folder, "results")) then
        raise("this run named no results folder; its log is %s", log)
    end
    os.cp(path.join(folder, "results", "*"), out)
    if os.isfile(path.join(folder, "verdict.json")) then
        os.cp(path.join(folder, "verdict.json"), out)
    end
    lines_with(path.join(out, "test.stdout"), {"FAIL", "checks "})
    io.writefile(path.join(out, "verdict.txt"), string.format("exit=%s run folder %s\n", status, folder))
    print("exit=%s run folder %s, kept in %s", status, folder, out)
    os.exit(status)
end

local function references()
    local names = {}
    for _, file in ipairs(os.files(tree.root("tests", "data", "snapshots", "*.txt"))) do
        names[path.filename(file)] = true
    end
    return names
end

local function snapshots(arguments)
    local chosen = options(arguments, {device = "iPod4,1", release = "6.0", seconds = "240", timeout = "3000", only = ""})
    local out = tree.fresh("snapshots")
    local shots = path.join(out, "shots")
    os.mkdir(shots)
    configure(out, {swiftui_snapshot_only = chosen.only})
    local status, folder, log = emulate(out, "launch", chosen, "launch", "space.kern0x1b.swiftui.snapshots", "until-exit")
    restore(out, {swiftui_snapshot_only = ""})
    local rendered = folder and path.join(folder, "results", "swiftui-snapshots")
    if not rendered or not os.isdir(rendered) then
        raise("no snapshots were written; the launch log is %s", log)
    end
    os.cp(path.join(rendered, "*"), shots)
    if os.isfile(path.join(folder, "verdict.json")) then
        os.cp(path.join(folder, "verdict.json"), out)
    end
    lines_with(path.join(folder, "results", "app.stdout"), {"snapshot"})
    if status ~= 0 then
        raise("the launch failed, exit=%s; its log is %s", status, log)
    end
    local wanted = chosen.only ~= "" and {[chosen.only .. ".txt"] = true} or references()
    local got = {}
    for _, file in ipairs(os.files(path.join(shots, "*.txt"))) do
        got[path.filename(file)] = true
    end
    if table.empty(got) then
        raise("no scenario was rendered; the launch log is %s", log)
    end
    local missing, extra = {}, {}
    for name in pairs(wanted) do
        if not got[name] then
            table.insert(missing, name)
        end
    end
    for name in pairs(got) do
        if not wanted[name] then
            table.insert(extra, name)
        end
    end
    table.sort(missing)
    table.sort(extra)
    if #missing > 0 then
        raise("these scenarios were not rendered: %s", table.concat(missing, " "))
    end
    if #extra > 0 then
        raise("the run wrote scenarios there are no references for: %s", table.concat(extra, " "))
    end
    local differs = 0
    for _, name in ipairs(table.orderkeys(got)) do
        local shot, reference = path.join(shots, name), tree.root("tests", "data", "snapshots", name)
        if not os.isfile(reference) or chosen.accept then
            os.cp(shot, reference)
            print("reference %s written", name)
        elseif io.readfile(shot, {encoding = "binary"}) == io.readfile(reference, {encoding = "binary"}) then
            print("match %s", name)
        else
            differs = differs + 1
            print("DIFFERS %s", name)
            local diff = os.iorunv("diff", {"-u", reference, shot}, {try = true}) or ""
            local count = 0
            for line in diff:gmatch("[^\n]*\n?") do
                count = count + 1
                if count > 20 or line == "" then
                    break
                end
                io.write(line)
            end
        end
    end
    print("pictures and trees in %s", shots)
    os.exit(differs > 0 and 1 or 0)
end

local function perf(arguments)
    local chosen = options(arguments, {device = "iPod4,1", release = "6.0", seconds = "240", timeout = "3000"})
    local out = tree.fresh("perf")
    configure(out, {swiftui_perf = "y"})
    local status, folder, log = emulate(out, "launch", chosen, "launch", "space.kern0x1b.swiftui.demo", "until-exit")
    restore(out, {swiftui_perf = "n"})
    local stdout = folder and path.join(folder, "results", "app.stdout")
    if not stdout or not os.isfile(stdout) then
        raise("the demo left no output; the launch log is %s", log)
    end
    os.cp(stdout, out)
    local timings = io.readfile(stdout, {encoding = "binary"})
    if not timings:find("perf done", 1, true) then
        raise("the demo did not finish its timings (exit=%s); its output is %s", status, path.join(out, "app.stdout"))
    end
    lines_with(stdout, {"perf"})
end

local function package(arguments)
    local chosen = options(arguments, {device = "iPhone4,1", release = "6.1.3", seconds = "240", timeout = "3600"})
    local out = tree.fresh("package")
    configure(out, {component = "SwiftUIDemo"})
    local status, folder, log = emulate(out, "launch", chosen, "launch", "space.kern0x1b.swiftui.demo")
    restore(out, {component = ""})
    local text = io.readfile(log):gsub("\27%[[%d;]*m", "")
    local found = driver.failures(text, folder)
    if folder and os.isfile(path.join(folder, "verdict.json")) then
        os.cp(path.join(folder, "verdict.json"), out)
    end
    if status ~= 0 and #found == 0 then
        table.insert(found, string.format("xmake emulate launch exited %s", status))
    end
    if #found > 0 then
        for _, failure in ipairs(found) do
            cprint("${red}%s", failure)
        end
        raise("the demo's packages do not install and run; the launch log is %s", log)
    end
    print("the demo's packages installed, the demo ran and drew; the verdict is in %s", out)
end

function main(action, ...)
    local actions = {tests = tests, snapshots = snapshots, perf = perf, package = package}
    if not actions[action] then
        raise(USAGE)
    end
    actions[action]({...})
end
