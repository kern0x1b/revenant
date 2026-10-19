import("fixtures")

function claim_failures(device, folder)
    local found = {}
    local home, holder = os.getenv("CHARON_HOME"), os.getenv("CHARON_DEVICE_HOLDER")
    os.setenv("CHARON_HOME", path.join(folder, "home"))
    local phone = {host = "10.0.0.7", port = "22", password = "", udid = "abc123"}
    device.claim(phone, "first", 30)
    local errors = fixtures.refusal(function () device.claim(phone, "second", 30) end)
    if not errors or not errors:find("held by first", 1, true) then
        table.insert(found, "a claimed device must refuse a second holder, naming the first: " .. tostring(errors))
    end
    if not fixtures.refusal(function () device.release(phone, "second") end) then
        table.insert(found, "only the holder releases a claim")
    end
    os.setenv("CHARON_DEVICE_HOLDER", "second")
    errors = fixtures.refusal(function () device.tunnel(phone) end)
    if not errors or not errors:find("held by first", 1, true) then
        table.insert(found, "reaching a device another holder claimed must be refused: " .. tostring(errors))
    end
    os.setenv("CHARON_DEVICE_HOLDER", "first")
    if fixtures.refusal(function () device.tunnel(phone) end) then
        table.insert(found, "the holder reaches the device it claimed")
    end
    device.release(phone, "first")
    if device.lease("abc123") then
        table.insert(found, "a released device has no claim")
    end
    device.claim(phone, "second", 30)
    io.writefile(path.join(folder, "home", "devices", "abc123.lease", "holder"), "second\n" .. (os.time() - 1) .. "\n")
    if device.lease("abc123") or fixtures.refusal(function () device.claim(phone, "third", 5) end) then
        table.insert(found, "an expired claim frees the device")
    end
    if not fixtures.refusal(function () device.claim({host = "127.0.0.1", port = "2222", password = "", udid = ""}, "first", 5) end) then
        table.insert(found, "a tunnel on 127.0.0.1 serves any attached device, so a claim there needs the UDID")
    end
    local networked = {host = "10.0.0.9", port = "22", password = "", udid = ""}
    device.claim(networked, "first", 5)
    os.setenv("CHARON_DEVICE_HOLDER", "second")
    errors = fixtures.refusal(function () device.tunnel(networked) end)
    if not errors or not errors:find("held by first", 1, true) then
        table.insert(found, "a device claimed by its address must refuse another holder: " .. tostring(errors))
    end
    os.setenv("CHARON_DEVICE_HOLDER", "first")
    device.release(networked, "first")
    for name, value in pairs({CHARON_HOME = home or false, CHARON_DEVICE_HOLDER = holder or false}) do
        if value then
            os.setenv(name, value)
        else
            os.setenv(name, nil)
        end
    end
    return found
end

-- The removal runs against a stand-in for dpkg that keeps its packages in a file, one per line as name|status|depends.
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
            "port.a" .. ok .. "org.charon.swift-runtime-11111111 (= 1), org.charon.libcxx-22222222 (= 1)",
            "port.b" .. ok .. "org.charon.swift-runtime-11111111 (= 1), org.charon.libcxx-22222222 (= 1)",
            "org.charon.swift-runtime-11111111" .. ok .. "org.charon.libcxx-22222222 (= 1)",
            "org.charon.swift-runtime-ui-11111111" .. ok .. "org.charon.swift-runtime-11111111 (= 1)",
            "org.charon.libcxx-22222222" .. ok,
            "org.charon.apple-backports" .. ok,
            "org.charon.swiftfull" .. ok
        }, extra or {})
    end
    installed(chain())
    local left = remove({"port.a"})
    if left ~= "org.charon.apple-backports org.charon.libcxx-22222222 org.charon.swift-runtime-11111111 org.charon.swiftfull port.b" then
        table.insert(found, "the runtime a program still needs must stay, and the UI package nobody needs must go: " .. left)
    end
    left = remove({"port.b"})
    if left ~= "org.charon.apple-backports org.charon.swiftfull" then
        table.insert(found, "the last program takes the runtime and the C++ runtime with it, in as many passes as it takes, and leaves everything else: " .. left)
    end
    installed(chain())
    left = remove({"port.a"}, {keep = true})
    if not left:find("org.charon.swift-runtime-ui-11111111", 1, true) then
        table.insert(found, "keep must remove only what is named: " .. left)
    end
    installed(chain({"port.ui" .. ok .. "org.charon.swift-runtime-ui-11111111 (= 1)"}))
    left = remove({"port.b"})
    if not left:find("org.charon.swift-runtime-ui-11111111", 1, true) or not left:find("org.charon.swift-runtime-11111111", 1, true) then
        table.insert(found, "a program that needs the UI package keeps it, and the runtime it needs: " .. left)
    end
    installed(chain({"ghost|deinstall ok config-files|org.charon.swift-runtime-11111111 (= 1)"}))
    left = remove({"port.a", "port.b"})
    if left:find("org.charon.swift-runtime-1", 1, true) then
        table.insert(found, "a package that is removed and only keeps its configuration files needs nothing: " .. left)
    end
    if not fixtures.refusal(function () device.uninstall_command({"x; rm -rf /"}) end) then
        table.insert(found, "a package name that is not a Debian package name must be refused")
    end
    return found
end

function failures(opt)
    local device = import("device", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local folder = fixtures.scratch()
    table.join2(found, pruning_failures(device, folder))
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
