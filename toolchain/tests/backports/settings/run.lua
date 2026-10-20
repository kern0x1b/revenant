local revenant = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
local workspace = import("workspace", {rootdir = path.join(revenant, "modules"), anonymous = true})
local byteorder = import("byteorder", {rootdir = path.join(revenant, "modules"), anonymous = true})

local HEARING = {"_AXMFiHearingDevicePairedUUIDs", "_AXMFiHearingDeviceStreamingEar", "_AXSupportsBidirectionalAXMFiHearingDeviceStreaming"}

local function tail(file, count)
    local lines = (io.readfile(file) or ""):split("\n")
    local first = math.max(1, #lines - count + 1)
    return table.concat(lines, "\n", first) .. (#lines > 0 and "\n" or "")
end

local function compile(arguments, log, failure)
    local status = os.execv("xcrun", table.join({"clang"}, arguments), {stderr = log, try = true})
    if status ~= 0 then
        io.stderr:write(failure .. "\n")
        io.stderr:write(tail(log, 20))
        return false
    end
    return true
end

function defined_hearing(object)
    local defined = {}
    for _, line in ipairs(os.iorunv("nm", {"-gU", object}):split("\n")) do
        local symbol = line:match("(%S+)%s*$")
        if symbol and (symbol:startswith("_AXMFiHearingDevice") or symbol:startswith("_AXSupportsBidirectional")) then
            table.insert(defined, symbol)
        end
    end
    byteorder.sort(defined)
    return defined
end

function run(opt)
    opt = opt or {}
    local here = os.scriptdir()
    local sources = opt.sources or path.join(revenant, "packages", "frameworks", "apple-backports", "Accessibility")
    local build = opt.build or workspace.run("revenant-accessibility-settings")
    os.tryrm(build)
    os.mkdir(build)
    local sdk = os.iorunv("xcrun", {"--show-sdk-path"}):trim()
    if not compile({"-target", "arm64-apple-macos26.0", "-isysroot", sdk, "-fobjc-arc", "-O0", "-Wall", "-Wno-nonnull",
                    path.join(here, "check.m"), path.join(sources, "RevenantAXSettings17.m"), path.join(sources, "RevenantAXSettings18.m"),
                    path.join(sources, "RevenantAXSettings26.m"), "-I" .. sources, "-framework", "Foundation", "-framework", "Accessibility",
                    "-o", path.join(build, "check")}, path.join(build, "build.log"), "the settings check did not build") then
        return 1
    end
    local status = os.execv(path.join(build, "check"), {}, {try = true})
    if status ~= 0 then
        if status == -1 then
            io.stderr:write("the settings check died of a signal before it could finish\n")
        end
        return status == -1 and 1 or status
    end
    local ios_sdk = workspace.sdk_package("16.4")
    local ios = {"-target", "armv7-apple-ios6.0", "-isysroot", ios_sdk, "-fobjc-arc"}
    local lenient = {"-Wno-unguarded-availability", "-Wno-unguarded-availability-new", "-I" .. sources, "-c"}
    if not compile(table.join(ios, {"-O0", "-Wall", "-Wno-nonnull"}, lenient, {path.join(here, "hearing-check.m"), "-o", path.join(build, "hearing-check.o")}),
                   path.join(build, "hearing.log"), "the hearing check did not compile") then
        return 1
    end
    local object = path.join(build, "RevenantHearing15.o")
    if not compile(table.join(ios, {"-Os", "-g0", "-Wall", "-Wno-nonnull"}, lenient, {path.join(sources, "RevenantHearing15.m"), "-o", object}),
                   path.join(build, "hearing-obj.log"), "the hearing object did not compile") then
        return 1
    end
    print("hearing: compiled for armv7-apple-ios6.0, and the port defines:")
    local defined = defined_hearing(object)
    if #defined == 0 then
        print("")
    end
    local present = {}
    for _, symbol in ipairs(defined) do
        print("  " .. symbol:sub(2))
        present[symbol] = true
    end
    local missing = 0
    for _, symbol in ipairs(HEARING) do
        if not present[symbol] then
            print(string.format("check\tthe port defines %s\tFAILED\tnot defined in the object", symbol:sub(2)))
            missing = missing + 1
        end
    end
    if missing > 0 then
        print(string.format("hearing: %d of the three functions the port must define are not there", missing))
        return 1
    end
    print("hearing: OWED - not run here, because the declarations are API_UNAVAILABLE(macos) and this machine has no iOS runtime")
    print("hearing: held by the compile above, by the nm assertion above, and by axs-census.lua; the command that would settle it is in this directory's README.md")
    return 0
end

function main()
    local source = os.getenv("ACCESSIBILITY_SRC")
    local build = os.getenv("BUILD")
    local status = run({sources = source ~= "" and source or nil, build = build ~= "" and build or nil})
    if status ~= 0 then
        os.exit(status)
    end
end
