import("core.base.json")

local here = os.scriptdir()
local repository = os.projectdir()
local workloads = path.join(here, "workloads")
local helper = path.join(repository, "toolchain", "src", "guest-memory")
local baselines_file = path.join(here, "..", "data", "bench", "baselines.json")
local device = "iPhone4,1"
local release = "6.1.3_10B329"
local triple = "armv7-apple-ios6.0"
local tolerance = {ticks = 0.02, calls = 0.02, resident = 0.05}

local WORKLOADS = {
    msgsend = {sources = {"msgsend.m"}, gated = {"Counter.bump"}},
    alloc = {sources = {"alloc.m"}, gated = {"Node.initWithValue", "Node.value"}},
    collections = {sources = {"collections.m"}, gated = {}},
    strings = {sources = {"strings.m"}, gated = {}},
    compute = {sources = {"compute.c"}, gated = {}}
}

local function scratch(name)
    return path.join(import("@addon.revenant.workspace", {anonymous = true}).scratch(), path.filename(repository), "bench", name)
end

local function discard(folder)
    if os.isdir(folder) then
        os.execv("chmod", {"-R", "u+w", folder}, {try = true})
        os.tryrm(folder)
    end
end

local function variant_flags()
    local given = os.getenv("REVENANT_BENCH_FLAGS") or "-Os"
    return given:split("%s+")
end

local function compile(opt, name, folder)
    local common = {"-target", triple, "-miphoneos-version-min=6.0", "-isysroot", opt.sdk,
                    "-Wno-incompatible-sysroot", "-I", path.join(helper, "include")}
    local units = {}
    for _, source in ipairs(WORKLOADS[name].sources) do
        table.insert(units, path.join(workloads, source))
    end
    table.insert(units, path.join(helper, "src", "guest_memory.c"))
    local objects = {}
    for _, source in ipairs(units) do
        local object = path.join(folder, path.basename(source) .. ".o")
        os.vrunv(opt.clang, table.join(common, variant_flags(), {"-c", source, "-o", object}))
        table.insert(objects, object)
    end
    local binary = path.join(folder, name)
    os.vrunv(opt.clang, table.join(common, {"-mlinker-version=" .. opt.ld64_version, "-fuse-ld=" .. opt.ld64, "-framework", "Foundation"},
                                   objects, {"-o", binary}))
    os.vrunv(opt.ldid, {"-S", binary})
    return binary
end

local function boot(name, binary, folder)
    local emulator = path.join(repository, "build", "macosx", "arm64", "release", "emulator")
    if not os.isexec(emulator) then
        raise("the emulator is not built: ./xmakew build -P . emulator")
    end
    local firmware = path.join(import("@addon.revenant.workspace", {anonymous = true}).home(), "firmware", "rootfs", device, release)
    if not os.isdir(firmware) then
        raise("the %s %s root filesystem is not held: ./xmakew firmware -P . --device=%s rootfs 6.1.3", device, release, device)
    end
    local rootfs = path.join(folder, "rootfs")
    discard(rootfs)
    os.mkdir(rootfs)
    os.execv("cp", {"-c", "-R", path.join(firmware, "."), rootfs})
    if not os.isfile(path.join(rootfs, "System", "Library", "CoreServices", "SystemVersion.plist")) then
        raise("the copy of %s is incomplete: %s has no SystemVersion.plist", firmware, rootfs)
    end
    os.mkdir(path.join(rootfs, "usr", "local", "bin"))
    os.cp(binary, path.join(rootfs, "usr", "local", "bin", name))
    local cache = path.join(scratch(""), "host-cache")
    os.mkdir(cache)
    local log = path.join(folder, "boot.log")
    os.execv(emulator, {"boot", "--rootfs", rootfs, "--device", device, "--binary", "/usr/local/bin/" .. name,
                        "--host-cache", cache, "--display", "headless", "--gles-backend", "software", "--time-scale", "10",
                        "--ticks", "4000000000", "--perf-summary", "--perf-block-profile"},
             {stdout = log, stderr = log, try = true, timeout = 900000})
    discard(rootfs)
    return io.readfile(log) or ""
end

local function normal(address)
    return address - address % 2
end

local function measure(name, text, gated, failures)
    local measured = {ticks = tonumber(text:match("cpu%-ticks=(%d+)")), status = tonumber(text:match("%[process%] exit pid=1 status=(%-?%d+)")),
                      fields = {}, calls = {}}
    local line = text:match("bench " .. name .. " ([^\n]+)")
    if line then
        for key, value in line:gmatch("(%w+)=(%S+)") do
            measured.fields[key] = value
        end
    end
    if measured.status ~= 0 then
        table.insert(failures, string.format("%s did not exit with status 0 (status %s): %s", name, tostring(measured.status), (text:match("[^\n]*fatal[^\n]*") or "no fatal fault in the log")))
        return measured
    end
    if not line or not measured.ticks then
        table.insert(failures, name .. " printed no result line or no cpu-ticks")
        return measured
    end
    local rows = {}
    for entry, runs in text:gmatch("%[perf%-block%-top%] rank=%d+ pid=1 entry=0x(%x+) .-exact%-runs=(%d+)") do
        table.insert(rows, {entry = tonumber(entry, 16), runs = tonumber(runs)})
    end
    local published = {}
    for symbol, address in text:gmatch("bench%-entry symbol=(%S+) address=0x(%x+)") do
        published[symbol] = tonumber(address, 16)
    end
    for _, symbol in ipairs(gated) do
        local address = published[symbol]
        if not address then
            table.insert(failures, string.format("%s published no address for %s", name, symbol))
        else
            local found
            for _, row in ipairs(rows) do
                if normal(row.entry) == normal(address) then
                    found = row.runs
                end
            end
            if found then
                measured.calls[symbol] = found
            else
                table.insert(failures, string.format("%s: the entry of %s is not among the profile's top rows, so its calls are not counted", name, symbol))
            end
        end
    end
    return measured
end

local function baselines()
    if os.isfile(baselines_file) then
        return json.loadfile(baselines_file)
    end
    return {}
end

local function compare(name, measured, recorded, failures)
    if not recorded then
        table.insert(failures, string.format("%s has no baseline: record one with REVENANT_BENCH_RECORD=1 ./xmakew test -P . bench/%s", name, name))
        return
    end
    if measured.fields.checksum ~= recorded.checksum then
        table.insert(failures, string.format("%s computes checksum %s, the baseline says %s", name, tostring(measured.fields.checksum), tostring(recorded.checksum)))
    end
    local function regressed(label, value, base, limit)
        if value and base and value > base * (1 + limit) then
            table.insert(failures, string.format("%s %s regressed: %d against the baseline %d, beyond %d%%", name, label, value, base, limit * 100))
        end
    end
    regressed("guest instructions", measured.ticks, recorded.ticks, tolerance.ticks)
    regressed("resident bytes", tonumber(measured.fields.resident), recorded.resident, tolerance.resident)
    for symbol, runs in pairs(recorded.calls or {}) do
        regressed("calls to " .. symbol, measured.calls[symbol], runs, tolerance.calls)
    end
end

function check(name, opt)
    local failures = {}
    local workload = WORKLOADS[name]
    if not workload then
        return {"no bench workload " .. name}
    end
    local folder = scratch(name)
    discard(folder)
    os.mkdir(folder)
    local binary = compile(opt, name, folder)
    local text = boot(name, binary, folder)
    local measured = measure(name, text, workload.gated, failures)
    if #failures == 0 then
        local recorded = {checksum = measured.fields.checksum, ticks = measured.ticks, resident = tonumber(measured.fields.resident), calls = measured.calls}
        local size = os.filesize(binary)
        if os.getenv("REVENANT_BENCH_RECORD") then
            local all = baselines()
            all[name] = recorded
            os.mkdir(path.directory(baselines_file))
            json.savefile(baselines_file, all)
            print("recorded %s: ticks=%d resident=%d calls=%s", name, recorded.ticks, recorded.resident, json.encode(recorded.calls))
        elseif os.getenv("REVENANT_BENCH_REPORT") then
            print("report %s: ticks=%d resident=%s calls=%s size=%d flags=%s", name, measured.ticks, measured.fields.resident,
                  json.encode(measured.calls), size, table.concat(variant_flags(), " "))
        else
            compare(name, measured, baselines()[name], failures)
            print("bench %s: ticks=%d resident=%s calls=%s size=%d", name, measured.ticks, measured.fields.resident,
                  json.encode(measured.calls), size)
        end
    end
    discard(path.join(folder, "rootfs"))
    return failures
end
