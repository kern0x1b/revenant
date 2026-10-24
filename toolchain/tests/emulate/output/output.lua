import("core.base.json")

local runs = import("runs", {rootdir = path.join(os.scriptdir(), "..", "..", "common"), anonymous = true})

local KNOWN = "revenant-emulate-output"

local function field(verdict, what)
    local document = json.decode(io.readfile(verdict))
    if what == "runner" then
        return document.output == 1 and "tree" or "installed"
    end
    local value = document[what]
    if type(value) == "number" and value == math.floor(value) then
        return string.format("%d", value)
    end
    return value == nil and "" or tostring(value)
end

local function runner(verdict)
    return try {
        function ()
            return field(verdict, "runner")
        end,
        catch {
            function ()
                return "unknown"
            end
        }
    }
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

local function yes(flag)
    return flag and "yes" or "no"
end

function main(device, release)
    device = device or "iPhone2,1"
    release = release or "6.1.3"
    local here = os.scriptdir()
    local out = runs.folder("emulate-output")
    os.mkdir(out)
    os.setenv("REVENANT_EMULATOR_ROOT", path.join(out, "emulator"))

    local function xmake(args, log, opt)
        return os.execv(os.programfile(), args, table.join({curdir = here, stdout = log, stderr = log}, opt or {}))
    end
    xmake({"f", "-p", "iphoneos", "-a", "armv7", "-y"}, path.join(out, "configure.log"))
    xmake({"emulate", "install", "-d", device, "-r", release}, path.join(out, "install.log"))

    local status = 0
    local marker = path.join(out, ".marked")
    for _, mode in ipairs({"end", "hang"}) do
        local log = path.join(out, mode .. ".log")
        local failed = false
        local function fail(text)
            print(text)
            failed = true
        end

        io.writefile(marker, "")
        local run = {"emulate", "-d", device, "-r", release, "-s", "60", "-t", "900", "run", "/usr/libexec/emulateoutput"}
        if mode == "hang" then
            run = {"emulate", "-d", device, "-r", release, "-s", "6", "-t", "900", "run", "/usr/libexec/emulateoutput", "--hang"}
        end
        local ran = xmake(run, log, {try = true})
        print(mode .. ": the run itself exited " .. ran)

        local verdicts = written_since(device, marker)
        if #verdicts == 0 then
            fail(mode .. ": no run's verdict was written after this run; the log is " .. log)
        elseif #verdicts > 1 then
            fail(mode .. ": " .. #verdicts .. " runs wrote a verdict after this run began, so which is this one is not known:")
            for _, verdict in ipairs(verdicts) do
                fail("  " .. verdict)
            end
        else
            local verdict = verdicts[1]
            local which_runner = runner(verdict)
            print(mode .. ": the runner was " .. which_runner .. " (" .. verdict .. ")")
            local stdout = field(verdict, "stdout")
            local stderr = field(verdict, "stderr")

            local control = stderr ~= "" and runs.contains(stderr, KNOWN .. ": stderr line 1 reached the host")
            if control then
                print(mode .. ": the control, unbuffered stderr, is in the file the verdict names")
            else
                fail(mode .. ": the control stderr is NOT there (" .. (stderr ~= "" and stderr or "no path")
                     .. "); the file was not captured at all")
            end

            local first = stdout ~= "" and runs.contains(stdout, KNOWN .. ": stdout line 1 reached the host")
            if first then
                print(mode .. ": the program's buffered stdout reached the file")
            else
                fail(mode .. ": the program's buffered stdout did NOT reach the file (" .. (stdout ~= "" and stdout or "no path") .. ")")
            end

            local second = mode == "hang" and stdout ~= "" and runs.contains(stdout, KNOWN .. ": stdout line 2 reached the host")

            local filtered = path.join(out, mode .. "-filtered.log")
            xmake({"emulate", "-d", device, "-r", release, "log", KNOWN}, filtered, {try = true})
            local logged = runs.contains(filtered, KNOWN .. ": stdout line 1 reached the host")
            if logged then
                print(mode .. ": the line comes back through xmake emulate log")
            else
                fail(mode .. ": the line does NOT come back through xmake emulate log")
            end

            if mode == "hang" then
                if which_runner == "tree" then
                    if control and first and second and logged then
                        print("hang: with the tree's runner, nothing a program wrote and never flushed was lost")
                    else
                        fail(string.format("hang: THE TREE'S RUNNER LOST IT: control=%s first=%s second=%s logged=%s",
                                           yes(control), yes(first), yes(second), yes(logged)))
                    end
                elseif not first or not second then
                    print("hang: UNMEASURED - the installed runner buffers, so the line a program never flushed is")
                    print("      gone, which is the behaviour the unbuffered spawn fixes. Rerun with the addon")
                    print("      rebuilt from this tree; this run is not a pass of it.")
                else
                    fail("hang: the line survived under a runner that has no unbuffered spawn, so the verdict's")
                    fail("      runner key says installed but the behaviour says otherwise; not counting it.")
                end
            end
        end

        if failed then
            print(mode .. ": a check of this mode failed, so this mode exits 1")
            status = 1
        else
            print(mode .. ": every check of this mode passed, so this mode exits 0")
        end
    end
    os.exit(status)
end
