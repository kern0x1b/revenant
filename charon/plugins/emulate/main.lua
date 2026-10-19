import("core.base.json")
import("core.base.option")
import("core.base.task")
import("core.project.config")
import("core.project.project")
import("@self.emulator")
import("@self.packaging")
import("@self.apple.firmware")

local function required(name)
    local package = project.required_package(name)
    if not package then
        raise("the project requires no %s; add includes(\"@addon/charon/emulate\") after includes(\"@addon/charon/apple-ios\")", name)
    end
    return package
end

-- A target says with emulate.timing = "strict" that it measures time itself.
local function timing()
    for _, target in pairs(project.targets()) do
        local value = target:values("emulate.timing")
        if value then
            return value
        end
    end
    return "scaled"
end

local function network()
    if option.get("network") then
        return option.get("network")
    end
    for _, target in pairs(project.targets()) do
        local value = target:values("emulate.network")
        if value then
            return value
        end
    end
    return "isolated"
end

local function context()
    if not is_host("macosx") or os.arch() ~= "arm64" then
        raise("xmake emulate runs on macOS arm64 hosts only, and this is %s %s", os.host(), os.arch())
    end
    task.run("config", {}, {disable_dump = true})
    local shade = required("shade")
    local guest = required("emulator-guest")
    local swiftshader = required("swiftshader")
    local tool = path.join(required("firmware-tools"):installdir(), "bin", "charon-firmware")
    local program = path.join(shade:installdir(), "bin", "shade")
    local release = option.get("release") or config.get("apple_minimum") or raise("xmake emulate needs -r RELEASE or set_config(\"apple_minimum\", ...)")
    local chosen = emulator.choose(firmware.catalog().devices, emulator.profiles(program),
                                   {device = option.get("device"), architecture = config.arch(), release = release})
    if not emulator.kernel(program, chosen.build) then
        raise("Shade emulates no Darwin kernel for %s iOS %s (%s); it has %s", chosen.identifier, chosen.version, chosen.build,
              table.concat(emulator.kernels(program), ", "))
    end
    local owner = (project.name() or path.filename(os.projectdir())) .. "-" .. hash.strhash32(os.projectdir())
    local image = path.join(emulator.root(), "images.noindex", owner, chosen.identifier .. "_" .. chosen.build)
    return {shade = program, shade_hash = path.filename(shade:installdir()), guest = guest:installdir(), tool = tool,
            icd = path.join(swiftshader:installdir(), "share", "vulkan", "icd.d", "vk_swiftshader_icd.json"),
            identifier = chosen.identifier, version = chosen.version, build = chosen.build, image = image,
            deadline = tonumber(option.get("timeout")), network = network()}
end

local function booter(ctx)
    return function (opt)
        local slot = emulator.acquire()
        local ok, result = try {
            function ()
                return true, emulator.boot(table.join(opt, {
                    scale = tonumber(option.get("scale")) or emulator.TIME_SCALE,
                    cache = path.join(emulator.root(), "cache.noindex", ctx.identifier .. "_" .. ctx.build, "slot-" .. slot.index),
                    tmpdir = path.join(emulator.root(), "tmp.noindex")}))
            end,
            catch {
                function (errors)
                    return false, errors
                end
            }
        }
        emulator.release(slot)
        if not ok then
            raise(result)
        end
        return result
    end
end

local function golden(ctx)
    local firmware_rootfs = firmware.rootfs(ctx.identifier, ctx.version, {tool = ctx.tool})
    return emulator.golden(table.join(ctx, {firmware = firmware_rootfs, boot = booter(ctx)}))
end

local function install(ctx)
    local written = packaging.write()
    local base = golden(ctx)
    local rootfs = path.join(ctx.image, "rootfs")
    emulator.clone_golden(base, rootfs)
    local applications = {}
    for _, package in ipairs(written) do
        local placed = emulator.install_deb(package.deb, rootfs)
        cprint("${bright green}installed${clear} %s into %s %s", path.filename(package.deb), ctx.identifier, ctx.version)
        -- What went in, so a caller can hold it against the build: a binary of this port is stripped and
        -- signed on its way into the image, and ldid's signature is not reproducible, so its hash is
        -- printed for the record and its size is what a comparison is made of.
        for _, file in ipairs(emulator.describe_files(package.stage)) do
            cprint("  %s %d B %s", file.path, file.size, file.hash:sub(1, 16))
        end
        for _, relative in ipairs(placed) do
            local identifier = emulator.register_application(rootfs, relative)
            applications[identifier] = "/" .. relative
            cprint("${bright green}registered${clear} %s (/%s) with SpringBoard", identifier, relative)
        end
    end
    json.savefile(path.join(ctx.image, "image.json"), {identifier = ctx.identifier, version = ctx.version, build = ctx.build,
                                                        packages = table.imap(written, function (_, item) return path.filename(item.deb) end),
                                                        applications = applications})
    return applications
end

local function run(ctx, argv)
    local refusal = emulator.timing_refusal(timing(), tonumber(option.get("scale")) or emulator.TIME_SCALE)
    if refusal then
        raise(refusal)
    end
    local image = path.join(ctx.image, "rootfs")
    if not os.isdir(image) then
        raise("%s %s has no image yet; run xmake emulate install first", ctx.identifier, ctx.version)
    end
    local folder = path.join(ctx.image, "run")
    emulator.remove(folder)
    local rootfs = path.join(folder, "rootfs")
    emulator.clone(image, rootfs)
    local seconds = tonumber(option.get("seconds"))
    emulator.install_runner(rootfs, ctx.guest, argv, seconds, ctx.version)
    local results = emulator.results(rootfs)
    -- The clone is a whole root filesystem, and it goes whatever the run did: a boot that times out, a
    -- command that raises, a harness that gives up - each of those left one behind, and 125 of them are
    -- what filled the cache. Only --keep holds it, and then beside the log the run leaves.
    local ok, result, booted, errors = try {
        function ()
            local boot = booter(ctx)(table.join(ctx, {rootfs = rootfs, run = folder, stop = function ()
                return os.isfile(path.join(results, "verdict.json"))
            end}))
            local reports = emulator.reports(rootfs)
            local verdict = emulator.verdict(boot.state, results, {frame = boot.frame, errors = boot.errors,
                                                                   scale = boot.scale, host_seconds = boot.seconds,
                                                                   reports = reports})
            os.cp(results, path.join(folder, "results"))
            for _, report in ipairs(reports) do
                os.cp(report.file, path.join(folder, "results", "reports", path.filename(report.file)))
                report.file = path.join(folder, "results", "reports", path.filename(report.file))
            end
            verdict.stdout = path.join(folder, "results", "test.stdout")
            verdict.stderr = path.join(folder, "results", "test.stderr")
            json.savefile(path.join(folder, "verdict.json"), table.join(verdict, {reason = boot.reason, seconds = boot.seconds}))
            return true, verdict, boot
        end,
        catch {
            function (caught)
                return false, nil, nil, caught
            end
        }
    }
    if not option.get("keep") then
        emulator.remove(rootfs)
        emulator.remove(path.join(folder, "runtime"))
        emulator.remove(path.join(folder, ".shade-device-state"))
    end
    if not ok then
        raise(errors)
    end
    emulator.report_output(folder, result.output)
    -- Where the run's own files are: a program writes what it has to say into /var/charon, and the
    -- image is under the emulator root, so the folder is named for whoever has to read them.
    print("run folder %s", folder)
    local described = emulator.describe(result)
    -- Both clocks are named whatever the outcome, so a run is never read as
    -- fast or slow without the scale that produced it.
    local timing = string.format("%.1f guest s / %.1f host s at time scale %s",
                                 result.guest_seconds or 0, result.host_seconds or 0, result.scale)
    if result.state == "pass" then
        cprint("${bright green}%s${clear} on %s %s (%s) in %s", described, ctx.identifier, ctx.version,
               ctx.build, timing)
    else
        raise("%s on %s %s (%s) in %s; the emulator log is %s", described, ctx.identifier, ctx.version,
              ctx.build, timing, booted.log)
    end
end

-- The port is installed, its application launched by SpringBoard the way a
-- tap on its icon launches it, and what the application writes and shows is
-- kept: its standard output and error, and a snapshot once its screen settles
-- and after each step.
local function launch(ctx, identifier, steps)
    local applications = install(ctx)
    local application = applications[identifier]
    if not application then
        raise("the port installs no application %s; it installs %s", identifier,
              #table.keys(applications) > 0 and table.concat(table.orderkeys(applications), ", ") or "none")
    end
    local folder = path.join(ctx.image, "run")
    emulator.remove(folder)
    local rootfs = path.join(folder, "rootfs")
    emulator.clone(path.join(ctx.image, "rootfs"), rootfs)
    local seconds = tonumber(option.get("seconds"))
    local results = emulator.results(rootfs)
    emulator.install_launcher(rootfs, ctx.guest)
    -- The runner outlasts charon-sblaunch's own wait by one of its half-second
    -- retries, so charon-sblaunch says why it gave up instead of being ended.
    emulator.install_runner(rootfs, ctx.guest, emulator.launch_command(identifier, seconds), seconds + 1, ctx.version)
    local scale = tonumber(option.get("scale")) or emulator.TIME_SCALE
    local driver = emulator.launch_driver({results = results, run = folder, application = application, steps = steps,
                                           seconds = seconds, scale = scale})
    local booted = booter(ctx)(table.join(ctx, {rootfs = rootfs, run = folder, stop = driver.stop}))
    os.cp(results, path.join(folder, "results"))
    local reports = emulator.reports(rootfs)
    for _, report in ipairs(reports) do
        os.cp(report.file, path.join(folder, "results", "reports", path.filename(report.file)))
    end
    local result = {identifier = identifier, application = application, shots = driver.shots, failure = driver.failure,
                    exit = driver.exit, pid = driver.application and driver.application.pid, unlocks = driver.unlocks,
                    held = driver.held, held_seconds = driver.held_seconds,
                    reason = booted.reason, seconds = booted.seconds, scale = booted.scale,
                    stdout = path.join(folder, "results", "app.stdout"), stderr = path.join(folder, "results", "app.stderr")}
    json.savefile(path.join(folder, "verdict.json"), result)
    if not option.get("keep") then
        emulator.remove(rootfs)
        emulator.remove(path.join(folder, "runtime"))
        emulator.remove(path.join(folder, ".shade-device-state"))
    end
    for _, name in ipairs({"app.stdout", "app.stderr"}) do
        local file = path.join(folder, "results", name)
        if os.isfile(file) and os.filesize(file) > 0 then
            io.write(io.readfile(file))
        end
    end
    for _, shot in ipairs(driver.shots) do
        print(shot)
    end
    -- Where the run's own files are: the application writes what it has to say into /var/charon, and
    -- the image is under the emulator root, so the folder is named for whoever has to read them.
    print("run folder %s", folder)
    local where = string.format("on %s %s (%s) in %.1f host s at time scale %s", ctx.identifier, ctx.version, ctx.build,
                                booted.seconds, booted.scale)
    if driver.failure == "refused" then
        local said = path.join(folder, "results", "test.stderr")
        local reason = os.isfile(said) and io.readfile(said):trim() or ""
        if reason == "" then
            local states = path.join(folder, "results", "test.stdout")
            local last = os.isfile(states) and io.readfile(states):match("([^\n]*)\n?$") or ""
            reason = string.format("charon-sblaunch was ended at the -s deadline of %d guest seconds; its last state: %s",
                                   seconds, last ~= "" and last or "none")
        end
        raise("SpringBoard did not launch %s %s: %s; the emulator log is %s", identifier, where, reason, booted.log)
    elseif driver.failure == "exited" then
        raise("%s ended %s %s; the emulator log is %s", identifier,
              driver.exit.signal ~= 0 and string.format("on signal %d", driver.exit.signal) or string.format("with status %d", driver.exit.status),
              where, booted.log)
    elseif not driver.application then
        raise("%s was %s, and no process of %s ever started %s; the emulator log is %s", identifier,
              driver.phase == "launching" and "never launched" or "launched", application, where, booted.log)
    elseif booted.reason ~= "reached" then
        raise("%s ran, and the run ended (%s) %s before its %d steps were taken; the emulator log is %s", identifier,
              booted.reason, where, #steps, booted.log)
    end
    cprint("${bright green}launched${clear} %s as pid %s %s, %d snapshot(s)", identifier, driver.application.pid, where, #driver.shots)
    if driver.held == "exited" then
        cprint("${bright green}held${clear} until %s ended, %.0f guest seconds after it was frontmost", identifier, driver.held_seconds)
    elseif driver.held == "deadline" then
        cprint("${bright yellow}held${clear} until the run's own budget (-s %g guest seconds from the application being frontmost) was spent, not until %s ended: it was still running, and the last frame is the one it was on; raise -s (and -t) for a run that needs longer",
               seconds, identifier)
    end
end

local function log(ctx, text)
    local results = path.join(ctx.image, "run", "results")
    for _, name in ipairs({"test.stdout", "test.stderr", "runner.stdout", "runner.stderr", "app.stdout", "app.stderr"}) do
        local file = path.join(results, name)
        if os.isfile(file) then
            for line in io.readfile(file):gmatch("[^\n]+") do
                if text == "" or line:find(text, 1, true) then
                    print("%s: %s", name, line)
                end
            end
        end
    end
    local emulated = path.join(ctx.image, "run", "emulator.log")
    if os.isfile(emulated) then
        for line in io.readfile(emulated, {encoding = "binary"}):gmatch("[^\n]+") do
            local wanted = text ~= "" and line:find(text, 1, true)
            wanted = wanted or (text == "" and (line:startswith("[cpu] fatal") or line:match("^%[process%] exit .*signal=[1-9]")))
            if wanted then
                print("emulator: %s", line)
            end
        end
    end
end

-- The program is started as the guest's first process and stopped where it
-- crashes, and what the debugger reads is printed as it is read: the signal,
-- the frames named by the images the guest says it loaded, and the registers.
local function debug_command(ctx, command)
    local image = path.join(ctx.image, "rootfs")
    if not os.isdir(image) then
        raise("%s %s has no image yet; run xmake emulate install first", ctx.identifier, ctx.version)
    end
    local folder = path.join(ctx.image, "debug")
    emulator.remove(folder)
    local rootfs = path.join(folder, "rootfs")
    emulator.clone(image, rootfs)
    local slot = emulator.acquire()
    local report = try {
        function ()
            return emulator.debugged(table.join(ctx, {rootfs = rootfs, run = folder, guest = command,
                                                      architecture = config.arch(), network = network(),
                                                      cache = path.join(emulator.root(), "cache.noindex", ctx.identifier .. "_" .. ctx.build, "slot-" .. slot.index),
                                                      tmpdir = path.join(emulator.root(), "tmp.noindex")}))
        end,
        catch {
            function (errors)
                emulator.release(slot)
                raise(errors)
            end
        }
    }
    emulator.release(slot)
    json.savefile(path.join(folder, "debug.json"), report)
    if report.exited then
        cprint("${bright}%s${clear} ran to its own exit %d on %s %s (%s), with nothing to debug", command, report.exited,
               ctx.identifier, ctx.version, ctx.build)
        return
    end
    cprint("${bright}%s${clear} stopped with signal %d on %s %s (%s)", command, report.signal, ctx.identifier, ctx.version, ctx.build)
    for index, frame in ipairs(report.frames) do
        cprint("  #%-2d %-6s 0x%08x  %s", index - 1, frame.kind, frame.address, frame.name)
    end
    local told = {}
    for _, name in ipairs(emulator.REGISTERS or {}) do
        table.insert(told, string.format("%s=0x%08x", name, report.registers[name] or 0))
    end
    if #told > 0 then
        print(table.concat(told, " "))
    end
    cprint("${dim}%d images loaded; the report is %s and the emulator log is %s", #report.images,
           path.join(folder, "debug.json"), report.log)
    -- the clone is a whole root filesystem here too, and it is not the report that keeps it alive
    if not option.get("keep") then
        emulator.remove(rootfs)
        emulator.remove(path.join(folder, "runtime"))
        emulator.remove(path.join(folder, ".shade-device-state"))
    end
end

function main()
    local action = option.get("action")
    local arguments = option.get("arguments") or {}
    if action ~= "install" and action ~= "run" and action ~= "launch" and action ~= "debug" and action ~= "log" and action ~= "shot" and action ~= "clean" then
        raise("xmake emulate takes install, run, launch, debug, log, shot or clean")
    end
    if action == "clean" then
        local owner = (project.name() or path.filename(os.projectdir())) .. "-" .. hash.strhash32(os.projectdir())
        local removed = emulator.clean({images = option.get("all") and os.dirs(path.join(emulator.root(), "images.noindex", "*")) or {path.join(emulator.root(), "images.noindex", owner)},
                                        goldens = option.get("all")})
        for _, folder in ipairs(removed) do
            cprint("${bright}removed${clear} %s", folder)
        end
        return
    end
    -- Before anything else an emulate does: what earlier runs left behind. A run that was killed cannot
    -- clean up after itself, so the next one is what bounds the cache.
    local hours = tonumber(option.get("prune-hours"))
    for _, folder in ipairs(emulator.prune({hours = hours})) do
        cprint("${bright}pruned${clear} %s, unused for more than %d hours", folder, hours or emulator.PRUNE_HOURS)
    end
    local ctx = context()
    emulator.directory(path.directory(ctx.image))
    local lock = io.openlock(ctx.image .. ".lock")
    if not lock:trylock() then
        cprint("another xmake emulate is using %s %s of this port; waiting for it", ctx.identifier, ctx.version)
        lock:lock()
    end
    if action == "install" then
        install(ctx)
    elseif action == "run" then
        if #arguments == 0 then
            raise("xmake emulate run needs a command")
        end
        run(ctx, arguments)
    elseif action == "launch" then
        if #arguments == 0 then
            raise("xmake emulate launch needs the bundle identifier of the application")
        end
        launch(ctx, arguments[1], emulator.parse_steps(table.slice(arguments, 2)))
    elseif action == "debug" then
        if #arguments == 0 then
            raise("xmake emulate debug needs the command to start under the debugger")
        end
        debug_command(ctx, arguments[1])
    elseif action == "log" then
        log(ctx, table.concat(arguments, " "))
    else
        local frame = path.join(ctx.image, "run", "frame.png")
        if not os.isfile(frame) then
            raise("%s %s has no frame yet; xmake emulate run and launch leave one", ctx.identifier, ctx.version)
        end
        local output = arguments[1] or path.join(config.builddir(), ctx.identifier .. "_" .. ctx.build .. ".png")
        os.cp(frame, output)
        print(output)
    end
end
