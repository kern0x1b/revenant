function failures(opt)
    local root = path.join(path.directory(opt.modules), "..")
    local install = import("host_install", {rootdir = path.join(root, "frameworks", "ReactNative", "tools"), anonymous = true})
    local found = {}

    if install.app_name("org.revenant.rnhost.hermes") ~= "hermes" or install.app_name("plain") ~= "plain" then
        table.insert(found, "the app is named by the last part of its bundle id")
    end
    if install.stash_folder("rn-hermes", "org.revenant.rnhost.hermes") ~= "/var/stash/rn-hermes/hermes" or install.run_folder("org.revenant.rnhost.iso") ~= "/var/tmp/iso" then
        table.insert(found, "an app lives in its holder's stash folder and writes its output to a folder of its own name")
    end
    if install.app_folder("rn-hermes", "org.revenant.rnhost.hermes") ~= "/var/stash/rn-hermes/hermes/hermes.app" then
        table.insert(found, "the configuration and the bundle live inside the app folder, not in /var/tmp")
    end

    if install.executable_name("org.revenant.rnhost.iso") ~= "RNHost-iso" or install.executable_name("org.revenant.rnhost.hermes") == install.executable_name("org.revenant.rnhost.iso") then
        table.insert(found, "two hosts must not share an executable name")
    end
    local stop = install.stop_command("org.revenant.rnhost.iso")
    if not stop:find("UIKitApplication:org.revenant.rnhost.iso\\[", 1, true) or not stop:find("kill $1", 1, true) or stop:find("killall", 1, true) then
        table.insert(found, "stop must end the process of its own launchd label and never use killall: " .. stop)
    end

    local listing ="RNHost:\n\t/usr/lib/revenant/org.revenant.backports/libUIKitBackports.dylib (compatibility version 1.0.0)\n\t/usr/lib/revenant/org.revenant.backports/libSystemBackports.dylib (compatibility version 1.0.0)\n\t/usr/lib/libSystem.B.dylib (compatibility version 1.0.0)\n"
    local arguments = install.change_arguments(listing, {"libUIKitBackports", "libWebKitBackports", "libSystemBackports"})
    local expected = {"-change", "/usr/lib/revenant/org.revenant.backports/libUIKitBackports.dylib", "@executable_path/Frameworks/libUIKitBackports.dylib",
                      "-change", "/usr/lib/revenant/org.revenant.backports/libSystemBackports.dylib", "@executable_path/Frameworks/libSystemBackports.dylib"}
    if table.concat(arguments, " ") ~= table.concat(expected, " ") then
        table.insert(found, "only the backports libraries a file names are retargeted, got " .. table.concat(arguments, " "))
    end
    if #install.change_arguments("/usr/lib/libSystem.B.dylib (x)", {"libUIKitBackports"}) ~= 0 then
        table.insert(found, "a file that names no backports library must not change")
    end
    local mapkit = "RNHost:\n\t/usr/lib/revenant/org.revenant.backports/libMapKitBackports.dylib (compatibility version 1.0.0)\n"
    if not table.contains(install.backports_libraries(), "libMapKitBackports") or
       table.concat(install.change_arguments(mapkit, install.backports_libraries()), " ") ~= "-change /usr/lib/revenant/org.revenant.backports/libMapKitBackports.dylib @executable_path/Frameworks/libMapKitBackports.dylib" then
        table.insert(found, "the MapKit backports library is packed and retargeted with the host")
    end

    local command = install.install_command("holder", "org.revenant.rnhost.iso")
    if not command:find("rm -rf /var/stash/holder/iso/iso.app /Applications/iso.app", 1, true) or not command:find("tar xzf /var/tmp/iso.tgz -C unpack", 1, true) or not command:find("mv unpack/*.app iso.app", 1, true) or
       command:find("RNHost", 1, true) or command:find("rm -rf /Applications/RNHost", 1, true) then
        table.insert(found, "the install must remove only the app of its own id: " .. command)
    end

    if not command:find("chown -R root:wheel iso.app", 1, true) then
        table.insert(found, "the unpacked app must belong to root: the archive keeps the owner of the Mac")
    end
    if install.conf_text("bundle.js", "engine=hermes,JSC_X=1") ~= "module=main\nbundle=bundle.js\nengine=hermes\nJSC_X=1\n" or
       install.conf_text("b.js") ~= "module=main\nbundle=b.js\n" then
        table.insert(found, "the configuration is module, bundle and the lines asked for")
    end
    local refused = false
    try {
        function () install.conf_text("bundle.js", "a=b") end,
        catch {
            function () refused = true end
        }
    }
    if not refused then
        table.insert(found, "a configuration key the host does not read must be refused")
    end

    local same = install.bundle_identifier_error("org.revenant.rnhost.iso", "org.revenant.rnhost.iso")
    local other = install.bundle_identifier_error("space.kern0x1b.paseo-ios6.rnhost", "org.revenant.rnhost.iso")
    if same ~= nil or other == nil or not other:find("space.kern0x1b.paseo-ios6.rnhost", 1, true) or not other:find("org.revenant.rnhost.iso", 1, true) then
        table.insert(found, "stage must refuse a built app whose bundle id is not the id it is given, and name both ids")
    end

    local outputs ={["rnhost.cmd.out"] = true, ["rnhost.stack"] = true, ["rnhost.prof.out"] = true, ["rnhost.jsprof.out"] = true, ["rnhost.log"] = true}
    for _, file in ipairs(os.files(path.join(root, "frameworks", "ReactNative", "src", "host", "*"))) do
        local text = io.readfile(file)
        if text:find("/var/tmp/rnhost", 1, true) or text:find("real.js", 1, true) then
            table.insert(found, path.filename(file) .. " names a shared /var/tmp path")
        end
        for name in text:gmatch("RNHostRunPath%(@\"([^\"]+)\"%)") do
            if not outputs[name] then
                table.insert(found, path.filename(file) .. " reads " .. name .. " from /var/tmp; it must come from the application bundle")
            end
        end
    end
    return found
end
