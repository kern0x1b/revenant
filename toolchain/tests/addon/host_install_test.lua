function failures(opt)
    local root = path.join(path.directory(opt.modules), "..")
    local install = import("host_install", {rootdir = path.join(root, "frameworks", "ReactNative", "tools"), anonymous = true})
    local found = {}

    if install.app_name("org.revenant.rnhost.hermes") ~= "hermes" or install.app_name("plain") ~= "plain" then
        table.insert(found, "the app is named by the last part of its bundle id")
    end
    if install.stash_folder("rn-hermes", "org.revenant.rnhost.hermes") ~= "/var/stash/rn-hermes/hermes" or install.run_folder("org.revenant.rnhost.iso") ~= "/var/tmp/iso" then
        table.insert(found, "an app lives in its holder's stash folder and runs from a folder of its own name")
    end

    local listing = "RNHost:\n\t/usr/lib/revenant/org.revenant.backports/libUIKitBackports.dylib (compatibility version 1.0.0)\n\t/usr/lib/revenant/org.revenant.backports/libSystemBackports.dylib (compatibility version 1.0.0)\n\t/usr/lib/libSystem.B.dylib (compatibility version 1.0.0)\n"
    local arguments = install.change_arguments(listing, {"libUIKitBackports", "libWebKitBackports", "libSystemBackports"})
    local expected = {"-change", "/usr/lib/revenant/org.revenant.backports/libUIKitBackports.dylib", "@executable_path/Frameworks/libUIKitBackports.dylib",
                      "-change", "/usr/lib/revenant/org.revenant.backports/libSystemBackports.dylib", "@executable_path/Frameworks/libSystemBackports.dylib"}
    if table.concat(arguments, " ") ~= table.concat(expected, " ") then
        table.insert(found, "only the backports libraries a file names are retargeted, got " .. table.concat(arguments, " "))
    end
    if #install.change_arguments("/usr/lib/libSystem.B.dylib (x)", {"libUIKitBackports"}) ~= 0 then
        table.insert(found, "a file that names no backports library must not change")
    end

    local command = install.install_command("holder", "org.revenant.rnhost.iso")
    if not command:find("rm -rf /var/stash/holder/iso/iso.app /Applications/iso.app", 1, true) or not command:find("tar xzf /var/tmp/iso.tgz", 1, true) or
       command:find("RNHost", 1, true) or command:find("rm -rf /Applications/RNHost", 1, true) then
        table.insert(found, "the install must remove only the app of its own id: " .. command)
    end

    if install.conf_text("/var/tmp/iso/bundle.js", "engine=hermes,a=b") ~= "module=main\nbundle=/var/tmp/iso/bundle.js\nengine=hermes\na=b\n" or
       install.conf_text("/x/b.js") ~= "module=main\nbundle=/x/b.js\n" then
        table.insert(found, "the configuration is module, bundle and the lines asked for")
    end
    return found
end
