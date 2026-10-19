import("env")
import("translate")

local function bundle_executable(bundle)
    return os.iorunv("plutil", {"-extract", "CFBundleExecutable", "raw", path.join(bundle, "Info.plist")}):trim()
end

function main(input, includes, output)
    if not input or not includes or not output then
        raise("usage: ./xmakew l recompiler/scripts/ipa.lua INPUT.ipa INCLUDES OUTPUT.ipa")
    end
    input = path.absolute(input)
    includes = path.absolute(includes)
    output = path.absolute(output)
    local e = env()
    local work = path.join(e.builddir, "recompiler", "ipa", path.basename(input))
    os.tryrm(work)
    os.mkdir(work)
    try {
        function ()
            os.execv("ditto", {"-x", "-k", input, path.join(work, "in")})
            local apps = os.dirs(path.join(work, "in", "Payload", "*.app"))
            env.sorted(apps)
            local app = assert(apps[1], "no Payload/*.app in " .. input)
            local executable = bundle_executable(app)
            local images = {}
            local frameworks = os.filedirs(path.join(app, "Frameworks", "*"))
            env.sorted(frameworks)
            for _, framework in ipairs(frameworks) do
                if framework:endswith(".framework") then
                    table.insert(images, path.join(framework, bundle_executable(framework)))
                elseif framework:endswith(".dylib") then
                    table.insert(images, framework)
                end
            end
            local thin = path.join(work, executable .. "-arm64")
            if os.execv("lipo", {"-thin", "arm64", path.join(app, executable), "-output", thin}, {stderr = os.nuldev(), try = true}) ~= 0 then
                os.cp(path.join(app, executable), thin)
            end
            translate.translate(thin, includes, path.join(work, "build"), images)
            for _, name in ipairs({"Frameworks", "_CodeSignature", "embedded.mobileprovision", "PlugIns"}) do
                os.tryrm(path.join(app, name))
            end
            os.cp(path.join(work, "build", executable), path.join(app, executable))
            local plist = path.join(app, "Info.plist")
            os.execv("plutil", {"-convert", "xml1", plist})
            os.execv("plutil", {"-replace", "MinimumOSVersion", "-string", "6.0", plist})
            os.execv("plutil", {"-replace", "UIRequiredDeviceCapabilities", "-json", "[\"armv7\"]", plist})
            os.execv("plutil", {"-convert", "binary1", plist})
            local rules = path.join(path.directory(includes), path.basename(app) .. ".rules")
            if os.isfile(rules) then
                os.cp(rules, path.join(app, "xlate.rules"))
            end
            os.execv(e.ldid, {"-S", path.join(app, executable)})
            os.mkdir(path.directory(output))
            os.execv("ditto", {"-c", "-k", "--norsrc", "--noextattr", "--keepParent", "Payload", path.join(work, "out.ipa")}, {curdir = path.join(work, "in")})
            os.mv(path.join(work, "out.ipa"), output)
        end,
        finally {
            function ()
                os.tryrm(work)
            end
        }
    }
    print("%s", output)
end
