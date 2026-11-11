local USAGE = [[usage: ./xmakew l -P . frameworks/ReactNative/tools/isolate.lua copy <project> <folder> --cache <private cache> [--bundle-id org.revenant.rnhost.<name>]
       ./xmakew l -P . frameworks/ReactNative/tools/isolate.lua build <folder> --cache <private cache> [--target RNHost] [--real a,b] [--pods pkg:module,...] [--jobs N] [--log file]
  copy   makes a private copy of the host project in <folder>: the hand-made inputs of its build/ with every absolute path rewritten to
         the folder, build/ref linked read only, and the react-native package with all its patches installed into the private cache
         and linked as build/rn-src. The path of <folder> must not contain "test" or "Example". The copy's app gets its own bundle id,
         --bundle-id or org.revenant.rnhost.<folder name>, written as bundleId into the copy's build/app-manifest/host.json, so that installs of different workers do not overwrite each other.
  build  builds the host (or another target, for example expo-jsi-probe) from that copy with this checkout's toolchain. Expo packages
         named in --real and community libraries named in --pods, or in the pods of the app manifest, are built as real modules; the rest are the stubs of the host.
         The react-native-enriched-markdown sources are the installed package of its recipe (packages/r, patches included), not the application's node_modules copy.]]

local INPUTS = {"app-assets", "app-components", "app-manifest", "codegen", "expo-core", "expo-jsi", "expo-pods", "expo-src", "keyboard", "lib-headers", "nitro", "rn-codegen", "rn-headers", "screens", "unistyles"}

local json = import("core.base.json")

local PATCH_MARKERS = {
    {"React/Fabric/Mounting/ComponentViews/TextInput/RCTTextInputUtils.mm", 'attributedString.string ?: @""'},
    {"Libraries/Image/RCTImageUtils.mm", "CGFloat)width.doubleValue"},
    {"ReactCommon/jsc/JSCRuntime.cpp", "RNJscRuntimeContext"}
}

local WHOLE = {
    {line = 'add_requires("revenant@swift-runtime", {alias = "swift-runtime", configs = {shared = true}})', alias = "swift-runtime", plain = 'add_requires("revenant@swift-runtime", {alias = "swift-runtime"})'},
    {line = 'add_requires("revenant@libcxx", {alias = "libcxx", configs = {packaged = true}})', alias = "libcxx", plain = 'add_requires("revenant@libcxx", {alias = "libcxx"})'},
    {line = 'add_requireconfs("**.libcxx", {configs = {packaged = true}})'},
    {line = 'add_requires("webkit-engine", {alias = "webkit-engine-prefixed", configs = {variant = "prefixed"}})', emit = 'if not os.getenv("RN_WEBKIT") then add_requires("webkit-engine", {alias = "webkit-engine-prefixed", configs = {variant = "prefixed"}}) end'}
}

local WHOLE_PROBE = {WHOLE[1].line, WHOLE[2].line, WHOLE[3].line}

function declares(text, alias)
    return text:find('alias = "' .. alias .. '"', 1, true) ~= nil
end

function whole_missing(text)
    local missing = {}
    for _, requirement in ipairs(WHOLE) do
        if not text:find(requirement.line, 1, true) then
            table.insert(missing, requirement)
        end
    end
    return missing
end

function whole_requirements(text)
    for _, requirement in ipairs(WHOLE) do
        if requirement.plain then
            text = replace(text, requirement.plain, requirement.line)
        end
    end
    local added = {}
    for _, requirement in ipairs(whole_missing(text)) do
        if requirement.plain and declares(text, requirement.alias) then
            raise("the application declares %s with configs other than the whole configuration, so the copy cannot carry it", requirement.alias)
        end
        table.insert(added, requirement.emit or requirement.line)
    end
    if #added > 0 then
        text = text .. "\n" .. table.concat(added, "\n") .. "\n"
    end
    return text
end

function replace(text, old, new)
    local parts, position = {}, 1
    while true do
        local first, last = text:find(old, position, true)
        if not first then
            break
        end
        table.insert(parts, text:sub(position, first - 1))
        table.insert(parts, new)
        position = last + 1
    end
    table.insert(parts, text:sub(position))
    return table.concat(parts)
end

function link_target(target, old, new)
    if target == old or target:startswith(old .. "/") then
        return new .. target:sub(#old + 1)
    end
end

function folder_is_valid(folder)
    return not (folder:find("[Tt]est") or folder:find("Example"))
end

function input_names()
    return INPUTS
end

function missing_input(folder)
    if not os.isfile(path.join(folder, "xmake.lua")) then
        return "xmake.lua"
    end
    for _, item in ipairs(INPUTS) do
        if not os.exists(path.join(folder, "build", item)) then
            return path.join("build", item)
        end
    end
    return nil
end

function check_copy(folder)
    local missing = missing_input(folder)
    if missing then
        raise("%s is not a complete copy made by copy: %s is missing, so nothing is built", folder, missing)
    end
    local lacking = whole_missing(io.readfile(path.join(folder, "xmake.lua")))
    if #lacking > 0 then
        raise("%s is not a copy of the whole configuration: its xmake.lua lacks %s, so nothing is built; make the copy again", folder, lacking[1].line)
    end
end

local ENRICHED_MARKDOWN = {name = "react-native-enriched-markdown", version = "1.2.0-nightly-20261014-766fc0e67"}

local DEFAULT_PATCHED = {"expo-clipboard"}

function default_patched(folder, real)
    if real and real ~= "" then
        return {}
    end
    local ref = path.join(folder, "build", "ref", "paseo")
    local found = {}
    for _, name in ipairs(DEFAULT_PATCHED) do
        if os.isdir(path.join(ref, "packages", "app", "node_modules", name)) or os.isdir(path.join(ref, "node_modules", name)) then
            table.insert(found, name)
        end
    end
    return found
end

function app_manifest_file(folder)
    return path.join(folder, "build", "app-manifest", "host.json")
end

function read_app_manifest(folder)
    local file = app_manifest_file(folder)
    if not os.isfile(file) then
        return {}
    end
    return json.decode(io.readfile(file))
end

function host_bundle_id(folder, given)
    if given then
        return given
    end
    local name = path.filename(folder):lower():gsub("[^a-z0-9%-]", "-")
    return "org.revenant.rnhost." .. name
end

function write_bundle_id(folder, given)
    local manifest = read_app_manifest(folder)
    local id = given or manifest.bundleId or host_bundle_id(folder)
    manifest.bundleId = id
    os.mkdir(path.directory(app_manifest_file(folder)))
    io.writefile(app_manifest_file(folder), json.encode(manifest))
    return id
end

function patched_sources(candidates, read, key)
    for _, candidate in ipairs(candidates) do
        local complete = candidate == key
        for _, marker in ipairs(PATCH_MARKERS) do
            local text = read(path.join(candidate, marker[1]))
            if not (text and text:find(marker[2], 1, true)) then
                complete = false
            end
        end
        if complete then
            return candidate
        end
    end
    return nil
end

function build_environment(options)
    local env = {
        RN_SRC = path.join(options.folder, "build", "rn-src"),
        RN_HEADERS = path.join(options.folder, "build", "rn-headers"),
        RN_SWIFT_I = options.swiftui,
        RN_STUBS = "1",
        RN_PODS_MORE = options.pods,
        RN_WEBKIT_BACKPORTS = options.backports,
        RN_JSC_ENGINE = (not options.hermes) and options.engine or nil,
        RN_HERMES = options.hermes and "1" or nil,
        RN_DEPS_REPO = "1",
        RN_BACKPORTS = "1",
        RN_LINK_ALL = "1",
        RN_ONLY = "1",
        RN_EXPO = "1",
        REVENANT_PATH = options.checkout,
        REVENANT_CACHE = options.cache,
        REVENANT_PREBUILT = "kern0x1b/revenant",
        REVENANT_PREBUILT_ONLY = os.getenv("REVENANT_PREBUILT_ONLY") or "1"
    }
    if options.real and options.real ~= "" then
        env.RN_EXPO_REAL = options.real
    end
    if options.pkgdirs and options.pkgdirs ~= "" then
        env.RN_PKG_DIRS = options.pkgdirs
    end
    return env
end

local function lines(output)
    local found = {}
    for line in output:gmatch("[^\n]+") do
        table.insert(found, line)
    end
    return found
end

function copy_project(project, folder, bundle_id)
    project = path.absolute(project)
    folder = path.absolute(folder)
    if not folder_is_valid(folder) then
        raise("%s contains test or Example, which the pod source filter of the host build skips", folder)
    end
    if folder == project then
        raise("%s is the original project", folder)
    end
    os.mkdir(folder)
    os.vrunv("rsync", {"-a", "--exclude", "build", "--exclude", "*.log", project .. "/", folder .. "/"})
    os.mkdir(path.join(folder, "build"))
    for _, item in ipairs(INPUTS) do
        if os.exists(path.join(project, "build", item)) then
            os.vrunv("rsync", {"-a", path.join(project, "build", item), path.join(folder, "build") .. "/"})
        end
    end
    local reference = path.join(project, "build", "ref")
    if os.exists(reference) then
        local real = os.iorunv("sh", {"-c", "cd \"$1\" && pwd -P", "sh", reference}):trim()
        os.vrunv("ln", {"-sfn", real, path.join(folder, "build", "ref")})
    end
    local rewritten = 0
    local named = try {
        function ()
            return os.iorunv("grep", {"-rIlF", "--exclude-dir=ref", project, folder})
        end,
        catch {
            function ()
                return ""
            end
        }
    }
    for _, file in ipairs(lines(named)) do
        local text = io.readfile(file)
        local changed = replace(text, project, folder)
        if changed ~= text then
            io.writefile(file, changed)
            rewritten = rewritten + 1
        end
    end
    local relinked = 0
    for _, link in ipairs(lines(os.iorunv("find", {path.join(folder, "build"), "-type", "l", "-not", "-path", path.join(folder, "build", "ref")}))) do
        local target = os.iorunv("readlink", {link}):trim()
        local new = link_target(target, project, folder)
        if new then
            os.vrunv("ln", {"-sfn", new, link})
            relinked = relinked + 1
        end
    end
    local xmake = path.join(folder, "xmake.lua")
    local text = io.readfile(xmake)
    local carried = whole_requirements(text)
    if carried ~= text then
        io.writefile(xmake, carried)
    end
    local id = write_bundle_id(folder, bundle_id)
    return {rewritten = rewritten, relinked = relinked, bundle_id = id}
end

local function checkout()
    return path.absolute(os.projectdir())
end

function install_react_native(folder, cache)
    local probe = path.join(folder, "build", "pkg-probe")
    os.mkdir(probe)
    io.writefile(path.join(probe, "xmake.lua"), table.concat(table.join({
        'set_project("rnsrc")',
        'set_xmakever("3.1.2")',
        'add_rules("mode.release")',
        string.format('add_repositories("revenant %s")', checkout()),
        string.format('add_addons("revenant", {sourcedir = "%s"})', path.join(checkout(), "toolchain")),
        'set_config("apple_minimum", "6.0")',
        'includes("@addon/revenant/apple-ios")'}, WHOLE_PROBE, {
        'add_requires("revenant@react-native 0.86.3", {alias = "react-native"})',
        'target("t")',
        '    set_kind("phony")',
        '    add_packages("react-native")',
        '    on_config(function (target)',
        '        io.writefile(path.join(os.projectdir(), "installdir.txt"), target:pkg("react-native"):installdir())',
        '    end)', ""}), "\n"))
    local installed = path.join(probe, "installdir.txt")
    os.tryrm(installed)
    os.vrunv(path.join(checkout(), "xmakew"), {"f", "-P", probe, "-p", "iphoneos", "-a", "armv7", "-y"}, {envs = {REVENANT_CACHE = cache}})
    if not os.isfile(installed) then
        raise("react-native 0.86.3 is not installed from its recipe")
    end
    return link_react_native(folder, io.readfile(installed):trim())
end

function install_recipe(folder, cache, name, version)
    local probe = path.join(folder, "build", "pkg-probe-" .. name)
    os.mkdir(probe)
    local installed = path.join(probe, "installdir.txt")
    os.tryrm(installed)
    io.writefile(path.join(probe, "xmake.lua"), table.concat(table.join({
        'set_project("pkgprobe")',
        'set_xmakever("3.1.2")',
        'add_rules("mode.release")',
        string.format('add_repositories("revenant %s")', checkout()),
        string.format('add_addons("revenant", {sourcedir = "%s"})', path.join(checkout(), "toolchain")),
        'set_config("apple_minimum", "6.0")',
        'includes("@addon/revenant/apple-ios")'}, WHOLE_PROBE, {
        string.format('add_requires("revenant@%s %s", {alias = "%s"})', name, version, name),
        'target("t")',
        '    set_kind("phony")',
        string.format('    add_packages("%s")', name),
        '    on_config(function (target)',
        string.format('        io.writefile(path.join(os.projectdir(), "installdir.txt"), target:pkg("%s"):installdir())', name),
        '    end)', ""}), "\n"))
    os.vrunv(path.join(checkout(), "xmakew"), {"f", "-P", probe, "-p", "iphoneos", "-a", "armv7", "-y"}, {envs = {REVENANT_CACHE = cache}})
    if not os.isfile(installed) then
        raise("%s %s is not installed from its recipe", name, version)
    end
    return io.readfile(installed):trim()
end

function link_react_native(folder, installdir)
    local sources = path.join(installdir, "src", "react-native")
    local found = patched_sources({sources}, function (file)
        return os.isfile(file) and io.readfile(file) or nil
    end, sources)
    if not found then
        raise("the react-native sources of %s do not carry every patch", installdir)
    end
    os.vrunv("ln", {"-sfn", found, path.join(folder, "build", "rn-src")})
    return found
end

function command_status(arguments, options)
    local ok = try {
        function ()
            os.execv("sh", arguments, options)
            return true
        end
    }
    return ok and 0 or 1
end

function newest(pattern, marker)
    local found = {}
    for _, dir in ipairs(os.dirs(pattern)) do
        if path.filename(dir):match("^%x+$") and os.exists(path.join(dir, marker)) then
            table.insert(found, dir)
        end
    end
    table.sort(found, function (a, b) return os.mtime(a) < os.mtime(b) end)
    return found[#found]
end

function real_packages(names)
    local found = {}
    for _, name in ipairs(string.split(names or "", ",", {plain = true})) do
        if name ~= "" then
            table.insert(found, name)
        end
    end
    return found
end

function recipe_version(name)
    local recipe = path.join(checkout(), "packages", name:sub(1, 1), name, "xmake.lua")
    local version = os.isfile(recipe) and io.readfile(recipe):match('add_versions%("([^"]+)"')
    if not version then
        raise("%s has no recipe in packages/, so the isolated build cannot take its sources from a revenant install", name)
    end
    return version
end

function build(folder, cache, options)
    folder = path.absolute(folder)
    check_copy(folder)
    local shared = options.shared or path.join(os.getenv("HOME"), "Git", "projects", "ios", "revenant", ".cache")
    local ci_backports = path.join(shared, "scratch", "rn-swift", "ci-backports", "libWebKitBackports.dylib")
    local pkgdirs = {ENRICHED_MARKDOWN.name .. "=" .. install_recipe(folder, path.absolute(cache), ENRICHED_MARKDOWN.name, ENRICHED_MARKDOWN.version)}
    for _, name in ipairs(real_packages(options.real)) do
        table.insert(pkgdirs, name .. "=" .. install_recipe(folder, path.absolute(cache), name, recipe_version(name)))
    end
    for _, name in ipairs(default_patched(folder, options.real)) do
        table.insert(pkgdirs, name .. "=" .. install_recipe(folder, path.absolute(cache), name, recipe_version(name)))
    end
    local hermes = os.getenv("RN_HERMES") and true or nil
    if hermes then
        table.insert(pkgdirs, "react-native-worklets=" .. install_recipe(folder, path.absolute(cache), "react-native-worklets", recipe_version("react-native-worklets")))
    end
    local env = build_environment({
        folder = folder, cache = path.absolute(cache), checkout = checkout(), real = options.real, hermes = hermes, pods = options.pods or table.concat(read_app_manifest(folder).pods or {}, ","),
        pkgdirs = table.concat(pkgdirs, ","),
        engine = options.engine or newest(path.join(shared, "xmake-global", ".xmake", "packages", "w", "webkit-engine", "latest", "*"), path.join("frameworks", "JavaScriptCore.framework", "JavaScriptCore")),
        swiftui = options.swiftui or path.join(newest(path.join(shared, "xmake-global", ".xmake", "packages", "s", "swiftui", "latest", "*"), path.join("lib", "swift", "iphoneos")), "lib", "swift", "iphoneos"),
        backports = options.backports or (os.isfile(ci_backports) and ci_backports or nil)
    })
    local log = options.log or path.join(folder, "build", "isolated.log")
    install_react_native(folder, path.absolute(cache))
    os.cd(folder)
    local xmakew = path.join(checkout(), "xmakew")
    local configured = command_status({"-c", "\"$1\" f -c -y -p iphoneos -a armv7 -P \"$2\" > \"$3\" 2>&1", "sh", xmakew, folder, log}, {envs = env})
    local built = configured
    if configured == 0 then
        built = command_status({"-c", "\"$1\" build -P \"$2\" -j \"$5\" -y -v \"$3\" >> \"$4\" 2>&1", "sh", xmakew, folder, options.target or "RNHost", log, options.jobs or "4"}, {envs = env})
    end
    return built or 1, log
end

function main(...)
    local args = {...}
    local command = args[1]
    local positional, options = {}, {}
    local index = 2
    while index <= #args do
        local arg = args[index]
        if arg:startswith("--") then
            index = index + 1
            options[arg:sub(3)] = args[index]
        else
            table.insert(positional, arg)
        end
        index = index + 1
    end
    if command == "copy" and #positional == 2 and options.cache then
        local result = copy_project(positional[1], positional[2], options["bundle-id"])
        local sources = install_react_native(path.absolute(positional[2]), path.absolute(options.cache))
        print(string.format("isolated %s: %d files rewritten, %d links retargeted, rn-src %s, bundle id %s", positional[2], result.rewritten, result.relinked, sources, result.bundle_id))
    elseif command == "build" and #positional == 1 and options.cache then
        local code, log = build(positional[1], options.cache, {target = options.target, real = options.real, pods = options.pods, log = options.log, engine = options.engine, swiftui = options.swiftui, backports = options.backports, shared = options.shared, jobs = options.jobs})
        print(string.format("exit %d, log %s", code, log))
        local errors = try {
            function ()
                return os.iorunv("sh", {"-c", "sed 's/\\x1b\\[[0-9;]*m//g' \"$1\" | grep -E 'error:|undefined|Undefined|uplicate' | grep -v 'warning:' | cut -c1-300 | sort -u | head -20", "sh", log})
            end,
            catch {
                function ()
                    return ""
                end
            }
        }
        io.write(errors)
        if code ~= 0 then
            raise("the build failed")
        end
    else
        print(USAGE)
    end
end
