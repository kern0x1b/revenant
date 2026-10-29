import("deps")

local function apple_toolchain(package)
    local found = assert(package:toolchains(), package:name() .. " is built for apple-ios without the apple-ios toolchain")[1]
    found:load()
    return found
end

function check(package, opt)
    opt = opt or {}
    local chosen = apple_toolchain(package)
    local from_deps = opt.deps and deps.flags(package, opt.deps) or {cflags = {}, cxxflags = {}, ldflags = {}}
    local dir = path.join(package:cachedir(), "probe")
    os.mkdir(dir)
    local source = path.join(dir, opt.name or "probe.cpp")
    io.writefile(source, opt.source)
    local cxx = path.extension(source) ~= ".c"
    local compiler = cxx and chosen:tool("cxx") or chosen:tool("cc")
    local envs = {IPHONEOS_DEPLOYMENT_TARGET = chosen:config("deployment")}
    local log = path.join(dir, "log.txt")
    local object = path.join(dir, "probe.o")
    local own = {"-isystem" .. package:installdir("include")}
    local compiled = table.join(table.wrap(chosen:get("cxflags")), own, table.wrap(opt.flags), from_deps.cflags,
                                cxx and from_deps.cxxflags or {})
    local ok, output = false, ""
    try {
        function ()
            os.vrunv(compiler, table.join(compiled, {"-c", source, "-o", object}),
                     {envs = envs, stdout = log, stderr = log})
            if opt.link then
                local executable = path.join(dir, "probe")
                os.vrunv(compiler, table.join(table.wrap(chosen:get("ldflags")), {"-L" .. package:installdir("lib")},
                                              table.wrap(opt.ldflags), from_deps.ldflags, {"-o", executable, object}),
                         {envs = envs, stdout = log, stderr = log})
                local imported = os.iorunv("xcrun", {"nm", "-u", executable}):split("\n")
                for _, symbol in ipairs(table.wrap(opt.forbid)) do
                    if table.contains(imported, symbol) then
                        raise("the probe binds %s from the system, which this release does not have", symbol)
                    end
                end
                if opt.bound then
                    local bindings = table.imap(os.iorunv("xcrun", {"dyld_info", "-imports", executable}):split("\n"),
                                                function (_, line) return line:trim() end)
                    for symbol, library in pairs(opt.bound) do
                        if not table.contains(bindings, symbol .. "  (from " .. library .. ")") then
                            local seen = {}
                            for _, line in ipairs(bindings) do
                                if line:find(symbol, 1, true) then
                                    table.insert(seen, line)
                                end
                            end
                            raise("the probe does not bind %s from %s; dyld_info says: %s", symbol, library, table.concat(seen, " | "))
                        end
                    end
                end
                if opt.linked then
                    local libraries = os.iorunv("xcrun", {"otool", "-L", executable})
                    if not libraries:find(opt.linked, 1, true) then
                        raise("the probe does not link %s, the runtime it binds from", opt.linked)
                    end
                end
            end
            ok = true
        end,
        catch {
            function (errors)
                output = tostring(errors or "")
            end
        }
    }
    local text = os.isfile(log) and io.readfile(log) or ""
    os.rm(dir)
    return ok, ok and "" or (text .. tostring(output or ""))
end

function require_architecture(file, architecture)
    local found = os.iorunv("xcrun", {"lipo", "-archs", file}):trim()
    assert(found:find(architecture, 1, true), file .. " is built for " .. found .. ", not " .. architecture)
end
