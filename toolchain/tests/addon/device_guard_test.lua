import("fixtures")

function failures(opt)
    local device = import("device", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local refused = {
        "cd / && tar xzf /var/tmp/find-payload4.tgz",
        "cd / ; tar -xzf payload.tgz",
        "cd '/' && tar xzf payload.tgz",
        "cd /Applications && cd .. && tar xzf payload.tgz",
        "cd /Applications && tar xzf a.tgz && cd / && tar xzf b.tgz",
        "tar -xzf payload.tgz -C /",
        "tar --extract -f payload.tgz --directory=/",
        "cd / && rm -rf Applications",
        "rm -rf /Applications",
        "rm -rf /Applications/",
        "rm -rf /Applications/*",
        "rm -rf /Applications/*.app",
        "rm -rf /",
        "rm -rf /*",
        "rm -rf /usr"
    }
    local accepted = {
        "cd /Applications && tar xzf /var/tmp/FindDevice.app.tgz && rm -f /var/tmp/FindDevice.app.tgz",
        "tar -xzf payload.tgz -C /Applications",
        "tar czf out.tgz -C / Applications",
        "cd / && ls -la /Applications",
        "rm -rf /Applications/FindDevice.app",
        "cd /Applications && rm -rf FindDevice.app",
        "rm -rf /var/revenant/show /var/revenant/gesture",
        "rm -f /var/tmp/FindDevice.app.tgz"
    }
    for _, command in ipairs(refused) do
        if not device.refused_command(command) then
            table.insert(found, "device.run must refuse: " .. command)
        end
    end
    for _, command in ipairs(accepted) do
        local reason = device.refused_command(command)
        if reason then
            table.insert(found, "device.run must accept " .. command .. ", but it refuses: " .. reason)
        end
    end
    local settings = {host = "10.0.0.7", port = "22", password = "", udid = "abc123"}
    local errors = fixtures.refusal(function () device.run(settings, "cd / && tar xzf /var/tmp/payload.tgz") end)
    if not errors or not errors:find("cd /Applications && tar xzf", 1, true) then
        table.insert(found, "device.run must refuse a root extraction before it reaches the phone, naming the safe form: " .. tostring(errors))
    end
    errors = fixtures.refusal(function () device.run(settings, "rm -rf /Applications") end)
    if not errors or not errors:find("/Applications/<name>.app", 1, true) then
        table.insert(found, "device.run must refuse a wholesale /Applications removal, naming the one-app form: " .. tostring(errors))
    end
    local scratch = fixtures.scratch()
    local app = path.join(scratch, "Demo.app")
    os.mkdir(app)
    io.writefile(path.join(app, "Info.plist"), "<plist/>\n")
    local archive = path.join(scratch, "Demo.app.tgz")
    device.app_archive(app, archive)
    for entry in os.iorunv("tar", {"-tzf", archive}):gmatch("[^\n]+") do
        if not entry:startswith("Demo.app/") then
            table.insert(found, "an app archive must hold only the bundle, but it holds " .. entry)
        end
    end
    local provenance = os.iorunv("sh", {"-c", "gzip -dc " .. archive .. " | grep -a -c com.apple.provenance; true"}):trim()
    if provenance ~= "0" then
        table.insert(found, "an app archive must carry no provenance headers, found " .. provenance)
    end
    local install = device.app_install_command("Demo.app", "/var/root/revenant-scratch/guard-a/Demo.app.tgz")
    if device.refused_command(install) then
        table.insert(found, "a single named app must install through the guard")
    end
    if not install:find("; status=$?; rm -f /var/root/revenant-scratch/guard-a/Demo.app.tgz; [ $status -eq 0 ]", 1, true) then
        table.insert(found, "the archive of an app must be removed whether or not tar succeeded: " .. install)
    end
    local holder = os.getenv("REVENANT_DEVICE_HOLDER")
    os.setenv("REVENANT_DEVICE_HOLDER", "guard-a")
    if device.staging() ~= "/var/root/revenant-scratch/guard-a" then
        table.insert(found, "files staged on the phone must go to the folder of the holder, not " .. tostring(device.staging()))
    end
    os.setenv("REVENANT_DEVICE_HOLDER", "")
    if device.staging() ~= "/var/root/revenant-scratch/unclaimed" then
        table.insert(found, "files staged without a holder must go to the unclaimed folder, not " .. tostring(device.staging()))
    end
    os.setenv("REVENANT_DEVICE_HOLDER", holder)
    errors = fixtures.refusal(function () device.install_app(settings, path.join(scratch, "Demo")) end)
    if not errors or not errors:find("install_app takes one Name.app directory", 1, true) then
        table.insert(found, "install_app must refuse a path that is not a Name.app directory: " .. tostring(errors))
    end
    os.tryrm(scratch)
    return found
end
