import("core.base.signal")
import("lib.detect.find_program")

local USAGE = "usage: ./xmakew l agent-skills/tests/run.lua [--runtime claude] [--hours N] SCENARIO... | all"

local function arguments(...)
    local chosen = {runtime = "claude", hours = 6, scenarios = {}}
    local given = {...}
    local i = 1
    while i <= #given do
        local argument = given[i]
        if argument == "--runtime" or argument == "--hours" then
            chosen[argument:sub(3)] = assert(given[i + 1], argument .. " takes a value")
            i = i + 2
        elseif argument == "-h" or argument == "--help" then
            print(USAGE)
            os.exit(0)
        else
            table.insert(chosen.scenarios, argument)
            i = i + 1
        end
    end
    chosen.hours = tonumber(chosen.hours) or raise("--hours takes a number")
    return chosen
end

local function git(top, argv)
    return os.iorunv("git", table.join({"-C", top}, argv)):gsub("%s+$", "")
end

local function refuse(code, message, ...)
    io.stderr:write(string.format(message, ...) .. "\n")
    os.exit(code)
end

local function append(file, text)
    local handle = io.open(file, "a")
    handle:write(text)
    handle:close()
end

local function guard(folder, xmake)
    os.mkdir(folder)
    local file = path.join(folder, "xmake")
    io.writefile(file, table.concat({
        "#!/bin/bash",
        "for a in \"$@\"; do [ \"$a\" = --force ] && { echo \"refused by the test guard: --force damages the shared store\" >&2; exit 97; }; done",
        "[ \"${1:-}\" = emulate ] && printf ' %s' \"$@\" | grep -q ' clean' && { echo \"refused by the test guard: emulate clean wipes shared emulator state\" >&2; exit 97; }",
        "exec \"" .. xmake .. "\" \"$@\"",
        ""}, "\n"))
    os.execv("chmod", {"+x", file})
end

function main(...)
    local chosen = arguments(...)
    local tests = path.absolute(os.scriptdir())
    local repo = path.directory(tests)
    local top = git(repo, {"rev-parse", "--show-toplevel"})
    local workspace = import("@addon.revenant.workspace", {anonymous = true})
    local credentials = import("credentials", {rootdir = tests, anonymous = true})

    if #chosen.scenarios == 0 then
        refuse(2, "name a scenario, or all")
    end
    if chosen.scenarios[1] == "all" then
        chosen.scenarios = {}
        for _, folder in ipairs(os.dirs(path.join(tests, "data", "scenarios", "*"))) do
            table.insert(chosen.scenarios, path.filename(folder))
        end
        table.sort(chosen.scenarios)
    end
    if os.getenv("REVENANT_AGENT_SKILLS_ISOLATION_APPROVED") ~= "1" then
        refuse(3, "refused: set REVENANT_AGENT_SKILLS_ISOLATION_APPROVED=1 to run with the approved isolation")
    end
    if os.execv("git", {"-C", top, "diff", "--quiet", "HEAD", "--"}, {try = true}) ~= 0 then
        refuse(2, "commit first: the plugin is installed from HEAD")
    end
    if chosen.runtime ~= "claude" then
        refuse(2, "runtime %s: not supported yet", chosen.runtime)
    end

    local commit = git(repo, {"rev-parse", "--short", "HEAD"})
    local run = os.date("%Y%m%d-%H%M%S") .. "-" .. commit
    local evidence_root = path.join(workspace.run("agent-skills"), run)
    local scratch = workspace.fresh(path.join("agent-skills", "scratch"))
    if (scratch .. "/"):startswith(top .. "/") then
        refuse(2, "scratch %s is inside revenant", scratch)
    end
    os.mkdir(evidence_root)
    print("run %s, scratch %s", run, scratch)

    local real_home = os.getenv("HOME")
    local brew_prefix = try { function () return os.iorunv("brew", {"--prefix"}):gsub("%s+$", "") end } or "/opt/homebrew"
    local xmake = find_program("xmake") or raise("no xmake on PATH: the scenarios run the xmake a user installs")
    local clone, plugin, guard_folder = path.join(scratch, "revenant"), path.join(scratch, "revenant", "agent-skills"), path.join(scratch, "guard")
    os.execv("git", {"clone", "-q", top, clone})
    os.execv("git", {"-C", clone, "checkout", "-q", commit})
    guard(guard_folder, xmake)
    os.mkdir(path.join(scratch, "tmp"))

    local homes = {}
    local function cleanup()
        for _, home in ipairs(homes) do
            os.tryrm(home)
        end
    end
    signal.register(signal.SIGINT, function ()
        cleanup()
        os.exit(130)
    end)

    local status = 0
    local errors
    try {
        function ()
            for _, id in ipairs(chosen.scenarios) do
                local scenario = path.join(tests, "data", "scenarios", id)
                if not os.isfile(path.join(scenario, "request.md")) then
                    io.stderr:write("no scenario " .. id .. "\n")
                    status = 1
                else
                    local project, evidence = path.join(scratch, "projects", id), path.join(evidence_root, id)
                    os.mkdir(project)
                    os.mkdir(evidence)
                    local home = path.join(scratch, "home-" .. id)
                    table.insert(homes, home)
                    os.mkdir(path.join(home, ".claude"))
                    os.execv("chmod", {"700", home})
                    local vars = {"HOME=" .. home, "USER=" .. os.getenv("USER"), "LOGNAME=" .. os.getenv("USER"), "SHELL=/bin/zsh",
                                  "LANG=en_US.UTF-8", "TERM=xterm-256color", "TMPDIR=" .. path.join(scratch, "tmp"),
                                  "PATH=" .. table.concat({guard_folder, brew_prefix .. "/bin", brew_prefix .. "/sbin", "/usr/local/bin",
                                                           "/usr/bin", "/bin", "/usr/sbin", "/sbin"}, ":"),
                                  "XMAKE_GLOBALDIR=" .. real_home, "REVENANT_HOME=" .. path.join(real_home, ".revenant")}
                    local login = path.join(home, ".claude", ".credentials.json")
                    io.writefile(login, "")
                    os.execv("chmod", {"600", login})
                    credentials.store(login, os.iorunv("security", {"find-generic-password", "-s", "Claude Code-credentials", "-w"}))
                    local left = credentials.seconds_left(login)
                    local function clean_env(argv, opt)
                        return os.execv("env", table.join({"-i"}, vars, argv), table.join({try = true}, opt or {}))
                    end
                    local limit = chosen.hours * 3600
                    if left - 900 < limit then
                        limit = left - 900
                    end
                    local installed = false
                    if limit < 3600 then
                        io.stderr:write(string.format("%s: the login expires in %d min; start again after it is refreshed\n", id, left // 60))
                    else
                        local log = path.join(evidence, "install.log")
                        local file = io.open(log, "w")
                        clean_env({"claude", "plugin", "marketplace", "add", clone}, {stdout = file, stderr = file})
                        clean_env({"claude", "plugin", "install", "agent-skills@revenant", "--scope", "user"}, {stdout = file, stderr = file})
                        clean_env({"claude", "plugin", "list"}, {stdout = file, stderr = file})
                        file:close()
                        installed = io.readfile(log):find("agent-skills", 1, true) ~= nil
                        if not installed then
                            io.stderr:write("the plugin did not install; see " .. log .. "\n")
                        end
                        for _, folder in ipairs({".claude/skills", ".agents/skills", ".codex", ".config/opencode"}) do
                            if installed and os.exists(path.join(home, folder)) then
                                io.stderr:write("the clean HOME already has " .. folder .. "\n")
                                installed = false
                            end
                        end
                    end
                    if not installed then
                        os.tryrm(home)
                        status = 1
                    else
                        os.cp(path.join(scenario, "answers.md"), path.join(project, "answers.md"))
                        print("== %s: agent running (up to %d min)", id, limit // 60)
                        local transcript = io.open(path.join(evidence, "transcript.jsonl"), "w")
                        local stderr = io.open(path.join(evidence, "agent.stderr"), "w")
                        local exited = clean_env({"claude", "-p", "--permission-mode", "bypassPermissions", "--output-format", "stream-json",
                                                  "--verbose", io.readfile(path.join(scenario, "request.md"))},
                                                 {curdir = project, stdout = transcript, stderr = stderr, timeout = limit * 1000})
                        if exited ~= 0 then
                            stderr:write("agent exited " .. tostring(exited) .. "\n")
                        end
                        transcript:close()
                        stderr:close()
                        os.execv("rsync", {"-a", "--exclude", "build", "--exclude", ".xmake", project .. "/", path.join(evidence, "project") .. "/"})
                        for _, pattern in ipairs({"*.deb", "*/*.deb", "*/*/*.deb"}) do
                            for _, deb in ipairs(os.files(path.join(project, "build", pattern))) do
                                os.cp(deb, evidence)
                            end
                        end
                        local hits = credentials.leaked_paths(login, evidence)
                        if #hits > 0 then
                            for _, hit in ipairs(hits) do
                                os.rm(hit)
                            end
                            local line = "FAIL  the login token reached the evidence; removed: " .. table.concat(hits, " ")
                            print(line)
                            append(path.join(evidence, "check.txt"), line .. "\n")
                            status = 1
                        end
                        os.tryrm(home)
                        local verdict = path.join(scratch, "verdict-" .. id .. ".txt")
                        local output = io.open(verdict, "w")
                        local counted = os.execv(os.programfile(), {"l", path.join(tests, "check.lua"), project, scenario, plugin, evidence},
                                                 {stdout = output, stderr = output, try = true})
                        output:close()
                        local said = io.readfile(verdict)
                        io.write(said)
                        append(path.join(evidence, "check.txt"), said)
                        os.rm(verdict)
                        if counted ~= 0 then
                            status = 1
                        end
                    end
                end
            end
        end,
        catch {
            function (caught)
                errors = caught
            end
        },
        finally {
            function ()
                cleanup()
            end
        }
    }
    if errors then
        raise(errors)
    end
    print("evidence in %s; scratch kept at %s", evidence_root, scratch)
    os.exit(status)
end
