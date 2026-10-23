import("core.base.json")

local root = path.directory(os.scriptdir())
local home = os.getenv("HOME")
local defaults = {
    emulator = path.join(root, "build", "macosx", "arm64", "release", "emulator"),
    firmware = path.join(home, ".revenant", "firmware", "rootfs", "iPhone4,1", "6.1.3_10B329"),
    device = "iPhone4,1",
    cap = "2700",
    out = path.join(home, ".revenant", "cache", "emulator-gtest")
}

local function options(args)
    local given = {}
    local index = 1
    while index <= #args do
        local key = args[index]:match("^%-%-(%w+)$")
        if not key or args[index + 1] == nil then
            raise("emulator-gtest: expected --name VALUE pairs, got %s", args[index])
        end
        given[key] = args[index + 1]
        index = index + 2
    end
    return given
end

function main(...)
    local given = options({...})
    local binary = given.binary or raise("emulator-gtest: --binary PATH is required")
    if not os.isfile(binary) then
        raise("emulator-gtest: no binary at %s", binary)
    end
    local emulator = given.emulator or defaults.emulator
    if not os.isfile(emulator) then
        raise("emulator-gtest: no emulator at %s (build it with ./xmakew build emulator)", emulator)
    end
    local firmware = given.firmware or defaults.firmware
    local name = given.name or path.filename(binary)
    local run = given.out or path.join(defaults.out, name .. "-" .. os.date("%Y%m%d-%H%M%S"))
    os.mkdir(run)

    local rootfs = path.join(run, "rootfs")
    os.vrunv("cp", {"-c", "-R", firmware, rootfs})
    local vroot = path.join(rootfs, "var", "root")
    os.mkdir(vroot)
    os.cp(binary, path.join(vroot, name))
    if given.filter then
        io.writefile(path.join(vroot, "gtest_filter"), given.filter .. "\n")
    end

    local log = path.join(run, "boot.log")
    local guest = "/var/root/" .. name
    try {
        function ()
            os.execv("perl", {"-e", "alarm " .. (given.cap or defaults.cap) .. "; exec @ARGV", emulator, "boot",
                              "--rootfs", rootfs, "--device", given.device or defaults.device, "--binary", guest,
                              "--display", "headless", "--gles-backend", "software", "--time-scale", "10",
                              "--perf-summary"}, {stdout = log, stderr = log})
        end,
        catch { function () end }
    }

    local text = os.isfile(log) and io.readfile(log) or ""
    local finished = text:find("cpu%-ticks=%d+") ~= nil
    local completed = 0
    for _ in text:gmatch("%(%d+ ms%)") do
        completed = completed + 1
    end
    local tests, failures = 0, 0
    local results = path.join(vroot, "gtest.json")
    if os.isfile(results) then
        local data = json.decode(io.readfile(results))
        tests, failures = data.tests or 0, data.failures or 0
        os.cp(results, path.join(run, "gtest.json"))
    end
    print("%s: %s, %d tests, %d failures, %d completed (%s)", name,
          finished and "finished" or "did not finish", tests, failures, completed, run)
    if not finished or failures > 0 or tests == 0 then
        raise("emulator-gtest: %s did not pass; see %s", name, log)
    end
end
