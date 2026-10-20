local failed = false

local function ok(message, ...)
    print("ok    " .. message, ...)
end

local function fail(message, ...)
    print("FAIL  " .. message, ...)
    failed = true
end

local PRUNED = {"build", ".xmake", ".logs", ".git"}

local function find(root, tests, opt)
    opt = opt or {}
    local argv = {"."}
    for _, name in ipairs(opt.prune and PRUNED or {}) do
        table.join2(argv, {"-name", name, "-prune", "-o"})
    end
    table.join2(argv, tests)
    table.insert(argv, "-print")
    local found = {}
    for line in os.iorunv("find", argv, {curdir = root}):gmatch("[^\n]+") do
        table.insert(found, (line:gsub("^%./", "")))
    end
    table.sort(found)
    return found
end

local function scenario_settings(folder)
    local settings = {}
    for line in io.readfile(path.join(folder, "scenario.conf")):gmatch("[^\n]+") do
        local key, value = line:match("^%s*([%w_]+)=(.*)$")
        if key then
            settings[key] = value
        end
    end
    for _, key in ipairs({"RELEASE", "DEVICE", "ARCH", "LANGUAGE"}) do
        if not settings[key] then
            raise("%s names no %s", path.join(folder, "scenario.conf"), key)
        end
    end
    return settings
end

local function output_of(program, argv)
    return try { function () return os.iorunv(program, argv) end }
end

local function language(project, settings)
    local m = #find(project, {"-type", "f", "(", "-name", "*.m", "-o", "-name", "*.mm", ")"}, {prune = true})
    local s = #find(project, {"-type", "f", "-name", "*.swift"}, {prune = true})
    if settings.LANGUAGE == "objc" then
        if m > 0 and s == 0 then
            ok("Objective-C sources (%d), no Swift", m)
        else
            fail("language objc: %d .m, %d .swift", m, s)
        end
    elseif settings.LANGUAGE == "swift" then
        if s > 0 then
            ok("Swift sources (%d)", s)
        else
            fail("language swift: no .swift file")
        end
    elseif settings.LANGUAGE == "swiftui" then
        local imports = false
        for _, file in ipairs(find(project, {"-type", "f", "-name", "*.swift"})) do
            local text = io.readfile(path.join(project, file), {encoding = "binary"})
            imports = imports or text:find("^import SwiftUI") ~= nil or text:find("\nimport SwiftUI") ~= nil
        end
        if s > 0 and imports then
            ok("Swift sources (%d) importing SwiftUI", s)
        else
            fail("language swiftui: no .swift file importing SwiftUI")
        end
    end
    if os.isfile(path.join(project, "PROJECT.md")) then
        ok("PROJECT.md written")
    else
        fail("no PROJECT.md: the interview did not record its decisions")
    end
end

local function nothing_copied(project, plugin)
    if #find(project, {"-name", "SKILL.md"}, {prune = true}) > 0 then
        fail("a SKILL.md is in the project")
    else
        ok("no SKILL.md in the project")
    end
    local copied = os.iorunv(os.programfile(), {"l", path.join(path.absolute(os.scriptdir()), "copied_text.lua"), plugin, "."}, {curdir = project})
    copied = copied:gsub("%s+$", "")
    if copied == "" then
        ok("no 5-line run shared with the plugin")
    else
        fail("text copied from the plugin:")
        for line in copied:gmatch("[^\n]+") do
            print("      " .. line)
        end
    end
end

local function release_declared(project, settings)
    local file = path.join(project, "xmake.lua")
    local text = os.isfile(file) and io.readfile(file) or ""
    if text:find("apple_minimum[\"'], *[\"']" .. settings.RELEASE:gsub("%.", "%%.") .. "[\"']") then
        ok("apple_minimum %s in xmake.lua", settings.RELEASE)
    else
        fail("xmake.lua does not set apple_minimum to %s", settings.RELEASE)
    end
end

local function without_zero(version)
    return (version:gsub("%.0$", ""))
end

local function built(project, settings)
    local apps = os.isdir(path.join(project, "build")) and find(path.join(project, "build"), {"-type", "d", "-name", "*.app", "-not", "-path", "*/.xmake/*"}) or {}
    if #apps == 0 then
        fail("no .app under build/")
        return
    end
    local app = path.join("build", apps[1])
    local plist = path.join(project, app, "Info.plist")
    local exe = output_of("/usr/libexec/PlistBuddy", {"-c", "Print :CFBundleExecutable", plist})
        or output_of("plutil", {"-extract", "CFBundleExecutable", "raw", plist})
    exe = exe and exe:gsub("%s+$", "")
    local binary = exe and path.join(project, app, exe)
    if not exe or exe == "" or not os.isfile(binary) then
        fail("%s has no executable named by CFBundleExecutable", app)
        return
    end
    local archs = (output_of("lipo", {"-archs", binary}) or ""):gsub("%s+$", "")
    local has = false
    for arch in archs:gmatch("%S+") do
        has = has or arch == settings.ARCH
    end
    if has then
        ok("%s/%s has %s", app, exe, settings.ARCH)
    else
        fail("%s/%s lacks %s (%s)", app, exe, settings.ARCH, archs)
    end
    local load_commands = output_of("otool", {"-arch", settings.ARCH, "-l", binary}) or ""
    local minos = load_commands:match("LC_VERSION_MIN_IPHONEOS.-\n%s*version%s+(%S+)") or ""
    if without_zero(minos) == without_zero(settings.RELEASE) then
        ok("minimum OS in the binary is %s", minos)
    else
        fail("minimum OS in the binary is '%s', not %s", minos, settings.RELEASE)
    end
end

local function emulated(project, settings)
    local wanted = "^pass on " .. settings.DEVICE:gsub("%p", "%%%0") .. " " .. settings.RELEASE:gsub("%.", "%%.") .. " "
    local passed = false
    for _, file in ipairs(os.files(path.join(project, ".logs", "*"))) do
        for line in io.readfile(file, {encoding = "binary"}):gsub("\27%[[%d;]*m", ""):gmatch("[^\n]+") do
            passed = passed or line:find(wanted) ~= nil
        end
    end
    if passed then
        ok("emulator: pass on %s %s", settings.DEVICE, settings.RELEASE)
    else
        fail("emulator: no 'pass on %s %s' line in .logs/", settings.DEVICE, settings.RELEASE)
    end
end

local function packaged(project)
    local debs = {}
    for _, pattern in ipairs({"*.deb", "*/*.deb", "*/*/*.deb"}) do
        for _, file in ipairs(os.files(path.join(project, "build", pattern))) do
            if not path.filename(file):startswith("org.revenant.") then
                table.insert(debs, file)
            end
        end
    end
    if #debs == 0 then
        fail("no app .deb under build/")
        return
    end
    local deb = path.relative(debs[1], project)
    local architecture = (output_of("dpkg-deb", {"-f", debs[1], "Architecture"}) or ""):gsub("%s+$", "")
    if architecture == "iphoneos-arm" then
        ok("%s is iphoneos-arm", deb)
    else
        fail("%s Architecture is '%s'", deb, architecture)
    end
    local contents = output_of("dpkg-deb", {"-c", debs[1]}) or ""
    if contents:find("/Applications/[^\n]*%.app/") then
        ok("%s carries an app under /Applications", deb)
    else
        fail("%s has nothing under /Applications", deb)
    end
end

local CREDENTIAL_SHAPES = {"claudeAiOauth", "\"refreshToken\"", "sk%-ant%-oat%d", "sk%-ant%-ort%d"}

local function no_credentials(evidence)
    local found = {}
    for _, file in ipairs(find(evidence, {"-type", "f"})) do
        local full = path.join(evidence, file)
        if path.filename(file) == ".credentials.json" then
            table.insert(found, full)
        elseif path.filename(file) ~= "check.txt" then
            local text = io.readfile(full, {encoding = "binary"})
            for _, shape in ipairs(CREDENTIAL_SHAPES) do
                if text:find(shape) then
                    table.insert(found, full)
                    break
                end
            end
        end
    end
    if #found == 0 then
        ok("no login credentials in the evidence")
    else
        fail("login credentials in the evidence:")
        for _, file in ipairs(found) do
            print("      " .. file)
        end
    end
end

function verdict(project, scenario, plugin, evidence)
    failed = false
    if not os.isdir(project) then
        print("FAIL  no project directory " .. project)
        return false
    end
    project = path.absolute(project)
    local settings = scenario_settings(path.absolute(scenario))
    language(project, settings)
    nothing_copied(project, path.absolute(plugin))
    release_declared(project, settings)
    built(project, settings)
    emulated(project, settings)
    packaged(project)
    if evidence then
        no_credentials(path.absolute(evidence))
    end
    print("")
    print(failed and "RUN DOES NOT COUNT" or "RUN COUNTS")
    return not failed
end

function main(project, scenario, plugin, evidence)
    if not project or not scenario or not plugin then
        raise("usage: ./xmakew l agent-skills/tests/check.lua PROJECT_DIR SCENARIO_DIR PLUGIN_DIR [EVIDENCE_DIR]")
    end
    os.exit(verdict(project, scenario, plugin, evidence) and 0 or 1)
end
