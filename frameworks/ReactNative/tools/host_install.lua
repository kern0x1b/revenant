local USAGE = [[usage: ./xmakew l -P . frameworks/ReactNative/tools/host_install.lua stage --app BUILT.app --backports DIR|STORE [--key BUILDHASH] --manifest DIR --output DIR [--bundle-id ID]
       ./xmakew l -P . frameworks/ReactNative/tools/host_install.lua stage --app BUILT.app --packages DIR[,DIR...] --manifest DIR --output DIR [--bundle-id ID]
       ./xmakew l -P . frameworks/ReactNative/tools/host_install.lua deploy --archive FILE --bundle-id ID [--bundle FILE] [--conf KEY=VALUE,...] [--packages FILE] [--provided NAME]
       ./xmakew l -P . frameworks/ReactNative/tools/host_install.lua launch --bundle-id ID [--dyld FOLDER]
       ./xmakew l -P . frameworks/ReactNative/tools/host_install.lua stop --bundle-id ID
       ./xmakew l -P . frameworks/ReactNative/tools/host_install.lua diagnostics --bundle-id ID [--output DIR]
  stage  makes DIR/<app name>.app and DIR/host.tgz from a built host: it adds the manifest folder (EXConstants.bundle from app_config.lua),
          the backports libraries in DIR of --backports (with --key, the generation of that store which the key names; no other
          generation is picked), refusing a built host that loads a library DIR lacks and naming each one, retargets the library references from /usr/lib/revenant/org.revenant.backports
          to @executable_path/Frameworks, and signs every Mach-O file with ldid. With --bundle-id it refuses a built app whose
          CFBundleIdentifier is another id (rebuild it from a copy made with isolate.lua copy --bundle-id), and it renames the
          executable to RNHost-<last part of the id> (and CFBundleExecutable with it), so that no two installed hosts share a process name.
          Without --backports the host takes its libraries from the shared packages the phone holds: stage carries no Frameworks, refuses a host that loads
          a library from its own Frameworks, and writes OUT/host-packages.json, each package folder under /usr/lib/revenant that the host loads with the
          version the build's description in --packages (the share/shared-packages folders of the packages it was linked against) names.
  deploy  installs the archive on the claimed phone as /var/stash/<claim holder>/<last part of the id>/<last part of the id>.app, linked
          from /Applications, registers it and, with --bundle, puts the JavaScript bundle at <that .app>/bundle.js and writes
          <that .app>/rnhost.conf with module=main and bundle=bundle.js (--conf adds lines: only module, bundle, engine and JSC_* keys).
          Both files are root-owned and read-only for everything else, which is what the host checks before it reads them. The
          host's output goes to /var/tmp/<last part of the id>/, a folder of the app's user. With --packages FILE (the host-packages.json of
          a shared stage) it first asks the phone for the version of each package and stops, naming it, when one is missing or another version; --provided names the packages that a launch with DYLD_LIBRARY_PATH supplies instead, which are not checked. It removes nothing of another bundle id.
  launch  wakes the phone and has SpringBoard start the app of the id. With --dyld FOLDER (a folder of the phone) the start sets DYLD_LIBRARY_PATH to it, so
          the libraries of that folder are loaded by file name before the installed ones; only that start sees them, not one from the home screen.
  stop    ends the running process of the app of the id and of no other id: it finds the process by the launchd label of the app.
  diagnostics  copies what the phone keeps of the app of the id into DIR (build/diagnostics/<last part of the id> by default): the app's
          version, the iOS version, the launchd state, the crash reports of RNHost-<last part of the id> (in crash/), the host's
          rnhost.log and a screenshot (screen.png), with a summary in diagnostics.txt. It changes nothing on the phone except one
          screenshot file in /tmp.]]

LIBRARIES = {"libFoundationBackports", "libCoreTextBackports", "libUIKitBackports", "libUserNotificationsBackports", "libCoreGraphicsBackports",
             "libGraphicsBackports", "libCoreFoundationBackports", "libSystemBackports", "libIOSurfaceBackports", "libWebKitBackports", "libMapKitBackports",
             "libCoreLocationBackports", "libSecurityBackports", "libContactsBackports", "libLocalAuthenticationBackports", "libTLSBackports"}

local BACKPORTS_SUBDIR = path.join("share", "root", "usr", "lib", "revenant", "org.revenant.backports")

function backports_generation(store, key)
    if not key:match("^%x+$") then
        raise("--key must be the buildhash of the backports package, in hexadecimal, not %s", key)
    end
    local generation = path.join(path.absolute(store), key)
    if not os.isdir(generation) then
        raise("%s holds no generation for key %s", store, key)
    end
    return path.join(generation, BACKPORTS_SUBDIR)
end

function backports_libraries(folder)
    if not folder then
        return LIBRARIES
    end
    local directory = path.absolute(folder)
    local found = {}
    for _, file in ipairs(os.files(path.join(directory, "lib*Backports.dylib"))) do
        table.insert(found, path.basename(file))
    end
    if #found == 0 then
        raise("no lib*Backports.dylib in %s, so the host would carry no backports library", folder)
    end
    table.sort(found)
    return found
end

function missing_backports(otool_text, libraries)
    local have, missing = {}, {}
    for _, name in ipairs(libraries) do
        have[name] = true
    end
    for line in otool_text:gmatch("[^\n]+") do
        local name = line:find("/usr/lib/revenant/org.revenant.backports/", 1, true) and line:match("org%.revenant%.backports/([^/%s]+)%.dylib")
        if name and not have[name] and not table.contains(missing, name) then
            table.insert(missing, name)
        end
    end
    return missing
end

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

function executable_name(bundle_id)
    return "RNHost-" .. app_name(bundle_id)
end

function bundle_identifier_error(built_id, bundle_id)
    if built_id == bundle_id then
        return nil
    end
    return string.format("the built app's CFBundleIdentifier is %s, not %s: rebuild it from a copy made with isolate.lua copy --bundle-id %s", built_id, bundle_id, bundle_id)
end

function stop_command(bundle_id)
    return "set -- $(launchctl list | grep 'UIKitApplication:" .. bundle_id .. "\\['); if [ -n \"$1\" ] && [ \"$1\" != - ]; then kill $1; echo stopped $1; else echo not running; fi"
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

function framework_retargets(otool_text, imports_text, exports, library_names)
    local sdk = "/System/Library/Frameworks/"
    local imports = {}
    local seen = {}
    for line in imports_text:gmatch("[^\n]+") do
        local symbol, framework = line:match("(_%S+) %(from ([^)]+)%)")
        if symbol then
            seen[framework] = seen[framework] or {}
            if not seen[framework][symbol] then
                seen[framework][symbol] = true
                imports[framework] = imports[framework] or {}
                table.insert(imports[framework], symbol)
            end
        end
    end
    local absent = {UserNotifications = true, Contacts = true, LocalAuthentication = true}
    local arguments, notes = {}, {}
    for _, name in ipairs(library_names) do
        local framework = name:match("^lib(.+)Backports$")
        local old = framework and sdk .. framework .. ".framework/" .. framework
        if old and absent[framework] and imports[framework] and otool_text:find(old .. " ", 1, true) then
            local defined = {}
            for line in (exports[name] or ""):gmatch("[^\n]+") do
                defined[line:match("(%S+)$")] = true
            end
            local missing = {}
            for _, symbol in ipairs(imports[framework]) do
                if not defined[symbol] then
                    table.insert(missing, symbol)
                end
            end
            if #missing == 0 then
                table.insert(arguments, "-change")
                table.insert(arguments, old)
                table.insert(arguments, NEW_PREFIX .. "/" .. name .. ".dylib")
            else
                table.insert(notes, string.format("%s stays on the device's framework: %s does not export %d of the %d symbols the host imports from it, e.g. %s",
                    framework, name, #missing, #imports[framework], missing[1]))
            end
        end
    end
    return arguments, notes
end

function duplicate_install_names(otool_text)
    local count, duplicates = {}, {}
    for line in otool_text:gmatch("[^\n]+") do
        local name = line:match("^%s+(%S+) %(")
        if name then
            count[name] = (count[name] or 0) + 1
            if count[name] == 2 then
                table.insert(duplicates, name)
            end
        end
    end
    return duplicates
end

function check_install_names(file, otool_text)
    local duplicates = duplicate_install_names(otool_text)
    if #duplicates > 0 then
        raise("%s has two load commands for %s after the retarget, so dyld would load that library twice: link each backports library once in src/host/xmake.lua (a framework the device lacks is linked only by its weak SDK import, which the retarget renames)",
            file, table.concat(duplicates, ", "))
    end
end

local LC_ID_DYLIB = 0x0D
local DYLIB_LOAD_COMMANDS = {[0x0C] = true, [0x1F] = true, [0x23] = true, [0x80000018] = true}

function word_at(data, position)
    local a, b, c, d = data:byte(position, position + 3)
    return a + b * 256 + c * 65536 + d * 16777216
end

function word_bytes(value)
    return string.char(value % 256, math.floor(value / 256) % 256, math.floor(value / 65536) % 256, math.floor(value / 16777216) % 256)
end

function version_text(value)
    return string.format("%d.%d.%d", math.floor(value / 65536), math.floor(value / 256) % 256, value % 256)
end

function dylib_records(data)
    if word_at(data, 1) ~= 0xFEEDFACE then
        raise("the file is not a 32-bit little-endian Mach-O")
    end
    local records = {}
    local position = 29
    for _ = 1, word_at(data, 17) do
        local command = word_at(data, position)
        if command == LC_ID_DYLIB or DYLIB_LOAD_COMMANDS[command] then
            local start = position + word_at(data, position + 8)
            table.insert(records, {
                id = command == LC_ID_DYLIB,
                name = data:sub(start, data:find("\0", start, true) - 1),
                current = word_at(data, position + 16),
                compatibility = word_at(data, position + 20),
                current_at = position + 16,
                compatibility_at = position + 20,
            })
        end
        position = position + word_at(data, position + 4)
    end
    return records
end

function image_versions(data)
    for _, record in ipairs(dylib_records(data)) do
        if record.id then
            return {current = record.current, compatibility = record.compatibility}
        end
    end
    return nil
end

function version_fixes(data, images)
    local fixes = {}
    for _, record in ipairs(dylib_records(data)) do
        local image = not record.id and images[record.name]
        if image then
            if record.current ~= image.current then
                table.insert(fixes, {position = record.current_at, value = image.current})
            end
            if record.compatibility ~= image.compatibility then
                table.insert(fixes, {position = record.compatibility_at, value = image.compatibility})
            end
        end
    end
    return fixes
end

function apply_version_fixes(data, fixes)
    table.sort(fixes, function (a, b) return a.position < b.position end)
    local pieces, last = {}, 1
    for _, fix in ipairs(fixes) do
        table.insert(pieces, data:sub(last, fix.position - 1))
        table.insert(pieces, word_bytes(fix.value))
        last = fix.position + 4
    end
    table.insert(pieces, data:sub(last))
    return table.concat(pieces)
end

function check_load_versions(file, data, images)
    for _, record in ipairs(dylib_records(data)) do
        local image = not record.id and images[record.name]
        if image and record.compatibility > image.current then
            raise("%s loads %s with compatibility version %s, above that library's current version %s: dyld refuses such a library, so its symbols would not resolve",
                file, record.name, version_text(record.compatibility), version_text(image.current))
        end
    end
end

function check_dependent_versions(file, data, images)
    for _, record in ipairs(dylib_records(data)) do
        local backports = not record.id and (record.name:startswith(OLD_PREFIX .. "/") or record.name:startswith(NEW_PREFIX .. "/"))
        local image = backports and images[NEW_PREFIX .. "/" .. path.filename(record.name)]
        if image and record.compatibility > image.current then
            raise("%s requires %s with compatibility version %s or later, but the bundled library has version %s: dyld refuses such a library, so the application would not start; link that library against the Backports library with a compatibility version not above its current one",
                file, path.filename(record.name), version_text(record.compatibility), version_text(image.current))
        end
    end
end

function signing_arguments(entitlements, index, file)
    if index == 1 then
        return {"-S" .. entitlements, file}
    end
    return {"-S", file}
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
        "chown -R root:wheel " .. app,
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

function shared_packages(otool_text, store)
    local names, found = {}, {}
    for line in otool_text:gmatch("[^\n]+") do
        local name = line:match("^%s+/usr/lib/revenant/([^/%s]+)/")
        if name and not names[name] then
            names[name] = true
            table.insert(found, name)
        end
    end
    table.sort(found)
    local packages = {}
    for _, name in ipairs(found) do
        local description
        for _, folder in ipairs(store) do
            local candidate = path.join(path.absolute(folder), name .. ".json")
            if os.isfile(candidate) then
                description = import("core.base.json").loadfile(candidate)
                break
            end
        end
        if not description then
            raise("the host loads a library of the package %s, and no folder of --packages holds %s.json: name the shared-packages folder of the build that links it", name, name)
        end
        table.insert(packages, {name = name, version = description.version})
    end
    return packages
end

function version_mismatches(packages, installed, provided)
    local problems = {}
    for _, package in ipairs(packages) do
        local held = installed[package.name]
        if provided and provided[package.name] then
        elseif not held or held == "" then
            table.insert(problems, string.format("%s %s is not installed on the phone", package.name, package.version))
        elseif held ~= package.version then
            table.insert(problems, string.format("%s is %s on the phone, and the host is linked against %s", package.name, held, package.version))
        end
    end
    return problems
end

local function stage_shared(options)
    local built = path.absolute(options.app)
    local binary = path.join(built, path.basename(built))
    local otool = os.iorunv("otool", {"-L", binary})
    if otool:find("@executable_path/Frameworks/", 1, true) then
        raise("%s loads a library from its own Frameworks folder, and without --backports stage keeps no Frameworks: a host that carries libraries is staged with --backports", built)
    end
    local packages = shared_packages(otool, string.split(options.packages or "", ",", {plain = true}))
    if #packages == 0 then
        raise("%s loads no library of a shared package, so there is nothing for the phone to hold: stage it with --backports", built)
    end
    local output = path.absolute(options.output)
    local target = path.join(output, path.filename(built))
    os.tryrm(output)
    os.mkdir(output)
    os.vrunv("cp", {"-cR", built, target})
    os.vrunv("cp", {"-R", path.join(path.absolute(options.manifest), "EXConstants.bundle"), target .. "/"})
    local executable = path.basename(built)
    if options["bundle-id"] then
        executable = executable_name(options["bundle-id"])
        os.vrunv("mv", {path.join(target, path.basename(built)), path.join(target, executable)})
        os.vrunv("plutil", {"-replace", "CFBundleExecutable", "-string", executable, path.join(target, "Info.plist")})
    end
    local ldid = os.iorunv("sh", {"-c", "ls \"$1\"/xmake-global/.xmake/packages/l/ldid/*/*/bin/ldid | head -1", "sh", os.getenv("REVENANT_CACHE") or ""}):trim()
    if ldid ~= "" then
        os.vrunv(ldid, signing_arguments(path.join(os.scriptdir(), "data", "rnhost.entitlements"), 1, path.join(target, executable)))
    end
    import("core.base.json").savefile(path.join(output, "host-packages.json"), {packages = packages})
    local archive = path.join(output, "host.tgz")
    os.execv("tar", {"czf", archive, "-C", output, path.filename(built)}, {envs = {COPYFILE_DISABLE = "1"}})
    print("wrote " .. archive .. " and " .. path.join(output, "host-packages.json"))
end

function stage(options)
    for _, key in ipairs({"app", "manifest", "output"}) do
        if not options[key] then
            raise("stage needs --%s", key)
        end
    end
    if options["bundle-id"] then
        local identifier = os.iorunv("plutil", {"-extract", "CFBundleIdentifier", "raw", "-o", "-", path.join(path.absolute(options.app), "Info.plist")}):trim()
        local problem = bundle_identifier_error(identifier, options["bundle-id"])
        if problem then
            raise(problem)
        end
    end
    if not options.backports then
        return stage_shared(options)
    end
    local built = path.absolute(options.app)
    if options["bundle-id"] then
        local identifier = os.iorunv("plutil", {"-extract", "CFBundleIdentifier", "raw", "-o", "-", path.join(built, "Info.plist")}):trim()
        local problem = bundle_identifier_error(identifier, options["bundle-id"])
        if problem then
            raise(problem)
        end
    end
    local backports_folder = options.key and backports_generation(options.backports, options.key) or options.backports
    local libraries = backports_libraries(backports_folder)
    local lacking = missing_backports(os.iorunv("otool", {"-L", path.join(built, path.basename(built))}), libraries)
    if #lacking > 0 then
        raise("%s loads Backports libraries that %s does not carry: %s, so the device would load its own copies", built, backports_folder, table.concat(lacking, ", "))
    end
    local output = path.absolute(options.output)
    local target = path.join(output, path.filename(built))
    os.tryrm(output)
    os.mkdir(output)
    os.vrunv("cp", {"-cR", built, target})
    os.vrunv("cp", {"-R", path.join(path.absolute(options.manifest), "EXConstants.bundle"), target .. "/"})
    local ldid = os.iorunv("sh", {"-c", "ls \"$1\"/xmake-global/.xmake/packages/l/ldid/*/*/bin/ldid | head -1", "sh", os.getenv("REVENANT_CACHE") or ""}):trim()
    local frameworks = path.join(target, "Frameworks")
    os.mkdir(frameworks)
    for _, name in ipairs(libraries) do
        local library = path.join(frameworks, name .. ".dylib")
        os.vrunv("cp", {path.join(path.absolute(backports_folder), name .. ".dylib"), library})
        os.vrunv("chmod", {"755", library})
        os.vrunv("install_name_tool", {"-id", NEW_PREFIX .. "/" .. name .. ".dylib", library})
    end
    local executable = path.basename(built)
    if options["bundle-id"] then
        executable = executable_name(options["bundle-id"])
        os.vrunv("mv", {path.join(target, path.basename(built)), path.join(target, executable)})
        os.vrunv("plutil", {"-replace", "CFBundleExecutable", "-string", executable, path.join(target, "Info.plist")})
    end
    local files = {path.join(target, executable)}
    for _, name in ipairs(libraries) do
        table.insert(files, path.join(frameworks, name .. ".dylib"))
    end
    local engine = path.join(frameworks, "JavaScriptCore.framework", "JavaScriptCore")
    if os.isfile(engine) then
        table.insert(files, engine)
    end
    for _, file in ipairs(files) do
        local arguments = change_arguments(os.iorunv("otool", {"-L", file}), libraries)
        if #arguments > 0 then
            table.insert(arguments, file)
            os.vrunv("install_name_tool", arguments)
        end
    end
    local exports = {}
    for _, name in ipairs(libraries) do
        exports[name] = os.iorunv("nm", {"-gU", "-arch", "armv7", path.join(frameworks, name .. ".dylib")})
    end
    local retargets, notes = framework_retargets(os.iorunv("otool", {"-L", files[1]}), os.iorunv("nm", {"-m", "-arch", "armv7", files[1]}), exports, libraries)
    for _, note in ipairs(notes) do
        print(note)
    end
    if #retargets > 0 then
        table.insert(retargets, files[1])
        os.vrunv("install_name_tool", retargets)
    end
    local images = {}
    for index = 2, #files do
        local versions = image_versions(io.readfile(files[index], {encoding = "binary"}))
        if versions then
            images["@executable_path/" .. path.relative(files[index], target)] = versions
        end
    end
    for _, file in ipairs(files) do
        local otool = os.iorunv("otool", {"-L", file})
        if otool:find(OLD_PREFIX, 1, true) then
            raise("%s still loads a backports library from %s: the library is not in LIBRARIES, so the device would load its own copy", file, OLD_PREFIX)
        end
        check_install_names(file, otool)
        local data = io.readfile(file, {encoding = "binary"})
        local fixes = version_fixes(data, images)
        if #fixes > 0 then
            data = apply_version_fixes(data, fixes)
            io.writefile(file, data, {encoding = "binary"})
        end
        check_load_versions(file, data, images)
    end
    for _, file in ipairs(os.files(path.join(frameworks, "libswift*.dylib"))) do
        check_dependent_versions(file, io.readfile(file, {encoding = "binary"}), images)
    end
    if ldid ~= "" then
        local entitlements = path.join(os.scriptdir(), "data", "rnhost.entitlements")
        for index, file in ipairs(files) do
            os.vrunv(ldid, signing_arguments(entitlements, index, file))
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
    if options.packages then
        local packages = import("core.base.json").loadfile(path.absolute(options.packages)).packages
        local installed, provided = {}, {}
        for _, name in ipairs(string.split(options.provided or "", ",", {plain = true})) do
            provided[name] = true
        end
        for _, package in ipairs(packages) do
            installed[package.name] = device.run(settings, "dpkg-query -W -f='${Version}' " .. package.name .. " 2>/dev/null ; true", {capture = true}):trim()
        end
        local problems = version_mismatches(packages, installed, provided)
        if #problems > 0 then
            raise("the phone does not hold the packages this host is linked against:\n  %s", table.concat(problems, "\n  "))
        end
    end
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

function launch_command(bundle_id, dyld)
    if not dyld then
        return "/usr/libexec/revenant-sblaunch " .. bundle_id
    end
    if not dyld:match("^/[%w%._/%-]+$") or dyld:find("..", 1, true) then
        raise("--dyld takes an absolute folder of the phone without spaces or .., not %s", dyld)
    end
    return "/usr/libexec/revenant-sblaunch --wait 10 --env DYLD_LIBRARY_PATH=" .. dyld .. " " .. bundle_id
end

function launch(options)
    if not options["bundle-id"] then
        raise("launch needs --bundle-id")
    end
    local device, settings = phone()
    device.run(settings, launch_command(options["bundle-id"], options.dyld))
end

function stop(options)
    if not options["bundle-id"] then
        raise("stop needs \"--bundle-id\"")
    end
    local device, settings = phone()
    device.run(settings, stop_command(options["bundle-id"]))
end

local CRASH_FOLDER = "/var/mobile/Library/Logs/CrashReporter"
local SYSTEM_VERSION = "/System/Library/CoreServices/SystemVersion.plist"

function plist_value(file, key)
    return try { function () return os.iorunv("plutil", {"-extract", key, "raw", "-o", "-", file}):trim() end }
end

function crash_reports(listing, executable)
    local names = {}
    for line in (listing or ""):gmatch("[^\n]+") do
        local name = line:trim()
        local after = name:sub(#executable + 1, #executable + 1)
        if name:sub(1, #executable) == executable and (after == "_" or after == ".") and (name:endswith(".crash") or name:endswith(".plist") or name:endswith(".ips")) then
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names
end

function screenshot_remote(name)
    return "/tmp/diagnostics-" .. name .. ".png"
end

function screenshot_removal(remote)
    if not remote:match("^/tmp/diagnostics%-[^/]+%.png$") then
        raise("%s is not a diagnostics screenshot, so it is not removed", remote)
    end
    return "rm -f " .. remote
end

function diagnostics(options)
    if not options["bundle-id"] then
        raise("diagnostics needs \"--bundle-id\"")
    end
    local device, settings, holder = phone()
    local id = options["bundle-id"]
    local output = path.absolute(options.output or path.join("build", "diagnostics", app_name(id)))
    os.mkdir(path.join(output, "crash"))
    local lines = {}
    local function fetch(remote, file)
        local local_file = path.join(output, file)
        if device.fetch(settings, remote, local_file) then
            return local_file
        end
        table.insert(lines, "missing " .. remote)
    end
    local info = fetch(app_folder(holder, id) .. "/Info.plist", "app-Info.plist")
    if info then
        table.insert(lines, "bundle " .. (plist_value(info, "CFBundleIdentifier") or "?"))
        table.insert(lines, "app version " .. (plist_value(info, "CFBundleShortVersionString") or "?") .. " build " .. (plist_value(info, "CFBundleVersion") or "?"))
    end
    local system = fetch(SYSTEM_VERSION, "system-version.plist")
    if system then
        table.insert(lines, "ios " .. (plist_value(system, "ProductVersion") or "?") .. " build " .. (plist_value(system, "ProductBuildVersion") or "?"))
    end
    local state = device.run(settings, "launchctl list | grep 'UIKitApplication:" .. id .. "\\[' ; true", {capture = true}):trim()
    table.insert(lines, "launchctl " .. (state ~= "" and state or "not running"))
    local listing = device.run(settings, "ls -1 " .. CRASH_FOLDER .. " 2>/dev/null ; true", {capture = true})
    local reports = crash_reports(listing, executable_name(id))
    table.insert(lines, #reports .. " crash reports of " .. executable_name(id))
    for _, report in ipairs(reports) do
        fetch(path.join(CRASH_FOLDER, report), path.join("crash", report))
    end
    fetch(run_folder(id) .. "/rnhost.log", "rnhost.log")
    local shot = screenshot_remote(app_name(id))
    if try { function () device.run(settings, "/usr/libexec/revenant-shot " .. shot); return true end } then
        fetch(shot, "screen.png")
    else
        table.insert(lines, "no screenshot: revenant-shot failed")
    end
    if not try { function () device.run(settings, screenshot_removal(shot)); return true end } then
        table.insert(lines, "the screenshot " .. shot .. " is still on the phone")
    end
    io.writefile(path.join(output, "diagnostics.txt"), table.concat(lines, "\n") .. "\n")
    print("diagnostics of " .. id .. " in " .. output)
end

function main(...)
    local shared = import("@addon.revenant.member", {anonymous = true})
    local options, words = shared.arguments({...}, {app = "value", backports = "value", packages = "value", provided = "value", dyld = "value", key = "value", manifest = "value", output = "value", archive = "value",
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
    elseif command == "stop" then
        stop(options)
    elseif command == "diagnostics" then
        diagnostics(options)
    else
        print(USAGE)
    end
end
