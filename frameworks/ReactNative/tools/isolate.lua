local USAGE = [[usage: ./xmakew l -P . frameworks/ReactNative/tools/isolate.lua copy <project> <folder> --cache <private cache> [--bundle-id org.revenant.rnhost.<name>]
       ./xmakew l -P . frameworks/ReactNative/tools/isolate.lua clone <warm copy> <folder> --cache <own clone of the private cache> [--src-cache <its cache>] [--src-checkout <its checkout>] [--bundle-id org.revenant.rnhost.<name>]
       ./xmakew l -P . frameworks/ReactNative/tools/isolate.lua build <folder> --cache <private cache> [--target RNHost] [--real a,b] [--pods pkg:module,...] [--jobs N] [--log file] [--configure-only 1] [--deb DIR]
  copy   makes a private copy of the host project in <folder>: the hand-made inputs of its build/ with every absolute path rewritten to
         the folder, build/ref linked read only, and the react-native package with all its patches installed into the private cache
         and linked as build/rn-src. The path of <folder> must not contain "test" or "Example". The copy's app gets its own bundle id,
         --bundle-id or org.revenant.rnhost.<folder name>, written as bundleId into the copy's build/app-manifest/host.json, so that installs of different workers do not overwrite each other.
  clone  makes an APFS clone of a warm copy (one that built) in <folder>, for another worktree whose private cache is an APFS clone of the copy's cache: the
         files that name the old copy, checkout and cache (recorded in build/isolate-roots.txt by copy and build) are rewritten and the links under build/ (rn-headers,
         rn-src, the package probes) are retargeted. The clone's probes answer from their recorded install folders without installing again, nothing in it reaches
         into the copy it came from, and a build in it compiles only what changed.
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
    {line = 'add_requires("webkit-engine", {alias = "webkit-engine-prefixed", configs = {variant = "prefixed"}})', emit = 'if not os.getenv("RN_WEBKIT") and not os.getenv("RN_HERMES") then add_requires("webkit-engine", {alias = "webkit-engine-prefixed", configs = {variant = "prefixed"}}) end'},
    {line = 'option("component", {type = "string", default = "", showmenu = true, description = "Configure only this component and what it needs, for example Backports or emulator; empty configures every component."})'},
    {line = 'add_requireconfs("combine", {override = true, configs = {shared = get_config("component") == "" or nil}})'}
}

local POD_REQUIRES = {
    {name = "sdwebimage", version = "5.21.7", modules = {"expo-image", "expo-image-manipulator"}},
    {name = "sdwebimage-webp", version = "0.14.6", modules = {"expo-image", "expo-image-manipulator"}},
    {name = "zxingobjc", version = "3.6.4", modules = {"expo-camera"}}
}

function pod_requirement(pod)
    local line = string.format('add_requires("revenant@%s %s", {alias = "%s"})', pod.name, pod.version, pod.name)
    local tests = {}
    for _, module in ipairs(pod.modules) do
        table.insert(tests, string.format('(",".. (os.getenv("RN_EXPO_REAL") or "") .. ","):find(",%s,", 1, true)', module))
    end
    return "if " .. table.concat(tests, " or ") .. " then " .. line .. " end"
end

function pod_requirements(text)
    local added = {}
    for _, pod in ipairs(POD_REQUIRES) do
        local emit = pod_requirement(pod)
        if not text:find(emit, 1, true) then
            table.insert(added, emit)
        end
    end
    if #added > 0 then
        text = text .. "\n" .. table.concat(added, "\n") .. "\n"
    end
    return text
end

local SHARED_PACKAGES = {"swiftui", "cryptokit", "uniformtypeidentifiers", "swift-crypto"}

function shared_packages(text)
    local added = {}
    for _, name in ipairs(SHARED_PACKAGES) do
        for _, pattern in ipairs({name, "**." .. name}) do
            local line = 'add_requireconfs("' .. pattern .. '", {configs = {shared = true, apple_sdk = get_config("apple_sdk")}})'
            if not text:find(line, 1, true) then
                table.insert(added, line)
            end
        end
    end
    if #added > 0 then
        text = text .. "\n" .. table.concat(added, "\n") .. "\n"
    end
    return text
end

local HOST_LIBCXX = table.concat({
    'target("RNHost")',
    '    after_load(function (target)',
    '        local kept = {}',
    '        for _, name in ipairs(table.wrap(target:values("app.frameworks"))) do',
    '            if name ~= "libcxx" then',
    '                table.insert(kept, name)',
    '            end',
    '        end',
    '        target:set("values", "app.frameworks", kept)',
    '    end)',
    'target_end()'}, "\n")

function host_libcxx(text)
    if text:find(HOST_LIBCXX, 1, true) then
        return text
    end
    return text .. "\n" .. HOST_LIBCXX .. "\n"
end

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
    local ref = path.join(folder, "build", "ref", "app")
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
    -- The application's own Expo modules (the "modules" of its host.json) are built from its sources, with no recipe.
    local modules = options.folder and read_app_manifest(options.folder).modules
    if modules and #modules > 0 then
        env.RN_APP_MODULES = table.concat(modules, ",")
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
    local carried = pod_requirements(host_libcxx(shared_packages(whole_requirements(text))))
    if carried ~= text then
        io.writefile(xmake, carried)
    end
    local id = write_bundle_id(folder, bundle_id)
    return {rewritten = rewritten, relinked = relinked, bundle_id = id}
end

local function checkout()
    return path.absolute(os.projectdir())
end

function roots_file(folder)
    return path.join(folder, "build", "isolate-roots.txt")
end

function write_roots(folder, cache)
    io.writefile(roots_file(folder), table.concat({path.absolute(folder), checkout(), path.absolute(cache)}, "\n") .. "\n")
end

function read_roots(folder)
    local file = roots_file(folder)
    if not os.isfile(file) then
        return nil
    end
    local found = {}
    for line in io.readfile(file):gmatch("[^\n]+") do
        table.insert(found, line)
    end
    return {folder = found[1], checkout = found[2], cache = found[3]}
end

function root_pairs(old, new)
    local pairs_ = {}
    for _, key in ipairs({"folder", "checkout", "cache"}) do
        if old[key] and new[key] and old[key] ~= new[key] then
            table.insert(pairs_, {old[key], new[key]})
        end
    end
    table.sort(pairs_, function (a, b) return #a[1] > #b[1] end)
    return pairs_
end

function rewrite_roots(text, mapped)
    for _, pair in ipairs(mapped) do
        text = replace(text, pair[1], pair[2])
    end
    return text
end

function retarget_link(target, mapped)
    for _, pair in ipairs(mapped) do
        local new = link_target(target, pair[1], pair[2])
        if new then
            return new
        end
    end
end

function lexical_path(value)
    local parts = {}
    for segment in path.absolute(value):gmatch("[^/]+") do
        if segment == ".." then
            table.remove(parts)
        elseif segment ~= "." then
            table.insert(parts, segment)
        end
    end
    return "/" .. table.concat(parts, "/")
end

function clone_project(src, dst, new_cache, old_cache, old_checkout, bundle_id)
    src, dst = lexical_path(src), lexical_path(dst)
    if not folder_is_valid(dst) then
        raise("%s contains test or Example, which the pod source filter of the host build skips", dst)
    end
    if os.exists(dst) then
        raise("%s exists; remove it first", dst)
    end
    local old = read_roots(src) or {folder = src}
    old.folder = src
    old.cache = old_cache and lexical_path(old_cache) or old.cache
    old.checkout = old_checkout and lexical_path(old_checkout) or old.checkout
    if not (old.cache and old.checkout) then
        raise("%s has no build/isolate-roots.txt: pass --src-cache and --src-checkout", src)
    end
    local new = {folder = dst, checkout = checkout(), cache = lexical_path(new_cache)}
    local mapped = root_pairs(old, new)
    os.mkdir(path.directory(dst))
    local patterns = {}
    for _, pair in ipairs(mapped) do
        table.join2(patterns, {"-e", pair[1]})
    end
    -- The files that name a root are found in the source, once, before the copy; the copy is one clone of the tree and
    -- only those files are opened in it, so the clone is neither walked nor searched.
    local named = try {
        function ()
            return os.iorunv("grep", table.join({"-rIlF", "--exclude-dir=ref"}, patterns, {src}))
        end,
        catch {
            function ()
                return ""
            end
        }
    }
    os.vrunv("cp", {"-cR", src, dst})
    local rewritten = 0
    local touched = {}
    for _, source_file in ipairs(lines(named)) do
        local file = path.join(dst, path.relative(source_file, src))
        table.insert(touched, file)
        local text = io.readfile(file)
        local changed = rewrite_roots(text, mapped)
        if changed ~= text then
            io.writefile(file, changed)
            rewritten = rewritten + 1
        end
    end
    local relinked = 0
    for _, link in ipairs(lines(os.iorunv("find", {path.join(dst, "build"), "-path", path.join(dst, "build", "ref"), "-prune", "-o", "-type", "l", "-print"}))) do
        local retargeted = retarget_link(os.iorunv("readlink", {link}):trim(), mapped)
        if retargeted then
            os.vrunv("ln", {"-sfn", retargeted, link})
            relinked = relinked + 1
        end
    end
    local left = #touched == 0 and "" or try {
        function ()
            return os.iorunv("grep", table.join({"-IlF"}, patterns, touched))
        end,
        catch {
            function ()
                return ""
            end
        }
    }
    local first = lines(left or "")[1]
    if first then
        raise("the clone %s still names a root of the copy it came from, for example in %s", dst, first)
    end
    write_roots(dst, new.cache)
    local id = bundle_id and write_bundle_id(dst, bundle_id) or nil
    return {rewritten = rewritten, relinked = relinked, bundle_id = id}
end

function probe_header(root)
    return {
        'set_xmakever("3.1.2")',
        'add_rules("mode.release")',
        string.format('add_repositories("revenant %s")', root),
        string.format('add_addons("revenant", {sourcedir = "%s"})', path.join(root, "toolchain")),
        'set_config("apple_minimum", "6.0")',
        'includes("@addon/revenant/apple-ios")'}
end

function react_native_probe_text(root)
    return table.concat(table.join({'set_project("rnsrc")'}, probe_header(root), WHOLE_PROBE, {
        'add_requires("revenant@react-native 0.86.3", {alias = "react-native"})',
        'target("t")',
        '    set_kind("phony")',
        '    add_packages("react-native")',
        '    on_config(function (target)',
        '        io.writefile(path.join(os.projectdir(), "installdir.txt"), target:pkg("react-native"):installdir())',
        '    end)', ""}), "\n")
end

function recipe_probe_text(root, name, version)
    return table.concat(table.join({'set_project("pkgprobe")'}, probe_header(root), WHOLE_PROBE, {
        string.format('add_requires("revenant@%s %s", {alias = "%s"})', name, version, name),
        'target("t")',
        '    set_kind("phony")',
        string.format('    add_packages("%s")', name),
        '    on_config(function (target)',
        string.format('        io.writefile(path.join(os.projectdir(), "installdir.txt"), target:pkg("%s"):installdir())', name),
        '    end)', ""}), "\n")
end

function reusable_answer(probe, text, recipe)
    local script, installed = path.join(probe, "xmake.lua"), path.join(probe, "installdir.txt")
    if not (os.isfile(script) and os.isfile(installed) and io.readfile(script) == text) then
        return nil
    end
    local previous = io.readfile(installed):trim()
    local stamp, newest_recipe = os.mtime(installed), 0
    for _, file in ipairs(os.files(path.join(recipe, "**"))) do
        newest_recipe = math.max(newest_recipe, os.mtime(file))
    end
    if os.isdir(previous) and newest_recipe < stamp then
        return previous
    end
    return nil
end

function run_probe(probe, text, cache, what)
    local installed = path.join(probe, "installdir.txt")
    os.tryrm(installed)
    io.writefile(path.join(probe, "xmake.lua"), text)
    os.vrunv(path.join(checkout(), "xmakew"), {"f", "-P", probe, "-p", "iphoneos", "-a", "armv7", "-y"}, {envs = {REVENANT_CACHE = cache}})
    if not os.isfile(installed) then
        raise("%s is not installed from its recipe", what)
    end
    return io.readfile(installed):trim()
end

function install_react_native(folder, cache)
    local probe = path.join(folder, "build", "pkg-probe")
    os.mkdir(probe)
    local text = react_native_probe_text(checkout())
    local installdir = reusable_answer(probe, text, path.join(checkout(), "packages", "r", "react-native"))
        or run_probe(probe, text, cache, "react-native 0.86.3")
    return link_react_native(folder, installdir)
end

function install_recipe(folder, cache, name, version)
    local probe = path.join(folder, "build", "pkg-probe-" .. name)
    os.mkdir(probe)
    local text = recipe_probe_text(checkout(), name, version)
    return reusable_answer(probe, text, path.join(checkout(), "packages", name:sub(1, 1), name))
        or run_probe(probe, text, cache, name .. " " .. version)
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

function application_version(folder, name)
    for _, base in ipairs({{"packages", "app", "node_modules"}, {"node_modules"}}) do
        local file = path.join(folder, "build", "ref", "app", path.join(table.unpack(base)), name, "package.json")
        if os.isfile(file) then
            return json.decode(io.readfile(file)).version
        end
    end
    return nil
end

function patched_pods(folder, cache, manifest, taken)
    local found = {}
    for _, entry in ipairs(manifest.pods or {}) do
        local package = entry:match("^(.-):") or entry
        local name = package:gsub("^@[^/]+/", "")
        local recipe = path.join(checkout(), "packages", name:sub(1, 1), name, "xmake.lua")
        if os.isfile(recipe) and not taken[name] then
            local version = recipe_version(name)
            local used = application_version(folder, package)
            if used == version then
                table.insert(found, name .. "=" .. install_recipe(folder, cache, name, version))
            else
                print(string.format("%s: the application has %s, the patched package is %s; the application's own unpatched copy is built", package, tostring(used), version))
            end
        end
    end
    return found
end

function build(folder, cache, options)
    folder = path.absolute(folder)
    check_copy(folder)
    write_roots(folder, cache)
    local carried = io.readfile(path.join(folder, "xmake.lua"))
    for _, pod in ipairs(POD_REQUIRES) do
        if not carried:find(pod_requirement(pod), 1, true) then
            raise("%s does not require %s for the modules that use it, so nothing is built; make the copy again", folder, pod.name)
        end
    end
    local shared = options.shared or path.join(os.getenv("HOME"), "Git", "projects", "ios", "revenant", ".cache")
    local ci_backports = path.join(shared, "scratch", "rn-swift", "ci-backports", "libWebKitBackports.dylib")
    local pkgdirs = {ENRICHED_MARKDOWN.name .. "=" .. install_recipe(folder, path.absolute(cache), ENRICHED_MARKDOWN.name, ENRICHED_MARKDOWN.version)}
    for _, name in ipairs(real_packages(options.real)) do
        table.insert(pkgdirs, name .. "=" .. install_recipe(folder, path.absolute(cache), name, recipe_version(name)))
    end
    for _, name in ipairs(default_patched(folder, options.real)) do
        table.insert(pkgdirs, name .. "=" .. install_recipe(folder, path.absolute(cache), name, recipe_version(name)))
    end
    local taken = {[ENRICHED_MARKDOWN.name] = true}
    for _, entry in ipairs(pkgdirs) do
        taken[entry:match("^([^=]+)=")] = true
    end
    for _, entry in ipairs(patched_pods(folder, path.absolute(cache), read_app_manifest(folder), taken)) do
        table.insert(pkgdirs, entry)
        taken[entry:match("^([^=]+)=")] = true
    end
    local hermes = os.getenv("RN_HERMES") and true or nil
    if hermes and not taken["react-native-worklets"] then
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
    if configured == 0 and not options.configure_only then
        built = command_status({"-c", "\"$1\" build -P \"$2\" -j \"$5\" -y -v \"$3\" >> \"$4\" 2>&1", "sh", xmakew, folder, options.target or "RNHost", log, options.jobs or "4"}, {envs = env})
    end
    if built == 0 and options.deb then
        built = command_status({"-c", "\"$1\" deb -P \"$2\" -y -o \"$3\" \"$5\" >> \"$4\" 2>&1", "sh", xmakew, folder, path.absolute(options.deb), log, options.target or "RNHost"}, {envs = env})
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
        write_roots(positional[2], options.cache)
        print(string.format("isolated %s: %d files rewritten, %d links retargeted, rn-src %s, bundle id %s", positional[2], result.rewritten, result.relinked, sources, result.bundle_id))
    elseif command == "clone" and #positional == 2 and options.cache then
        local result = clone_project(positional[1], positional[2], options.cache, options["src-cache"], options["src-checkout"], options["bundle-id"])
        print(string.format("cloned %s to %s: %d files rewritten, %d links retargeted", positional[1], positional[2], result.rewritten, result.relinked))
    elseif command == "build" and #positional == 1 and options.cache then
        local code, log = build(positional[1], options.cache, {target = options.target, real = options.real, pods = options.pods, log = options.log, deb = options.deb, engine = options.engine, swiftui = options.swiftui, backports = options.backports, shared = options.shared, jobs = options.jobs, configure_only = options["configure-only"]})
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
