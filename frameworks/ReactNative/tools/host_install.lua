local USAGE = [[usage: ./xmakew l -P . frameworks/ReactNative/tools/host_install.lua stage --app BUILT.app --backports DIR --manifest DIR --output DIR
       ./xmakew l -P . frameworks/ReactNative/tools/host_install.lua deploy --archive FILE --bundle-id ID [--bundle FILE] [--conf KEY=VALUE,...]
       ./xmakew l -P . frameworks/ReactNative/tools/host_install.lua launch --bundle-id ID
  stage   makes DIR/<app name>.app and DIR/host.tgz from a built host: it adds the manifest folder (EXConstants.bundle from app_config.lua),
          the backports libraries in DIR of --backports, retargets the library references from /usr/lib/revenant/org.revenant.backports
          to @executable_path/Frameworks, and signs every Mach-O file with ldid.
  deploy  installs the archive on the claimed phone as /var/stash/<claim holder>/<last part of the id>/<last part of the id>.app, linked
          from /Applications, registers it and, with --bundle, puts the JavaScript bundle at <that .app>/bundle.js and writes
          <that .app>/rnhost.conf with module=main and bundle=bundle.js (--conf adds lines: only module, bundle, engine and JSC_* keys).
          Both files are root-owned and read-only for everything else, which is what the host checks before it reads them. The
          host's output goes to /var/tmp/<last part of the id>/, a folder of the app's user. It removes nothing of another bundle id.
  launch  wakes the phone and has SpringBoard start the app of the id.]]

local LIBRARIES = {"libFoundationBackports", "libCoreTextBackports", "libUIKitBackports", "libUserNotificationsBackports", "libCoreGraphicsBackports",
                   "libGraphicsBackports", "libCoreFoundationBackports", "libSystemBackports", "libIOSurfaceBackports", "libWebKitBackports"}
local OLD_PREFIX = "/usr/lib/revenant/org.revenant.backports"
local NEW_PREFIX = "@executable_path/Frameworks"
local CONF_KEYS = {module = true, bundle = true, engine = true}
local CONF_BUNDLE = "bundle.js"

function app_name(bundle_id)
    return bundle_id:match("([^%.]+)$")
end

function stash_folder(holder, bundle_id)
    return "/var/stash/" .. holder .. "/" .. app_name(bundle_id)
end

function app_folder(holder, bundle_id)
    return stash_folder(holder, bundle_id) .. "/" .. app_name(bundle_id) .. ".app"
end

function run_folder(bundle_id)
    return "/var/tmp/" .. app_name(bundle_id)
end

function change_arguments(otool_text, library_names)
    local arguments = {}
    for _, name in ipairs(library_names) do
        local old = OLD_PREFIX .. "/" .. name .. ".dylib"
        if otool_text:find(old .. " ", 1, true) then
            table.insert(arguments, "-change")
            table.insert(arguments, old)
            table.insert(arguments, NEW_PREFIX .. "/" .. name .. ".dylib")
        end
    end
    return arguments
end

function install_command(holder, bundle_id)
    local stash = stash_folder(holder, bundle_id)
    local name = app_name(bundle_id)
    local app = name .. ".app"
    return table.concat({
        "mkdir -p " .. stash,
        "rm -rf " .. stash .. "/" .. app .. " /Applications/" .. app,
        "cd " .. stash,
        "rm -rf unpack",
        "mkdir unpack",
        "tar xzf /var/tmp/" .. name .. ".tgz -C unpack 2>/dev/null",
        "rm /var/tmp/" .. name .. ".tgz",
        "mv unpack/*.app " .. app,
        "rmdir unpack",
        "chmod -R 755 " .. app,
        "ln -s " .. stash .. "/" .. app .. " /Applications/" .. app,
        "su mobile -c 'uicache -p /Applications/" .. app .. "'"
    }, " && ")
end

function conf_text(bundle_name, extra)
    local lines = {"module=main", "bundle=" .. bundle_name}
    for line in (extra or ""):gmatch("[^,]+") do
        local key = line:match("^([^=]+)=")
        if not key or not (CONF_KEYS[key] or key:sub(1, 4) == "JSC_") then
            raise("--conf key %s is not read by the host: only module, bundle, engine and JSC_* keys", line)
        end
        table.insert(lines, line)
    end
    return table.concat(lines, "\n") .. "\n"
end

function phone()
    local device = import("@addon.revenant.device", {anonymous = true})
    local settings = device.bind(os.curdir())
    local holder = device.holder_name()
    local lease = settings.udid ~= "" and device.lease(settings.udid)
    if not holder or not lease or lease.holder ~= holder then
        raise("the phone is not claimed by %s: claim it first and export REVENANT_DEVICE_HOLDER", holder or "anyone (REVENANT_DEVICE_HOLDER is unset)")
    end
    return device, settings, holder
end

function stage(options)
    for _, key in ipairs({"app", "backports", "manifest", "output"}) do
        if not options[key] then
            raise("stage needs --%s", key)
        end
    end
    local built = path.absolute(options.app)
    local output = path.absolute(options.output)
    local target = path.join(output, path.filename(built))
    os.tryrm(output)
    os.mkdir(output)
    os.vrunv("cp", {"-cR", built, target})
    os.vrunv("cp", {"-R", path.join(path.absolute(options.manifest), "EXConstants.bundle"), target .. "/"})
    local ldid = os.iorunv("sh", {"-c", "ls \"$1\"/xmake-global/.xmake/packages/l/ldid/*/*/bin/ldid | head -1", "sh", os.getenv("REVENANT_CACHE") or ""}):trim()
    local frameworks = path.join(target, "Frameworks")
    os.mkdir(frameworks)
    for _, name in ipairs(LIBRARIES) do
        local library = path.join(frameworks, name .. ".dylib")
        os.vrunv("cp", {path.join(path.absolute(options.backports), name .. ".dylib"), library})
        os.vrunv("chmod", {"755", library})
        os.vrunv("install_name_tool", {"-id", NEW_PREFIX .. "/" .. name .. ".dylib", library})
    end
    local files = {path.join(target, path.basename(built))}
    for _, name in ipairs(LIBRARIES) do
        table.insert(files, path.join(frameworks, name .. ".dylib"))
    end
    for _, file in ipairs(files) do
        local arguments = change_arguments(os.iorunv("otool", {"-L", file}), LIBRARIES)
        if #arguments > 0 then
            table.insert(arguments, file)
            os.vrunv("install_name_tool", arguments)
        end
    end
    local engine = path.join(frameworks, "JavaScriptCore.framework", "JavaScriptCore")
    if os.isfile(engine) then
        table.insert(files, engine)
    end
    if ldid ~= "" then
        for _, file in ipairs(files) do
            os.vrunv(ldid, {"-S", file})
        end
    end
    local archive = path.join(output, "host.tgz")
    os.execv("tar", {"czf", archive, "-C", output, path.filename(built)}, {envs = {COPYFILE_DISABLE = "1"}})
    print("wrote " .. archive)
end

function deploy(options)
    if not (options.archive and options["bundle-id"]) then
        raise("deploy needs \"--archive\" and \"--bundle-id\"")
    end
    local device, settings, holder = phone()
    local id = options["bundle-id"]
    local name = app_name(id)
    local app = app_folder(holder, id)
    device.copy(settings, path.absolute(options.archive), "/var/tmp/" .. name .. ".tgz")
    device.run(settings, install_command(holder, id))
    local output = run_folder(id)
    device.run(settings, "mkdir -p " .. output .. " && chown mobile " .. output .. " && chmod 700 " .. output)
    if options.bundle then
        local conf = os.tmpfile()
        io.writefile(conf, conf_text(CONF_BUNDLE, options.conf))
        device.copy(settings, path.absolute(options.bundle), app .. "/" .. CONF_BUNDLE)
        device.copy(settings, conf, app .. "/rnhost.conf")
        os.rm(conf)
        device.run(settings, "chown root:wheel " .. app .. "/" .. CONF_BUNDLE .. " " .. app .. "/rnhost.conf && chmod 644 " .. app .. "/" .. CONF_BUNDLE .. " " .. app .. "/rnhost.conf")
    end
    print("installed " .. id .. " as " .. app)
end

function launch(options)
    if not options["bundle-id"] then
        raise("launch needs --bundle-id")
    end
    local device, settings = phone()
    device.run(settings, "/usr/libexec/revenant-sblaunch " .. options["bundle-id"])
end

function main(...)
    local shared = import("@addon.revenant.member", {anonymous = true})
    local options, words = shared.arguments({...}, {app = "value", backports = "value", manifest = "value", output = "value", archive = "value",
                                                    ["bundle-id"] = "value", bundle = "value", conf = "value", help = "switch"})
    local command = words[1]
    if options.help then
        print(USAGE)
    elseif command == "stage" then
        stage(options)
    elseif command == "deploy" then
        deploy(options)
    elseif command == "launch" then
        launch(options)
    else
        print(USAGE)
    end
end
