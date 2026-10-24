import("core.base.json")
import("core.project.config")

local ROOT = path.absolute(path.join(os.scriptdir(), "..", "..", "..", ".."))
local DRIVER = path.join(os.scriptdir(), "driver.lua")
local emulator = import("@addon.revenant.emulator", {anonymous = true})

local DEVICE = "iPhone4,1"
local RELEASE = "6.1.3"
local BUILD = "10B329"
local APP_ID = "org.revenant.backports.runtime"
local APP = "var/mobile/Applications/7E6B3B4A-6A5C-4A8E-9C35-0B1F2E7D9A11/RevenantBackportsRuntime.app"
local BINARY = APP .. "/RevenantBackportsRuntime"
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

local TCC_SCHEMA = [[
CREATE TABLE IF NOT EXISTS admin (key TEXT PRIMARY KEY NOT NULL, value INTEGER NOT NULL);
INSERT OR IGNORE INTO admin VALUES ('version', 4);
CREATE TABLE IF NOT EXISTS access (service TEXT NOT NULL, client TEXT NOT NULL, client_type INTEGER NOT NULL, allowed INTEGER NOT NULL, prompt_count INTEGER NOT NULL, CONSTRAINT key PRIMARY KEY (service, client, client_type));
CREATE TABLE IF NOT EXISTS access_times (service TEXT NOT NULL, client TEXT NOT NULL, client_type INTEGER NOT NULL, last_used_time INTEGER NOT NULL, CONSTRAINT key PRIMARY KEY (service, client, client_type));
CREATE TABLE IF NOT EXISTS access_overrides (service TEXT PRIMARY KEY NOT NULL);
INSERT OR REPLACE INTO access VALUES ('kTCCServicePhotos', '%s', 0, 1, 1);
INSERT OR REPLACE INTO access VALUES ('kTCCServicePhotos', '%s', 1, 1, 1);
INSERT OR REPLACE INTO access VALUES ('kTCCServicePhotos', '%s', 0, 1, 1);
INSERT OR REPLACE INTO access_times VALUES ('kTCCServicePhotos', '%s', 0, 0);
INSERT OR REPLACE INTO access_times VALUES ('kTCCServicePhotos', '%s', 1, 0);
INSERT OR REPLACE INTO access_times VALUES ('kTCCServicePhotos', '%s', 0, 0);
]]

local function owned_by_mobile(file)
    os.vrunv("xattr", {"-w", "hfsfuse.record.owner_id", "501", file})
    os.vrunv("xattr", {"-w", "hfsfuse.record.group_id", "501", file})
end

local function install_bundle(rootfs, binary)
    local bundle = emulator.guest_path(rootfs, APP)
    os.mkdir(bundle)
    local info = path.join(bundle, "Info.plist")
    os.vrunv("plutil", {"-create", "xml1", info})
    for _, key in ipairs({{"CFBundleIdentifier", APP_ID}, {"CFBundleExecutable", "RevenantBackportsRuntime"},
                          {"CFBundleName", "RevenantBackportsRuntime"}, {"CFBundlePackageType", "APPL"}}) do
        os.vrunv("plutil", {"-replace", key[1], "-string", key[2], info})
    end
    for _, file in ipairs({bundle, info, binary}) do
        owned_by_mobile(file)
    end
end

local function grant_photos_access(rootfs)
    local directory = emulator.guest_path(rootfs, "/var/root/Library/TCC")
    os.mkdir(directory)
    local database = path.join(directory, "TCC.db")
    local clients = {APP_ID, "/" .. BINARY, "RevenantBackportsRuntime"}
    local values = table.join(clients, clients)
    os.vrunv("sqlite3", {database, string.format(TCC_SCHEMA, table.unpack(values))})
    owned_by_mobile(directory)
    owned_by_mobile(database)
end

local function require_present(file, message)
    if not os.isfile(file) and not os.isdir(file) then
        raise("%s", message)
    end
end

function parse(text)
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

function guarded(body)
    local failure
    local values = try {
        function ()
            return {body()}
        end,
        catch {
            function (raised)
                failure = tostring(raised or "the body raised nothing")
            end
        }
    }
    if failure or not values then
        return nil, failure or "the body returned nothing"
    end
    return values
end

function judge(case, cases, finished, description)
    local found = {}
    if not finished then
        table.insert(found, string.format("the runtime app did not finish on %s %s (%s): %s", DEVICE, RELEASE, BUILD, description))
        return found
    end
    local outcome = cases[case]
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

local function libraries_folder(app)
    local folder = config.get("backports_libs")
    if not folder or folder == "" then
        folder = path.directory(app)
    end
    return folder
end

local function run(app, guest, ldid)
    local program = emulator_program()
    local firmware = firmware_root()
    local libraries = os.files(path.join(libraries_folder(app), "lib*Backports.dylib"))
    table.join2(libraries, os.files(path.join(libraries_folder(app), "lib*Probe.dylib")))
    if #libraries == 0 then
        raise("no lib*Backports.dylib in %s: build them with ./xmakew build -P . FoundationBackports UIKitBackports, or set --backports_libs to a folder of them", libraries_folder(app))
    end
    local identity = {hash.sha256(program), hash.sha256(app), hash.sha256(guest), hash.sha256(DRIVER)}
    for _, library in ipairs(libraries) do
        table.insert(identity, hash.sha256(library))
    end
    local key = hash.strhash128(table.concat(identity, ";"))
    local folder = path.join(home_cache(), key)
    local saved = path.join(folder, "cases.json")
    if os.isfile(saved) then
        return json.loadfile(saved), true, ""
    end
    os.mkdir(folder)
    local lock = io.openlock(path.join(home_cache(), key .. ".lock"))
    lock:lock()
    local values, failure = guarded(function ()
        if os.isfile(saved) then
            return json.loadfile(saved), true, ""
        end
        local started = os.mclock()
        local rootfs = path.join(folder, "rootfs")
        emulator.clone(firmware, rootfs)
        grant_photos_access(rootfs)
        local destination = emulator.guest_path(rootfs, INSTALL)
        os.mkdir(destination)
        for _, library in ipairs(libraries) do
            os.cp(library, path.join(destination, path.filename(library)))
        end
        local binary = emulator.guest_path(rootfs, BINARY)
        os.mkdir(path.directory(binary))
        os.cp(app, binary)
        os.vrunv(ldid, {"-S", binary})
        os.vrunv("chmod", {"0755", binary})
        install_bundle(rootfs, binary)
        emulator.register_application(rootfs, APP)
        emulator.install_runner(rootfs, guest, {"/" .. BINARY}, 60, RELEASE)
        local results = emulator.results(rootfs)
        local verdict_file = path.join(results, "verdict.json")
        local perf_ready = emulator.guest_path(rootfs, "/var/mobile/Library/Caches/revenant-photos-perf-ready")
        local perf_done = emulator.guest_path(rootfs, "/var/mobile/Library/Caches/revenant-photos-perf-done")
        local booted = emulator.boot({emulator = program, rootfs = rootfs, identifier = DEVICE, run = folder,
                                      cache = path.join(home_cache(), "host-cache"),
                                      tmpdir = path.join(home_cache(), "tmp"), network = "isolated",
                                      scale = emulator.TIME_SCALE, deadline = 900, perf = true,
                                      stop = function (state, control)
                                          if state.perf_begin and not state.perf_begin_sent then
                                              control("perf-begin " .. state.perf_begin)
                                              state.perf_begin_sent = true
                                          end
                                          if state.perf_started and not state.perf_ready then
                                              io.writefile(perf_ready, "ready\n")
                                              state.perf_ready = true
                                          end
                                          if state.perf_end and not state.perf_end_sent then
                                              control("perf-end")
                                              state.perf_end_sent = true
                                          end
                                          if state.perf_finished and not state.perf_done then
                                              io.writefile(perf_done, "done\n")
                                              state.perf_done = true
                                          end
                                          return os.isfile(verdict_file)
                                      end})
        local verdict = emulator.verdict(booted.state, results, {frame = booted.frame, errors = booted.errors,
                                                                 scale = booted.scale, host_seconds = booted.seconds,
                                                                 reports = emulator.reports(rootfs)})
        local stdout = path.join(results, "test.stdout")
        local text = os.isfile(stdout) and io.readfile(stdout) or ""
        os.cp(results, path.join(folder, "results"))
        io.writefile(path.join(folder, "app.stdout"), text)
        emulator.remove(rootfs)
        local cases, finished = parse(text)
        local description = emulator.describe(verdict) .. "; the emulator log is " .. tostring(booted.log)
        if finished then
            json.savefile(saved, cases)
            cprint("${dim}runtime run on %s %s in %.1f host s at time scale %s, %s", DEVICE, RELEASE,
                   (os.mclock() - started) / 1000, booted.scale, emulator.describe(verdict))
        end
        return cases, finished, description
    end)
    lock:unlock()
    lock:close()
    if not values then
        raise(failure)
    end
    return values[1], values[2], values[3]
end

function failures(case, target)
    local found = {}
    local values, failure = guarded(function ()
        local app = target:dep("backports_runtime_app"):targetfile()
        require_present(emulator_program(), "the emulator is not built: ./xmakew f -P . -p macosx -a arm64 -y, then ./xmakew build -P . emulator")
        require_present(firmware_root(), string.format("the %s iOS %s root filesystem is not under ~/.revenant/firmware: ./xmakew firmware --device=%s rootfs %s",
                                                      DEVICE, RELEASE, DEVICE, RELEASE))
        require_present(app, "the runtime app is not built: ./xmakew build -P . backports_runtime_app")
        local guest = target:pkg("emulator-guest")
        if not guest then
            raise("emulator-guest is not installed for this configuration")
        end
        local ldid = path.join(target:dep("backports_runtime_app"):pkg("ldid"):installdir(), "bin", "ldid")
        return run(app, guest:installdir(), ldid)
    end)
    if not values or values[1] == nil then
        table.insert(found, failure or "the runtime run returned no results")
        return found
    end
    return judge(case, values[1], values[2], values[3])
end
