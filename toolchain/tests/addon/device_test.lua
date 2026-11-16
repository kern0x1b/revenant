import("fixtures")

function claim_failures(device, folder)
    local found = {}
    local home, holder, leases = os.getenv("REVENANT_CACHE"), os.getenv("REVENANT_DEVICE_HOLDER"), os.getenv("REVENANT_DEVICE_LEASES")
    os.setenv("REVENANT_CACHE", path.join(folder, "home"))
    os.setenv("REVENANT_DEVICE_LEASES", path.join(folder, "leases"))
    local phone = {host = "10.0.0.7", port = "22", password = "", udid = "abc123"}
    device.claim(phone, "first", 30)
    local errors = fixtures.refusal(function () device.claim(phone, "second", 30) end)
    if not errors or not errors:find("held by first", 1, true) then
        table.insert(found, "a claimed device must refuse a second holder, naming the first: " .. tostring(errors))
    end
    os.setenv("REVENANT_CACHE", path.join(folder, "other-home"))
    errors = fixtures.refusal(function () device.claim(phone, "second", 30) end)
    if not errors or not errors:find("held by first", 1, true) then
        table.insert(found, "a claim is seen from every cache, so a second cache must refuse a second holder too: " .. tostring(errors))
    end
    if not device.lease("abc123") or device.lease("abc123").holder ~= "first" then
        table.insert(found, "the claim of one cache is listed from another")
    end
    os.setenv("REVENANT_CACHE", path.join(folder, "home"))
    if not fixtures.refusal(function () device.release(phone, "second") end) then
        table.insert(found, "only the holder releases a claim")
    end
    os.setenv("REVENANT_DEVICE_HOLDER", "second")
    errors = fixtures.refusal(function () device.tunnel(phone) end)
    if not errors or not errors:find("held by first", 1, true) then
        table.insert(found, "reaching a device another holder claimed must be refused: " .. tostring(errors))
    end
    os.setenv("REVENANT_DEVICE_HOLDER", "first")
    if fixtures.refusal(function () device.tunnel(phone) end) then
        table.insert(found, "the holder reaches the device it claimed")
    end
    if not device.held(phone, "first") or device.held(phone, "second") or device.held(phone, "") or not device.held(phone, nil) then
        table.insert(found, "held must be true for the holder of a live claim, named or from REVENANT_DEVICE_HOLDER, and for nobody else")
    end
    device.release(phone, "first")
    if device.lease("abc123") then
        table.insert(found, "a released device has no claim")
    end
    if device.held(phone, "first") then
        table.insert(found, "a released device is held by nobody")
    end
    device.claim(phone, "second", 30)
    io.writefile(path.join(folder, "leases", "abc123.lease", "holder"), "second\n" .. (os.time() - 1) .. "\n")
    if device.lease("abc123") or fixtures.refusal(function () device.claim(phone, "third", 5) end) then
        table.insert(found, "an expired claim frees the device")
    end
    if not fixtures.refusal(function () device.claim({host = "127.0.0.1", port = "2222", password = "", udid = ""}, "first", 5) end) then
        table.insert(found, "a tunnel on 127.0.0.1 serves any attached device, so a claim there needs the UDID")
    end
    local networked = {host = "10.0.0.9", port = "22", password = "", udid = ""}
    device.claim(networked, "first", 5)
    os.setenv("REVENANT_DEVICE_HOLDER", "second")
    errors = fixtures.refusal(function () device.tunnel(networked) end)
    if not errors or not errors:find("held by first", 1, true) then
        table.insert(found, "a device claimed by its address must refuse another holder: " .. tostring(errors))
    end
    os.setenv("REVENANT_DEVICE_HOLDER", "first")
    device.release(networked, "first")
    for name, value in pairs({REVENANT_CACHE = home or false, REVENANT_DEVICE_HOLDER = holder or false, REVENANT_DEVICE_LEASES = leases or false}) do
        if value then
            os.setenv(name, value)
        else
            os.setenv(name, nil)
        end
    end
    return found
end

local function pruning_failures(device, folder)
    local found = {}
    local bin = path.join(folder, "prune-bin")
    os.mkdir(bin)
    local state = path.join(folder, "prune-state")
    io.writefile(path.join(bin, "dpkg-query"), "#!/bin/sh\ncat " .. state .. "\n")
    io.writefile(path.join(bin, "dpkg"), "#!/bin/sh\nshift\nfor p in \"$@\"; do grep -v \"^$p|\" " .. state .. " > " .. state .. ".new; mv " .. state .. ".new " .. state .. "; done\n")
    os.vrunv("chmod", {"+x", path.join(bin, "dpkg-query"), path.join(bin, "dpkg")})
    local function installed(lines)
        io.writefile(state, table.concat(lines, "\n") .. "\n")
    end
    local function remove(packages, opt)
        os.vrunv("sh", {"-c", device.uninstall_command(packages, opt)}, {envs = {PATH = bin .. ":" .. os.getenv("PATH")}})
        local left = {}
        for line in io.readfile(state):gmatch("[^\n]+") do
            table.insert(left, (line:gsub("|.*", "")))
        end
        table.sort(left)
        return table.concat(left, " ")
    end
    local ok = "|install ok installed|"
    local function chain(extra)
        return table.join({
            "port.a" .. ok .. "org.revenant.swift-runtime-11111111 (= 1), org.revenant.libcxx-22222222 (= 1)",
            "port.b" .. ok .. "org.revenant.swift-runtime-11111111 (= 1), org.revenant.libcxx-22222222 (= 1)",
            "org.revenant.swift-runtime-11111111" .. ok .. "org.revenant.libcxx-22222222 (= 1)",
            "org.revenant.swift-runtime-ui-11111111" .. ok .. "org.revenant.swift-runtime-11111111 (= 1)",
            "org.revenant.libcxx-22222222" .. ok,
            "org.revenant.backports" .. ok,
            "org.revenant.swiftfull" .. ok
        }, extra or {})
    end
    installed(chain())
    local left = remove({"port.a"})
    if left ~= "org.revenant.backports org.revenant.libcxx-22222222 org.revenant.swift-runtime-11111111 org.revenant.swiftfull port.b" then
        table.insert(found, "the runtime a program still needs must stay, and the UI package nobody needs must go: " .. left)
    end
    left = remove({"port.b"})
    if left ~= "org.revenant.backports org.revenant.swiftfull" then
        table.insert(found, "the last program takes the runtime and the C++ runtime with it, in as many passes as it takes, and leaves everything else: " .. left)
    end
    installed(chain())
    left = remove({"port.a"}, {keep = true})
    if not left:find("org.revenant.swift-runtime-ui-11111111", 1, true) then
        table.insert(found, "keep must remove only what is named: " .. left)
    end
    installed(chain({"port.ui" .. ok .. "org.revenant.swift-runtime-ui-11111111 (= 1)"}))
    left = remove({"port.b"})
    if not left:find("org.revenant.swift-runtime-ui-11111111", 1, true) or not left:find("org.revenant.swift-runtime-11111111", 1, true) then
        table.insert(found, "a program that needs the UI package keeps it, and the runtime it needs: " .. left)
    end
    installed(chain({"ghost|deinstall ok config-files|org.revenant.swift-runtime-11111111 (= 1)"}))
    left = remove({"port.a", "port.b"})
    if left:find("org.revenant.swift-runtime-1", 1, true) then
        table.insert(found, "a package that is removed and only keeps its configuration files needs nothing: " .. left)
    end
    if not fixtures.refusal(function () device.uninstall_command({"x; rm -rf /"}) end) then
        table.insert(found, "a package name that is not a Debian package name must be refused")
    end
    return found
end

local OLD, NEW = "0a2b76cd", "5fa6884c"

local function runtime_failures(device, folder, opt)
    local found = {}
    local function fail(message)
        table.insert(found, message)
    end
    local work = path.join(folder, "runtime")
    os.mkdir(work)
    io.writefile(path.join(work, "libSystem.tbd"), fixtures.system_stub())
    local function runtime(key)
        local source = "core_" .. key .. ".c"
        io.writefile(path.join(work, source), string.format("int core_%s(void) { return 1; }\n", key))
        return fixtures.link(work, opt.ld64, "libswiftCore-" .. key .. ".dylib", "armv7-apple-ios6.0", source,
                             {"-dynamiclib", "-install_name", "/usr/lib/revenant/org.revenant.swift-runtime-" .. key .. "/libswiftCore.dylib"})
    end
    local function consumer(package, name, key, core)
        local source = name .. "-" .. key .. ".c"
        io.writefile(path.join(work, source), string.format("extern int core_%s(void);\nint %s_%s(void) { return core_%s(); }\n", key, name, key, key))
        local library = fixtures.link(work, opt.ld64, name .. "-" .. key .. ".dylib", "armv7-apple-ios6.0", source,
                                      {"-dynamiclib", "-install_name", "/usr/lib/revenant/" .. package .. "/" .. name .. ".dylib", core})
        return {file = "/usr/lib/revenant/" .. package .. "/" .. name .. ".dylib",
                links = device.runtime_links(fixtures.run(work, "xcrun", {"otool", "-arch", "armv7", "-L", library}))}
    end
    local old, new = runtime(OLD), runtime(NEW)
    local utility = consumer("org.revenant.uniformtypeidentifiers-f72850ed", "libswiftUniformTypeIdentifiers", OLD, old)
    local crypto = consumer("org.revenant.swift-crypto-91c43b24", "libswiftCrypto", OLD, old)
    local interface = consumer("org.revenant.swift-runtime-ui-" .. NEW, "libswiftUIKit", NEW, new)
    if #utility.links ~= 1 or utility.links[1].package ~= "org.revenant.swift-runtime-" .. OLD or utility.links[1].image ~= "libswiftCore.dylib" then
        fail("the Swift runtime a library links is read from its otool -L listing as the package folder and the library: " .. #utility.links .. " links")
    end
    for name, key in pairs({["org.revenant.swift-runtime-" .. NEW] = NEW, ["org.revenant.swift-runtime-ui-" .. NEW] = NEW}) do
        if device.runtime_key(name) ~= key then
            fail(name .. " carries the runtime key " .. key .. ", read " .. tostring(device.runtime_key(name)))
        end
    end
    for _, name in ipairs({"org.revenant.backports", "org.revenant.libcxx-341c5c30", "org.revenant.swift-crypto-91c43b24", "org.revenant.cryptokit-45dc94fc"}) do
        if device.runtime_key(name) then
            fail(name .. " is not a Swift runtime package")
        end
    end
    local installed = {}
    for _, name in ipairs({"org.revenant.swift-runtime-" .. OLD, "org.revenant.swift-runtime-" .. NEW, "org.revenant.swift-runtime-ui-" .. NEW}) do
        installed[name] = true
    end
    local mixed = {utility, crypto, interface}
    local problems, warnings = device.runtime_problems(mixed, installed, NEW)
    if #problems ~= 2 or not problems[1]:find(utility.file, 1, true) or not problems[1]:find(OLD, 1, true) or not problems[1]:find(NEW, 1, true)
       or not problems[2]:find(crypto.file, 1, true) or #warnings ~= 0 then
        fail("a library of a package the host loads that links another runtime than the host's is an error naming the file and both keys: " .. table.concat(problems, " | "))
    end
    problems, warnings = device.runtime_problems(mixed, installed, nil)
    if #problems ~= 0 or #warnings ~= 1 or not warnings[1]:find(OLD, 1, true) or not warnings[1]:find(NEW, 1, true) or not warnings[1]:find(utility.file, 1, true) then
        fail("without a host, packages that link two runtimes are a warning naming both keys and the files: " .. table.concat(problems, " | ") .. " / " .. table.concat(warnings, " | "))
    end
    problems, warnings = device.runtime_problems({interface}, installed, NEW)
    if #problems ~= 0 or #warnings ~= 0 then
        fail("a library that links the host's runtime is no problem: " .. table.concat(problems, " | "))
    end
    problems = device.runtime_problems({utility}, {["org.revenant.swift-runtime-" .. NEW] = true}, nil)
    if #problems ~= 1 or not problems[1]:find("not installed", 1, true) or not problems[1]:find(OLD, 1, true) then
        fail("a library that links a runtime the phone does not hold is an error: " .. table.concat(problems, " | "))
    end
    problems = device.runtime_problems({{file = "/usr/lib/revenant/x/libX.dylib", links = {{package = "org.revenant.swift-runtime-" .. NEW, image = "libswiftCore.dylib"},
                                                                                         {package = "org.revenant.swift-runtime-ui-" .. NEW, image = "libswiftUIKit.dylib"}}}}, installed, NEW)
    if #problems ~= 0 then
        fail("a library that links the runtime and its UI package of one key is no problem: " .. table.concat(problems, " | "))
    end
    local paths = device.revenant_links(table.concat({"x.dylib:", "\t/usr/lib/revenant/org.revenant.backports/libFoundationBackports.dylib (compatibility version 1.0.0, current version 1.0.0)",
                                                      "\t/System/Library/Frameworks/UIKit.framework/UIKit (compatibility version 1.0.0, current version 1.0.0)", ""}, "\n"))
    if #paths ~= 1 or paths[1].package ~= "org.revenant.backports" or #device.runtime_links("\t/usr/lib/revenant/org.revenant.backports/libFoundationBackports.dylib (x)") ~= 0 then
        fail("only the packages of /usr/lib/revenant are listed, and the Backports are not a runtime")
    end
    return found
end

function failures(opt)
    local device = import("device", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local folder = fixtures.scratch()
    table.join2(found, pruning_failures(device, folder))
    table.join2(found, runtime_failures(device, folder, opt))
    io.writefile(path.join(folder, "device.env"), table.concat({
        "# the phone on the desk",
        "export DEVICE_HOST=10.0.0.7",
        "DEVICE_PORT='22' # quoted",
        "DEVICE_PASSWORD=\"secret value\"",
        "DEVICE_UDID=abc123 # trailing",
        "not a line"
    }, "\n"))
    io.writefile(path.join(folder, "device.spare.env"), "DEVICE_HOST=10.0.0.8\n")
    local settings = device.bind(folder)
    local wanted = {host = "10.0.0.7", port = "22", password = "secret value", udid = "abc123"}
    for key, value in pairs(wanted) do
        if settings[key] ~= value then
            table.insert(found, string.format("device.env gives %s=%s, read %s", key, value, tostring(settings[key])))
        end
    end
    if device.bind(folder, "spare").host ~= "10.0.0.8" then
        table.insert(found, "a named device reads device.NAME.env")
    end
    local errors = fixtures.refusal(function () device.bind(folder, "absent") end)
    if not errors or not errors:find("this port has device.env, device.spare.env", 1, true) then
        table.insert(found, "a phone nothing names must be refused, listing the env files there are: " .. tostring(errors))
    end
    table.join2(found, claim_failures(device, folder))
    os.tryrm(folder)
    return found
end
