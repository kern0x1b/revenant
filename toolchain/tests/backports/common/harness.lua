local TOOLCHAIN = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
local workspace = import("workspace", {rootdir = path.join(TOOLCHAIN, "modules"), anonymous = true})
local byteorder = import("byteorder", {rootdir = path.join(TOOLCHAIN, "modules"), anonymous = true})
local json = import("core.base.json")

local GENERATED = path.join(TOOLCHAIN, "packages", "frameworks", "apple-backports", ".gen")
local TWOPROCESS_FRAMEWORKS = {"-framework", "UIKit", "-framework", "Foundation", "-framework", "CoreGraphics"}
local LOG_TAIL = 5

function toolchain()
    return TOOLCHAIN
end

function folder(name)
    return workspace.run(name)
end

function fresh(name)
    return workspace.fresh(name)
end

function sdk()
    return workspace.sdk()
end

function corpus(...)
    return workspace.corpus(...)
end

local function tail(file, count)
    local lines = {}
    for line in io.lines(file) do
        table.insert(lines, "    " .. line)
        if #lines > count then
            table.remove(lines, 1)
        end
    end
    return table.concat(lines, "\n")
end

function generated(frameworks)
    local missing = {}
    for _, framework in ipairs(frameworks) do
        if not os.isdir(path.join(GENERATED, framework)) then
            table.insert(missing, framework)
        end
    end
    if #missing == 0 then
        return
    end
    local wanted = table.concat(missing, " ")
    local gen_sdk = workspace.sdk()
    local log = path.join(workspace.run("generated"), "gen.log")
    local status = os.execv(os.programfile(), {"l", path.join(TOOLCHAIN, "tools", "gen.lua"), "gen", "--tree", TOOLCHAIN, "--all", "--sdk", gen_sdk},
                            {curdir = TOOLCHAIN, envs = {REVENANT_GEN_SDK = gen_sdk}, stdout = log, stderr = log, try = true})
    if status ~= 0 then
        raise("the generator exits %s writing .gen/ for %s (tail of %s):\n%s", tostring(status), wanted, log, tail(log, LOG_TAIL))
    end
    for _, framework in ipairs(missing) do
        if not os.isdir(path.join(GENERATED, framework)) then
            raise("the generator wrote no .gen/%s (its log is %s)", framework, log)
        end
    end
end

local function renames(files)
    local seen = {}
    for _, file in ipairs(files) do
        for line in io.lines(file) do
            local name = line:match("^@implementation%s+(%S+)")
            if name and not line:find("(", 1, true) then
                seen["-D" .. name .. "=RevenantPort" .. name] = true
            end
        end
    end
    return byteorder.keys(seen)
end

local function compile(common, extra, sources, frameworks, output)
    local argv = {"clang"}
    table.join2(argv, common, extra, sources, TWOPROCESS_FRAMEWORKS, frameworks, {"-o", output})
    local log = output .. ".log"
    local status = os.execv("xcrun", argv, {stdout = log, stderr = log, try = true})
    if status ~= 0 then
        raise("clang exits %s building %s (tail of %s):\n%s", tostring(status), path.filename(output), log, tail(log, LOG_TAIL))
    end
    os.execv("codesign", {"-s", "-", "--force", output}, {stdout = os.nuldev(), stderr = os.nuldev()})
end

local function answers(binary, out)
    local status = os.execv(binary, {}, {stdout = out, try = true})
    if status ~= 0 then
        raise("%s exits %s", path.filename(binary), tostring(status))
    end
    return io.readfile(out)
end

function twoprocess(opt)
    local build, test, files = opt.build, opt.test, opt.files
    os.mkdir(build)
    local macsdk = os.iorunv("xcrun", {"--show-sdk-path"}):trim()
    local common = {"-target", "arm64-apple-ios15.0-macabi", "-isysroot", macsdk, "-iframework",
                    path.join(macsdk, "System", "iOSSupport", "System", "Library", "Frameworks"), "-fobjc-arc", "-w", "-I", opt.uikit}
    local frameworks = opt.frameworks or {}
    local host_app, port_app = path.join(build, "host-app"), path.join(build, "port-app")
    compile(common, {}, {test}, frameworks, host_app)
    compile(common, renames(files), table.join(files, {test}), frameworks, port_app)
    local host = answers(host_app, path.join(build, "host.txt"))
    local checks = #host:split("\n")
    if checks == 0 then
        raise("no checks ran")
    end
    local port = answers(port_app, path.join(build, "port.txt"))
    if host ~= port then
        local difference = path.join(build, "diff.txt")
        os.execv("diff", {path.join(build, "host.txt"), path.join(build, "port.txt")}, {stdout = difference, try = true})
        raise("the port and the host differ\n%s", io.readfile(difference))
    end
    return string.format("%d checks, the port's classes answer as the host's do", checks)
end

function records(file)
    local count = 0
    for _ in pairs(json.loadfile(file)) do
        count = count + 1
    end
    return count
end

function plant(folder, needle)
    local hits = 0
    for _, file in ipairs(os.files(path.join(folder, "*.m"))) do
        local text = io.readfile(file)
        local found = 0
        local at = text:find(needle, 1, true)
        local pieces = {}
        local start = 1
        while at do
            table.insert(pieces, text:sub(start, at - 1))
            found = found + 1
            start = at + #needle
            at = text:find(needle, start, true)
        end
        if found > 0 then
            table.insert(pieces, text:sub(start))
            io.writefile(file, table.concat(pieces))
            hits = hits + found
        end
    end
    if hits == 0 then
        raise("the text to remove is in no .m file under %s, so nothing was planted", folder)
    end
    return hits
end

local function words(text)
    local out = {}
    for word in (text or ""):gmatch("%S+") do
        table.insert(out, word)
    end
    return out
end

local commands = {}
local VALUES = {folder = true, fresh = true, sdk = true, corpus = true, records = true, plant = true}

function commands.folder(name)
    print(folder(name))
end

function commands.fresh(name)
    print(fresh(name))
end

function commands.sdk()
    print(sdk())
end

function commands.corpus(...)
    print(corpus(...))
end

function commands.generated(...)
    generated({...})
end

function commands.twoprocess(build, uikit, frameworks, test, ...)
    print(twoprocess({build = build, uikit = uikit, frameworks = words(frameworks), test = test, files = {...}}))
end

function commands.records(file)
    print(records(file))
end

function commands.plant(folder, needle)
    print(string.format("planted: removed %d occurrence(s)", plant(folder, needle)))
end

local USAGE = "usage: xmake l tests/backports/common/harness.lua folder <name> | fresh <name> | sdk | corpus [path ...] | generated <framework>... | "
              .. "twoprocess <build> <uikit> <frameworks> <test.m> <port.m>... | records <json> | plant <folder> <text>"

function main(command, ...)
    local run = commands[command or ""]
    if not run then
        print("FAIL " .. USAGE)
        os.exit(1)
    end
    local arguments = table.pack(...)
    local failure
    try {
        function ()
            run(table.unpack(arguments, 1, arguments.n))
        end,
        catch {
            function (errors)
                failure = tostring(errors)
            end
        }
    }
    if failure then
        if VALUES[command] then
            io.stderr:write("FAIL " .. failure .. "\n")
        else
            print("FAIL " .. failure)
        end
        os.exit(1)
    end
end
