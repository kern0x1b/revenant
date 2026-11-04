local USAGE = [[usage: ./xmakew l -P . frameworks/ReactNative/tools/isolate.lua copy <project> <folder> --cache <private cache> [--bundle-id org.revenant.rnhost.<name>]
       ./xmakew l -P . frameworks/ReactNative/tools/isolate.lua build <folder> --cache <private cache> [--target RNHost] [--real a,b] [--pods pkg:module,...] [--jobs N] [--log file]
  copy   makes a private copy of the host project in <folder>: the hand-made inputs of its build/ with every absolute path rewritten to
         the folder, build/ref linked read only, and the react-native package with all its patches installed into the private cache
         and linked as build/rn-src. The path of <folder> must not contain "test" or "Example". The copy's app gets its own bundle id,
         --bundle-id or org.revenant.rnhost.<folder name>, so that installs of different workers do not overwrite each other.
  build  builds the host (or another target, for example expo-jsi-probe) from that copy with this checkout's toolchain. Expo packages
         named in --real and community libraries named in --pods are built as real modules; the rest are the stubs of the host.
         The react-native-enriched-markdown sources are the installed package of its recipe (packages/r, patches included), not the application's node_modules copy.]]

local INPUTS = {"app-assets", "codegen", "expo-core", "expo-jsi", "expo-pods", "expo-src", "keyboard", "lib-headers", "nitro", "rn-codegen", "rn-headers", "rn-spike-gen", "screens", "unistyles"}

local DEFAULT_PODS = "react-native-worklets:rnworklets,react-native-webview:RNCWebViewSpec,react-native-reanimated:rnreanimated,react-native-gesture-handler:rngesturehandler_codegen,react-native-safe-area-context:safeareacontext,react-native-screens:rnscreens,react-native-svg:rnsvg,react-native-keyboard-controller:RNKC,@mattermost/react-native-paste-input:PasteTextInputSpecs,@react-native-masked-view/masked-view,react-native-enriched-markdown"

local PATCH_MARKERS = {
    {"React/Fabric/Mounting/ComponentViews/TextInput/RCTTextInputUtils.mm", 'attributedString.string ?: @""'},
    {"Libraries/Image/RCTImageUtils.mm", "CGFloat)width.doubleValue"},
    {"ReactCommon/jsc/JSCRuntime.cpp", "RNJscRuntimeContext"}
}

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

local HOST_BUNDLE_ID = "space.kern0x1b.paseo-ios6.rnhost"

local ENRICHED_MARKDOWN = {name = "react-native-enriched-markdown", version = "1.2.0-nightly-20261014-766fc0e67"}

function host_bundle_id(folder, given)
    if given then
        return given
    end
    local name = path.filename(folder):lower():gsub("[^a-z0-9%-]", "-")
    return "org.revenant.rnhost." .. name
end

-- Returns the candidate that is the install xmake reports for the recipe (key) if it carries every patch marker. The
-- cache keeps the installs of earlier recipes too, and one of those may carry the markers as well: only the key's own
-- install is the one the recipe builds, so another complete candidate is never picked.
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
        RN_PODS_MORE = options.pods or DEFAULT_PODS,
        RN_WEBKIT_BACKPORTS = options.backports,
        RN_JSC_ENGINE = options.engine,
        RN_DEPS_REPO = "1",
        RN_BACKPORTS = "1",
        RN_LINK_ALL = "1",
        RN_ONLY = "1",
        RN_EXPO = "1",
        REVENANT_PATH = options.checkout,
        REVENANT_CACHE = options.cache,
        REVENANT_PREBUILT = "kern0x1b/revenant",
        REVENANT_PREBUILT_ONLY = "1"
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
    local host = path.absolute(path.join(os.scriptdir(), "..", "src", "host"))
    local target = path.join(folder, "rn-spike", "host-app")
    if os.isdir(target) and os.isdir(host) then
        os.vrunv("rsync", {"-a", host .. "/", target .. "/"})
    end
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
    local id = host_bundle_id(folder, bundle_id)
    local manifest = path.join(folder, "rn-spike", "host-app", "xmake.lua")
    if os.isfile(manifest) then
        local text = io.readfile(manifest)
        local changed = replace(text, "CFBundleIdentifier=" .. HOST_BUNDLE_ID, "CFBundleIdentifier=" .. id)
        if changed ~= text then
            io.writefile(manifest, changed)
        end
    end
    return {rewritten = rewritten, relinked = relinked, bundle_id = id}
end

local function checkout()
    return path.absolute(os.projectdir())
end

function install_react_native(folder, cache)
    local probe = path.join(folder, "build", "pkg-probe")
    os.mkdir(probe)
    io.writefile(path.join(probe, "xmake.lua"), table.concat({
        'set_project("rnsrc")',
        'set_xmakever("3.1.2")',
        'add_rules("mode.release")',
        string.format('add_repositories("revenant %s")', checkout()),
        string.format('add_addons("revenant", {sourcedir = "%s"})', path.join(checkout(), "toolchain")),
        'set_config("apple_minimum", "6.0")',
        'includes("@addon/revenant/apple-ios")',
        'add_requires("revenant@react-native 0.86.3", {alias = "react-native"})',
        'target("t")',
        '    set_kind("phony")',
        '    add_packages("react-native")',
        '    on_config(function (target)',
        '        io.writefile(path.join(os.projectdir(), "installdir.txt"), target:pkg("react-native"):installdir())',
        '    end)', ""}, "\n"))
    local installed = path.join(probe, "installdir.txt")
    os.tryrm(installed)
    os.vrunv(path.join(checkout(), "xmakew"), {"f", "-P", probe, "-p", "iphoneos", "-a", "armv7", "-y"}, {envs = {REVENANT_CACHE = cache}})
    if not os.isfile(installed) then
        raise("react-native 0.86.3 is not installed from its recipe")
    end
    return link_react_native(folder, io.readfile(installed):trim())
end

-- Installs a revenant recipe into the private cache and returns its install directory: the on_config of the probe
-- reports the directory xmake installed the package into, so the recipe's own patches are the sources that build.
function install_recipe(folder, cache, name, version)
    local probe = path.join(folder, "build", "pkg-probe-" .. name)
    os.mkdir(probe)
    local installed = path.join(probe, "installdir.txt")
    os.tryrm(installed)
    io.writefile(path.join(probe, "xmake.lua"), table.concat({
        'set_project("pkgprobe")',
        'set_xmakever("3.1.2")',
        'add_rules("mode.release")',
        string.format('add_repositories("revenant %s")', checkout()),
        string.format('add_addons("revenant", {sourcedir = "%s"})', path.join(checkout(), "toolchain")),
        'set_config("apple_minimum", "6.0")',
        'includes("@addon/revenant/apple-ios")',
        string.format('add_requires("revenant@%s %s", {alias = "%s"})', name, version, name),
        'target("t")',
        '    set_kind("phony")',
        string.format('    add_packages("%s")', name),
        '    on_config(function (target)',
        string.format('        io.writefile(path.join(os.projectdir(), "installdir.txt"), target:pkg("%s"):installdir())', name),
        '    end)', ""}, "\n"))
    os.vrunv(path.join(checkout(), "xmakew"), {"f", "-P", probe, "-p", "iphoneos", "-a", "armv7", "-y"}, {envs = {REVENANT_CACHE = cache}})
    if not os.isfile(installed) then
        raise("%s %s is not installed from its recipe", name, version)
    end
    return io.readfile(installed):trim()
end

-- Links the react-native sources of the install the recipe resolved to (installdir, from the probe), which must carry
-- every patch marker.
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

function build(folder, cache, options)
    folder = path.absolute(folder)
    local shared = options.shared or path.join(os.getenv("HOME"), "Git", "projects", "ios", "revenant", ".cache")
    local ci_backports = path.join(shared, "scratch", "rn-swift", "ci-backports", "libWebKitBackports.dylib")
    local enriched = install_recipe(folder, path.absolute(cache), ENRICHED_MARKDOWN.name, ENRICHED_MARKDOWN.version)
    local env = build_environment({
        folder = folder, cache = path.absolute(cache), checkout = checkout(), real = options.real, pods = options.pods,
        pkgdirs = ENRICHED_MARKDOWN.name .. "=" .. enriched,
        engine = options.engine or newest(path.join(shared, "xmake-global", ".xmake", "packages", "w", "webkit-engine", "latest", "*"), path.join("frameworks", "JavaScriptCore.framework", "JavaScriptCore")),
        swiftui = options.swiftui or path.join(newest(path.join(shared, "xmake-global", ".xmake", "packages", "s", "swiftui", "latest", "*"), path.join("lib", "swift", "iphoneos")), "lib", "swift", "iphoneos"),
        backports = options.backports or (os.isfile(ci_backports) and ci_backports or nil)
    })
    local log = options.log or path.join(folder, "build", "isolated.log")
    install_react_native(folder, path.absolute(cache))
    os.cd(folder)
    os.vrunv("sh", {"rn-spike/tools/patch-provider.sh"})
    local xmakew = path.join(checkout(), "xmakew")
    local configured = command_status({"-c", "\"$1\" f -c -y -P \"$2\" > \"$3\" 2>&1", "sh", xmakew, folder, log}, {envs = env})
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
