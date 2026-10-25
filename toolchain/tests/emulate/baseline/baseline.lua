import("core.base.json")

local runs = import("runs", {rootdir = path.join(os.scriptdir(), "..", "..", "common"), anonymous = true})

local PROGRAM = "emulatebaseline"

local function field(verdict, what)
    local document = json.decode(io.readfile(verdict))
    local value = document[what]
    return value == nil and "" or tostring(value)
end

local function written_since(device, marker)
    local found = {}
    for _, file in ipairs(os.files(path.join(runs.images(), "**", device .. "_*", "run", "verdict.json"))) do
        if os.mtime(file) > os.mtime(marker) then
            table.insert(found, file)
        end
    end
    table.sort(found)
    return found
end

local function line_of(text, prefix)
    for line in text:gmatch("[^\n]+") do
        if line:find(prefix, 1, true) == 1 then
            return line
        end
    end
end

function main(device, release)
    device = device or "iPhone4,1"
    release = release or "6.1.3"
    local here = path.absolute(os.scriptdir())
    local out = runs.folder("emulate-baseline")
    os.mkdir(out)
    os.setenv("REVENANT_EMULATOR_ROOT", path.join(out, "emulator"))

    local function xmake(args, log, opt)
        local command = {args[1], "-P", here}
        for index = 2, #args do
            table.insert(command, args[index])
        end
        return os.execv(os.programfile(), command, table.join({curdir = here, stdout = log, stderr = log}, opt or {}))
    end
    xmake({"f", "-p", "iphoneos", "-a", "armv7", "-y"}, path.join(out, "configure.log"))
    xmake({"emulate", "-d", device, "-r", release, "install"}, path.join(out, "install.log"))

    local marker = path.join(out, ".marked")
    io.writefile(marker, "")
    local log = path.join(out, "run.log")
    local ran = xmake({"emulate", "-d", device, "-r", release, "-s", "60", "-t", "900", "run", "/usr/libexec/" .. PROGRAM}, log, {try = true})
    print("the run itself exited " .. tostring(ran))

    local verdicts = written_since(device, marker)
    if #verdicts ~= 1 then
        print("expected one verdict after this run began, found " .. #verdicts .. "; the log is " .. log)
        os.exit(1)
    end
    local stdout = field(verdicts[1], "stdout")
    local text = stdout ~= "" and io.readfile(stdout) or ""
    local plain = line_of(text, "BASELINE-PROBE plain ")
    local raised = line_of(text, "BASELINE-PROBE raised ")
    local shift = line_of(text, "BASELINE-PROBE shift=")
    local done = line_of(text, "BASELINE-PROBE-DONE")
    for _, value in ipairs({plain or "", raised or "", shift or "", done or ""}) do
        if value ~= "" then
            print(value)
        end
    end
    if not done or not plain or not raised or not shift then
        print("the probe did not finish its measurements; its stdout is " .. stdout)
        os.exit(1)
    end
    print("BASELINE-PROBE measured on " .. device .. " iOS " .. release)
    os.exit(0)
end
