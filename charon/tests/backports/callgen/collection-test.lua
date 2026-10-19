local charon = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
local workspace = import("workspace", {rootdir = path.join(charon, "modules"), anonymous = true})
local mutant = import("collection-mutant", {rootdir = os.scriptdir(), anonymous = true})

local FACTORY = "successesWithResolvedMediaItems:"

local function tail(file, count)
    local lines = (io.readfile(file) or ""):split("\n")
    return table.concat(lines, "\n", math.max(1, #lines - count + 1)) .. "\n"
end

local function clang(arguments, log, failure)
    local handle = io.open(log, "a")
    local status = os.execv("xcrun", table.join({"clang"}, arguments), {stderr = handle, try = true})
    handle:close()
    if status ~= 0 then
        io.stderr:write(failure .. "\n")
        io.stderr:write(tail(log, 10))
        return false
    end
    return true
end

function factory_source(build)
    local out = path.join(build, "intents")
    os.execv(os.programfile(), {"l", path.join(charon, "tools", "intents", "objects.lua"), "--out", out, "--work", path.join(build, "intents-work")},
             {stdout = path.join(build, "intents.log")})
    for _, file in ipairs(os.files(path.join(out, "*.m"))) do
        local text = io.readfile(file)
        if text:find(FACTORY, 1, true) and text:find("    return results;\n}", 1, true) then
            return file
        end
    end
    raise("none of the Intents objects in %s implements +%s", out, FACTORY)
end

function run(opt)
    opt = opt or {}
    local here = os.scriptdir()
    local build = opt.build or workspace.fresh("charon-callgen")
    os.mkdir(build)
    local sdk = os.iorunv("xcrun", {"--show-sdk-path"}):trim()
    local host = {"-target", "arm64-apple-macos26.0", "-isysroot", sdk, "-fobjc-arc", "-O0", "-w"}
    if not clang(table.join(host, {path.join(here, "collection-host.m"), "-framework", "Foundation", "-framework", "Intents",
                                   "-o", path.join(build, "host")}), path.join(build, "host-build.log"), "the host probe did not build") then
        return 1
    end
    local status = os.execv(path.join(build, "host"), {"the host's own Intents"}, {try = true})
    if status ~= 0 then
        return status
    end
    local source = opt.source or factory_source(build)
    local name = path.basename(source)
    io.writefile(path.join(build, name .. ".mutant.m"), mutant.mutated(io.readfile(source, {encoding = "binary"})), {encoding = "binary"})
    local port_sdk = workspace.sdk_package("16.4")
    local ports = {"CharonPortMediaItemResolutionResult", "CharonPortMediaItem"}
    for _, half in ipairs({"real", "mutant"}) do
        print("=== " .. half)
        io.flush()
        local compiled = half == "mutant" and path.join(build, name .. ".mutant.m") or source
        local object = path.join(build, name .. "." .. half .. ".o")
        local log = path.join(build, "build.log")
        if not clang({"-target", "armv7-apple-ios6.1.3", "-isysroot", port_sdk, "-fobjc-arc", "-O0", "-w",
                      "-I" .. path.join(charon, "packages", "c", "charon-coding", "files"),
                      "-I" .. path.join(charon, "packages", "a", "apple-backports", "Intents"), "-c", compiled, "-o", object},
                     log, string.format("the %s half did not compile", half)) then
            return 1
        end
        if not clang(table.join(host, {path.join(here, "collection-test.m"), object, "-framework", "Foundation", "-framework", "Intents",
                                       "-o", path.join(build, half)}), log, string.format("the %s runner did not build", half)) then
            return 1
        end
        status = os.execv(path.join(build, half), table.join({string.format("the port's own body (%s)", half)}, ports), {try = true})
        if status ~= 0 then
            return status
        end
    end
    local counts = {}
    for _, half in ipairs({"real", "mutant"}) do
        counts[half] = os.iorunv(path.join(build, half), table.join({"counts"}, ports))
        io.writefile(path.join(build, half .. ".counts"), counts[half])
    end
    if counts.real == counts.mutant then
        print("FAIL: the mutation did not change the count table, so the two halves are the same code")
        return 1
    end
    print("the mutation turns the table red - the two halves differ:")
    io.flush()
    os.execv("diff", {path.join(build, "real.counts"), path.join(build, "mutant.counts")}, {try = true})
    return 0
end

function main(source)
    local build = os.getenv("BUILD")
    local status = run({build = build ~= "" and build or nil, source = source})
    if status ~= 0 then
        os.exit(status)
    end
end
