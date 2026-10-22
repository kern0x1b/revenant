import("core.base.json")
import("core.project.config")

local ROOT = path.absolute(path.join(os.scriptdir(), "..", "..", "..", ".."))
local emulator = import("emulator", {rootdir = path.join(ROOT, "toolchain", "modules"), anonymous = true})

local DEVICE = "iPhone4,1"
local RELEASE = "6.1.3"
local BUILD = "10B329"
local BINARY = "usr/libexec/revenant-backports-runtime"
local INSTALL = "usr/lib/revenant/org.revenant.backports"

local function home_cache()
    return path.join(os.getenv("HOME"), ".revenant", "cache", "runtime-tests")
end

local function firmware_root()
    return path.join(os.getenv("HOME"), ".revenant", "firmware", "rootfs", DEVICE, RELEASE .. "_" .. BUILD)
end

local function emulator_program()
    return path.join(ROOT, "build", "macosx", "arm64", "release", "emulator")
end

local function require_present(file, message)
    if not os.isfile(file) and not os.isdir(file) then
        raise("%s", message)
    end
end

local function parse(text)
    local cases = {}
    local finished = false
    for line in text:gmatch("[^\n]+") do
        local name, mode, outcome, detail = line:match("^REVENANT%-CASE (%S+) (%S+) (%S+) ?(.*)$")
        if name then
            cases[name] = cases[name] or {}
            cases[name][mode] = {outcome = outcome, detail = detail}
        elseif line:match("^REVENANT%-DONE") then
            finished = true
        end
    end
    return cases, finished
end

local function libraries_folder(app)
    local folder = config.get("backports_libs")
    if not folder or folder == "" then
        folder = path.directory(app)
    end
    return folder
end

local function run(app, guest)
    local program = emulator_program()
    local firmware = firmware_root()
    local libraries = os.files(path.join(libraries_folder(app), "lib*Backports.dylib"))
    if #libraries == 0 then
        raise("no lib*Backports.dylib in %s: build them with ./xmakew build -P . FoundationBackports UIKitBackports, or set --backports_libs to a folder of them", libraries_folder(app))
    end
    local identity = {hash.sha256(program), hash.sha256(app), hash.sha256(guest)}
    for _, library in ipairs(libraries) do
        table.insert(identity, hash.sha256(library))
    end
    local key = hash.strhash128(table.concat(identity, ";"))
    local folder = path.join(home_cache(), key)
    local saved = path.join(folder, "cases.json")
    if os.isfile(saved) then
        return json.loadfile(saved)
    end
    os.mkdir(folder)
    local lock = io.openlock(path.join(home_cache(), key .. ".lock"))
    lock:lock()
    local ok, cases = try {
        function ()
            if os.isfile(saved) then
                return true, json.loadfile(saved)
            end
            local started = os.mclock()
            local rootfs = path.join(folder, "rootfs")
            emulator.clone(firmware, rootfs)
            local destination = emulator.guest_path(rootfs, INSTALL)
            os.mkdir(destination)
            for _, library in ipairs(libraries) do
                os.cp(library, path.join(destination, path.filename(library)))
            end
            local binary = emulator.guest_path(rootfs, BINARY)
            os.mkdir(path.directory(binary))
            os.cp(app, binary)
            os.vrunv("chmod", {"0755", binary})
            emulator.install_runner(rootfs, guest, {"/" .. BINARY}, 60, RELEASE)
            local results = emulator.results(rootfs)
            local verdict_file = path.join(results, "verdict.json")
            local booted = emulator.boot({emulator = program, rootfs = rootfs, identifier = DEVICE, run = folder,
                                          cache = path.join(home_cache(), "host-cache"),
                                          tmpdir = path.join(home_cache(), "tmp"), network = "isolated",
                                          scale = emulator.TIME_SCALE, deadline = 900,
                                          stop = function () return os.isfile(verdict_file) end})
            local verdict = emulator.verdict(booted.state, results, {frame = booted.frame, errors = booted.errors,
                                                                     scale = booted.scale, host_seconds = booted.seconds,
                                                                     reports = emulator.reports(rootfs)})
            local stdout = path.join(results, "test.stdout")
            local text = os.isfile(stdout) and io.readfile(stdout) or ""
            os.cp(results, path.join(folder, "results"))
            io.writefile(path.join(folder, "app.stdout"), text)
            emulator.remove(rootfs)
            local parsed, finished = parse(text)
            if not finished then
                raise("the runtime app did not finish on %s %s (%s): %s; the emulator log is %s", DEVICE, RELEASE, BUILD,
                      emulator.describe(verdict), booted.log)
            end
            json.savefile(saved, parsed)
            cprint("${dim}runtime run on %s %s in %.1f host s at time scale %s, %s", DEVICE, RELEASE,
                   (os.mclock() - started) / 1000, booted.scale, emulator.describe(verdict))
            return true, parsed
        end,
        catch {
            function (raised)
                return false, raised
            end
        }
    }
    lock:unlock()
    lock:close()
    if not ok then
        raise(cases)
    end
    return cases
end

function failures(case, target)
    local found = {}
    local ok, result = try {
        function ()
            local app = target:dep("backports_runtime_app"):targetfile()
            require_present(emulator_program(), "the emulator is not built: ./xmakew f -P . -p macosx -a arm64 -y, then ./xmakew build -P . emulator")
            require_present(firmware_root(), string.format("the %s iOS %s root filesystem is not under ~/.revenant/firmware: ./xmakew firmware --device=%s rootfs %s",
                                                          DEVICE, RELEASE, DEVICE, RELEASE))
            require_present(app, "the runtime app is not built: ./xmakew build -P . backports_runtime_app")
            local guest = target:pkg("emulator-guest")
            if not guest then
                raise("emulator-guest is not installed for this configuration")
            end
            return true, run(app, guest:installdir())
        end,
        catch {
            function (raised)
                return false, tostring(raised)
            end
        }
    }
    if not ok then
        table.insert(found, result)
        return found
    end
    local outcome = result[case]
    if not outcome then
        table.insert(found, "the runtime app printed no result for " .. case)
        return found
    end
    if not outcome.positive or outcome.positive.outcome ~= "pass" then
        table.insert(found, "the check must pass on iOS " .. RELEASE .. ": " .. (outcome.positive and (outcome.positive.outcome .. ": " .. outcome.positive.detail) or "no result"))
    end
    if not outcome.negative or outcome.negative.outcome ~= "fail" then
        table.insert(found, "the negative control must fail: " .. (outcome.negative and (outcome.negative.outcome .. ": " .. outcome.negative.detail) or "no result"))
    end
    return found
end
