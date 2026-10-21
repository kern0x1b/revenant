import("fixtures")

function failures(opt)
    local found = {}
    local stubs = import("apple.sdkstubs", {rootdir = opt.modules, anonymous = true})
    local folder = fixtures.scratch()
    local installdir = path.join(folder, "iphoneos-sdk", "26.2")
    os.mkdir(installdir)
    if stubs.installed(installdir, "26.2") then
        table.insert(found, "an empty install folder is taken as installed")
    end
    io.writefile(path.join(installdir, "manifest.txt"), "")
    if stubs.installed(installdir, "26.2") then
        table.insert(found, "an install folder with a manifest and no SDK is taken as installed")
    end
    local sdk = path.join(installdir, "Developer.app", "Contents", "Developer", "Platforms", "iPhoneOS.platform", "Developer", "SDKs", "iPhoneOS26.2.sdk")
    os.mkdir(sdk)
    io.writefile(path.join(sdk, "SDKSettings.json"), "{}")
    if not stubs.installed(installdir, "26.2") then
        table.insert(found, "a complete install folder is not taken as installed")
    end
    os.tryrm(folder)
    return found
end
