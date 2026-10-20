import("core.base.option")
import("core.base.process")
import("lib.detect.find_tool")
import("byteorder")
import("workspace")

CHOSEN = "REVENANT_DEVICE"

local defaults = {host = "127.0.0.1", port = "2222", password = "", udid = ""}

local ssh_options = {
    "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
    "-o", "LogLevel=ERROR", "-o", "ConnectTimeout=8",
    "-o", "HostKeyAlgorithms=+ssh-rsa", "-o", "PubkeyAcceptedKeyTypes=+ssh-rsa",
    "-o", "KexAlgorithms=+diffie-hellman-group1-sha1,diffie-hellman-group14-sha1",
    "-o", "Ciphers=+aes128-cbc,3des-cbc",
    "-o", "ControlMaster=auto", "-o", "ControlPersist=60",
    "-o", "ControlPath=/tmp/revenant-ssh-%h-%p"
}

function read_env_file(file)
    local values = {}
    if not os.isfile(file) then
        return values
    end
    for raw in io.readfile(file):gmatch("[^\n]+") do
        local line = raw:trim()
        if line ~= "" and not line:startswith("#") then
            if line:startswith("export ") then
                line = line:sub(8):ltrim()
            end
            local key, value = line:match("^([%a_][%w_]*)=(.*)$")
            if key then
                value = value:trim()
                local quote = value:sub(1, 1)
                if quote == "'" or quote == '"' then
                    local finish = value:find(quote, 2, true)
                    value = finish and value:sub(2, finish - 1) or value:sub(2)
                else
                    value = value:gsub("%s+#.*$", ""):trim()
                end
                values[key] = value
            end
        end
    end
    return values
end

function env_file(root, name)
    local chosen = name or os.getenv(CHOSEN)
    return path.join(root, chosen and ("device." .. chosen .. ".env") or "device.env")
end

function bind(root, name)
    local file = env_file(root, name)
    if not os.isfile(file) and not os.getenv("DEVICE_HOST") and not os.getenv("DEVICE_UDID") then
        local known = {}
        for _, found in ipairs(os.files(path.join(root, "device*.env"))) do
            table.insert(known, path.filename(found))
        end
        byteorder.sort(known)
        raise("nothing names a phone: %s does not exist and DEVICE_HOST is unset%s. %s:%s is not a safe guess - on a machine with a USB tunnel it reaches whichever phone that tunnel serves.",
              file, #known > 0 and (" (this port has " .. table.concat(known, ", ") .. ")") or "", defaults.host, defaults.port)
    end
    local values = read_env_file(file)
    local function value(...)
        for _, key in ipairs({...}) do
            local found = values[key] or os.getenv(key)
            if found and found ~= "" then
                return found
            end
        end
    end
    return {
        host = value("DEVICE_HOST") or defaults.host,
        port = value("DEVICE_PORT") or defaults.port,
        password = value("DEVICE_PASSWORD", "DEVICE_PASS") or defaults.password,
        udid = value("DEVICE_UDID") or defaults.udid
    }
end

function where(settings)
    return settings.host .. ":" .. settings.port
end

local function leases()
    return path.join(workspace.home(), "devices")
end

function holder_name(given)
    return given or os.getenv("REVENANT_DEVICE_HOLDER")
end

local function lease_of(udid)
    local file = path.join(leases(), udid .. ".lease", "holder")
    if not os.isfile(file) then
        return nil
    end
    local name, expires = io.readfile(file):match("^([^\n]*)\n(%d+)")
    if not name then
        return nil
    end
    return {holder = name, expires = tonumber(expires)}
end

function lease(udid)
    local found = lease_of(udid)
    if found and found.expires <= os.time() then
        os.tryrm(path.join(leases(), udid .. ".lease"))
        return nil
    end
    return found
end

local function identified(settings)
    if settings.udid ~= "" then
        return settings.udid
    end
    if settings.host ~= "127.0.0.1" then
        return (settings.host .. "-" .. settings.port):gsub("[^%w%-%.]", "_")
    end
    raise("claiming the device on %s needs its UDID, because that port can serve any attached device: set DEVICE_UDID in device.env or the environment; xmake device list shows the attached ones", where(settings))
end

function claim(settings, holder, minutes)
    local udid = identified(settings)
    if not holder or holder == "" then
        raise("a claim names who holds the device: --holder=NAME or REVENANT_DEVICE_HOLDER")
    end
    os.mkdir(leases())
    local folder = path.join(leases(), udid .. ".lease")
    local current = lease(udid)
    if current and current.holder ~= holder then
        raise("%s is held by %s until %s; wait for xmake device release there, or for the claim to expire", udid, current.holder, os.date("%H:%M:%S", current.expires))
    end
    if not current and not os.isdir(folder) then
        local made = try { function () os.runv("mkdir", {folder}); return true end }
        if not made then
            current = lease(udid)
            raise("%s was claimed at the same moment by %s", udid, current and current.holder or "another holder")
        end
    end
    local expires = os.time() + minutes * 60
    io.writefile(path.join(folder, "holder"), holder .. "\n" .. expires .. "\n")
    return expires
end

function release(settings, holder)
    local udid = identified(settings)
    local current = lease(udid)
    if current and current.holder ~= holder then
        raise("%s is held by %s, not by %s", udid, current.holder, tostring(holder))
    end
    os.tryrm(path.join(leases(), udid .. ".lease"))
end

local function admitted(settings)
    local key = settings.udid
    if key == "" then
        if settings.host == "127.0.0.1" then
            return
        end
        key = (settings.host .. "-" .. settings.port):gsub("[^%w%-%.]", "_")
    end
    local current = lease(key)
    local holder = holder_name()
    if current and current.holder ~= holder then
        raise("%s is held by %s until %s; this process runs as %s. Wait for the release, or claim it after that", key, current.holder, os.date("%H:%M:%S", current.expires), holder or "no holder (REVENANT_DEVICE_HOLDER is unset)")
    end
end

local function tunnelled_device(port)
    local listing = try { function () return os.iorunv("pgrep", {"-fl", "iproxy"}) end } or ""
    for line in listing:gmatch("[^\n]+") do
        local listened, udid = line:match("iproxy%s+(%d+)[:%s]+22%s+%-u%s+([%x%-]+)")
        if listened == tostring(port) then
            return udid
        end
    end
end

function attached()
    local found = {}
    for _, udid in ipairs(((try { function () return os.iorunv("idevice_id", {"-l"}) end }) or ""):split("%s+")) do
        if udid ~= "" then
            local function key(name)
                return ((try { function () return os.iorunv("ideviceinfo", {"-u", udid, "-k", name}) end }) or ""):trim()
            end
            local port
            local listing = try { function () return os.iorunv("pgrep", {"-fl", "iproxy"}) end } or ""
            for line in listing:gmatch("[^\n]+") do
                local listened, served = line:match("iproxy%s+(%d+)[:%s]+22%s+%-u%s+([%x%-]+)")
                if served == udid then
                    port = listened
                end
            end
            table.insert(found, {udid = udid, product = key("ProductType"), release = key("ProductVersion"), port = port, lease = lease(udid)})
        end
    end
    return found
end

local function port_open(host, port)
    return try { function ()
        os.runv("nc", {"-z", "-G", "2", host, port})
        return true
    end }
end

function tunnel(settings)
    admitted(settings)
    if settings.host ~= "127.0.0.1" then
        return
    end
    local serving = tunnelled_device(settings.port)
    if serving and settings.udid ~= "" and serving ~= settings.udid then
        raise("port %s tunnels to %s, not to %s; give this device its own DEVICE_PORT (xmake device list shows the tunnels)", settings.port, serving, settings.udid)
    end
    if port_open(settings.host, settings.port) then
        return
    end
    local iproxy = find_tool("iproxy")
    if not iproxy then
        return
    end
    local udid = settings.udid
    if udid == "" then
        local attached = (try { function () return os.iorunv("idevice_id", {"-l"}) end } or ""):split("%s+")
        if #attached == 1 then
            udid = attached[1]
        end
    end
    if udid == "" then
        wprint("tunnel on %s is down and DEVICE_UDID is not set", settings.port)
        return
    end
    if serving then
        try { function () os.runv("pkill", {"-f", "iproxy " .. settings.port .. "[: ]"}) end }
    end
    os.execv("sh", {"-c", string.format("nohup %s %s 22 -u %s > /tmp/iproxy-%s.log 2>&1 &", iproxy.program, settings.port, udid, settings.port)})
    os.sleep(3000)
end

local function askpass()
    local helper = path.join(os.tmpdir(), "revenant-askpass")
    if not os.isfile(helper) then
        local staged = helper .. "." .. os.getpid()
        io.writefile(staged, "#!/bin/sh\nprintf '%s\\n' \"$REVENANT_DEVICE_SECRET\"\n")
        os.runv("chmod", {"700", staged})
        os.mv(staged, helper)
    end
    return helper
end

local function authenticated(settings, program, argv)
    if settings.password == "" then
        return program, argv, nil
    end
    return program, table.join({"-o", "PubkeyAuthentication=no", "-o", "PreferredAuthentications=keyboard-interactive,password"}, argv),
           {SSH_ASKPASS = askpass(), SSH_ASKPASS_REQUIRE = "force", REVENANT_DEVICE_SECRET = settings.password}
end

function run(settings, command, opt)
    opt = opt or {}
    if command:find("killall", 1, true) then
        wprint("killing a VoIP application makes iOS 6 relaunch it and kill it again for holding a file lock (0xdead10cc); quit it from the switcher instead")
    end
    tunnel(settings)
    local program, argv, envs = authenticated(settings, "ssh", table.join(ssh_options, {"-p", settings.port, "root@" .. settings.host, command}))
    if opt.capture then
        return os.iorunv(program, argv, {envs = envs})
    end
    os.execv(program, argv, {envs = envs, try = opt.try})
end

function copy(settings, localfile, remote)
    tunnel(settings)
    local program, argv, envs = authenticated(settings, "scp", table.join(ssh_options, {"-P", settings.port, localfile, "root@" .. settings.host .. ":" .. remote}))
    os.execv(program, argv, {envs = envs})
end

function fetch(settings, remote, localfile)
    tunnel(settings)
    local program, argv, envs = authenticated(settings, "scp", table.join(ssh_options, {"-P", settings.port, "root@" .. settings.host .. ":" .. remote, localfile}))
    return try { function ()
        os.runv(program, argv, {envs = envs})
        return true
    end }
end

function reverse_tunnel(settings, port)
    tunnel(settings)
    local forwarded = {"-o", "ControlMaster=no", "-o", "ControlPath=none"}
    local program, argv, extra = authenticated(settings, "ssh", table.join(forwarded, ssh_options,
                                               {"-N", "-R", port .. ":127.0.0.1:" .. port, "-p", settings.port, "root@" .. settings.host}))
    local envs = {}
    for key, value in pairs(table.join(os.getenvs(), extra or {})) do
        table.insert(envs, key .. "=" .. value)
    end
    return process.openv(program, argv, {envs = envs})
end

function uninstall_command(packages, opt)
    for _, name in ipairs(packages) do
        if not name:match("^[%w%.%+%-]+$") then
            raise("%s is not a Debian package name", name)
        end
    end
    local removal = string.format("dpkg -r %s", table.concat(packages, " "))
    if opt and opt.keep then
        return removal
    end
    return removal .. [[ && while :; do
state=$(dpkg-query -W -f='${Package}|${Status}|${Depends}\n' 2>/dev/null | grep '|install ok installed|')
removed=
for p in $(echo "$state" | sed 's/|.*//' | grep -e '^org\.revenant\.libcxx-' -e '^org\.revenant\.swift-runtime-'); do
if ! echo "$state" | grep -q "$p ("; then dpkg -r $p && removed=1; fi
done
[ -z "$removed" ] && break
done]]
end

function identity_conflicts(settings, stage)
    import("apple.bundle")
    local conflicts = {}
    for _, plist in ipairs(os.files(path.join(stage, "Applications", "*.app", "Info.plist"))) do
        local packaged = bundle.read_plist(plist).CFBundleIdentifier
        local relative = path.relative(plist, stage)
        local fetched = os.tmpfile() .. ".plist"
        if fetch(settings, "/" .. relative, fetched) and os.isfile(fetched) then
            local installed = bundle.read_plist(fetched).CFBundleIdentifier
            os.rm(fetched)
            if installed ~= packaged then
                table.insert(conflicts, string.format("/%s on the phone is %s, and this package installs %s over it; SpringBoard would lose the app until a reboot, so remove the installed one first", path.directory(relative), tostring(installed), tostring(packaged)))
            end
        end
    end
    return conflicts
end

function log(settings, seconds, text)
    admitted(settings)
    local syslog = find_tool("idevicesyslog")
    if not syslog then
        raise("idevicesyslog is not installed; brew install libimobiledevice reads the phone's log over USB without Xcode")
    end
    local argv = {}
    if settings.udid ~= "" then
        table.join2(argv, {"-u", settings.udid})
    end
    if text and text ~= "" then
        table.join2(argv, {"-m", text})
    end
    os.execv("sh", {"-c", string.format("%s %s & reader=$!; sleep %d; kill $reader 2>/dev/null; wait $reader 2>/dev/null; true",
                                       syslog.program, os.args(argv), seconds)})
end
