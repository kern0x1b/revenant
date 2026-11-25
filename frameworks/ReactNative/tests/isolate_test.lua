local ROOT = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
local TOOLS = path.join(ROOT, "frameworks", "ReactNative", "tools")

local workspace = import("@addon.revenant.workspace", {anonymous = true})
local isolate = import("isolate", {rootdir = TOOLS, anonymous = true})
local patch_wire = import("patch_wire", {rootdir = TOOLS, anonymous = true})
local module_build = import("module_build", {rootdir = TOOLS, anonymous = true})

local function expect(name, condition, detail)
    if not condition then
        raise("%s: %s", name, detail)
    end
    print(name .. ": passes")
end

local function refusal(check)
    local message
    try { check, catch { function (errors) message = tostring(errors) end } }
    return message
end

local SWIFT = 'add_requires("revenant@swift-runtime", {alias = "swift-runtime", configs = {shared = true}})'
local LIBCXX = 'add_requires("revenant@libcxx", {alias = "libcxx", configs = {packaged = true}})'
local LIBCXX_DEPS = 'add_requireconfs("**.libcxx", {configs = {packaged = true}})'
local WEBKIT = 'add_requires("webkit-engine", {alias = "webkit-engine-prefixed", configs = {variant = "prefixed"}})'

local APPLICATION = table.concat({
    'set_project("example-host")',
    'if not os.getenv("RN_ONLY") or os.getenv("RN_EXPO") then',
    '    add_requires("revenant@swift-runtime", {alias = "swift-runtime"})',
    'end',
    'add_requires("revenant@libcxx", {alias = "libcxx"})',
    'includes("@addon/revenant/apple-ios")',
    ""
}, "\n")

local COMPONENT = 'option("component", {type = "string", default = "", showmenu = true, description = "Configure only this component and what it needs, for example Backports or emulator; empty configures every component."})'
local COMBINE = 'add_requireconfs("combine", {override = true, configs = {shared = get_config("component") == "" or nil}})'

local ROOT_TEXT = table.concat({SWIFT, LIBCXX, LIBCXX_DEPS, WEBKIT, COMPONENT, COMBINE, ""}, "\n")

local CARRIED = table.concat({SWIFT, LIBCXX, LIBCXX_DEPS,
    'add_requires("webkit-engine", {alias = "webkit-engine-prefixed", configs = {variant = "prefixed", carried = "jsc"}})', ""}, "\n")

local whole = isolate.whole_requirements(APPLICATION)

expect("a plain application gets the whole requirements", #isolate.whole_missing(whole) == 0,
       "whole_missing still lists " .. #isolate.whole_missing(whole) .. " requirements after the copy carried them")
expect("the plain swift-runtime and libcxx lines are replaced", not whole:find('{alias = "swift-runtime"})', 1, true)
       and not whole:find('{alias = "libcxx"})', 1, true), "a plain requirement survives")
expect("the replaced swift-runtime keeps its condition", whole:find('if not os.getenv("RN_ONLY")', 1, true) ~= nil and whole:find(SWIFT, 1, true) ~= nil,
       "the condition or the shared swift-runtime is missing")
expect("the whole requirements are carried once", isolate.whole_requirements(whole) == whole, "a second copy changed the text")
expect("the copy declares the component option and the combine rule", whole:find('option("component"', 1, true) ~= nil and whole:find(COMBINE, 1, true) ~= nil,
       "the component option or the combine requireconf is missing from the copy")
expect("a plain application lacks all six whole requirements", #isolate.whole_missing(APPLICATION) == 6,
       "expected 6 missing, found " .. #isolate.whole_missing(APPLICATION))
local pods = isolate.pod_requirements(whole)
expect("the image and camera libraries are required only when a module that uses them is real",
       pods:find('if (",".. (os.getenv("RN_EXPO_REAL") or "") .. ","):find(",expo-image,", 1, true) or (",".. (os.getenv("RN_EXPO_REAL") or "") .. ","):find(",expo-image-manipulator,", 1, true) then add_requires("revenant@sdwebimage 5.21.7", {alias = "sdwebimage"}) end', 1, true) ~= nil
       and pods:find(',expo-camera,", 1, true) then add_requires("revenant@zxingobjc 3.6.4", {alias = "zxingobjc"}) end', 1, true) ~= nil
       and isolate.pod_requirements(pods) == pods and #isolate.whole_missing(pods) == 0,
       "the SDWebImage or ZXingObjC requirement is missing, not conditional on its modules or carried twice")
expect("the root's own declarations are already whole", #isolate.whole_missing(ROOT_TEXT) == 0 and isolate.whole_requirements(ROOT_TEXT) == ROOT_TEXT,
       "the root's text is rewritten or reported missing")
local carried = isolate.whole_requirements(CARRIED)
expect("a webkit-engine that RN_WEBKIT declares keeps its own line, and the whole one is added unless RN_WEBKIT is set", #isolate.whole_missing(CARRIED) == 3
       and #isolate.whole_missing(carried) == 0 and carried:find('if not os.getenv("RN_WEBKIT") and not os.getenv("RN_HERMES") then add_requires("webkit-engine"', 1, true) ~= nil
       and isolate.whole_requirements(carried) == carried, "the RN_WEBKIT line is not kept beside the whole one, or a second pass changes the copy")

local OTHER = 'add_requires("revenant@swift-runtime", {alias = "swift-runtime", configs = {shared = false}})\n'
local message = refusal(function () isolate.whole_requirements(OTHER) end)
expect("a swift-runtime with other configs is refused", message ~= nil and message:find("swift%-runtime") ~= nil,
       "the copy was rewritten or the refusal does not name swift-runtime")

local shared = isolate.shared_packages(APPLICATION)
local missing = {}
for _, name in ipairs({"swiftui", "cryptokit", "uniformtypeidentifiers", "swift-crypto"}) do
    for _, pattern in ipairs({name, "**." .. name}) do
        local line = 'add_requireconfs("' .. pattern .. '", {configs = {shared = true, apple_sdk = get_config("apple_sdk")}})'
        if not shared:find(line, 1, true) then
            table.insert(missing, pattern)
        end
    end
end
expect("the copy asks the four packages, as the application requires them and as its dependants do, for a shared swift-runtime and keeps the SDK",
       #missing == 0, "no shared rule for " .. table.concat(missing, ", "))
expect("the shared rules are carried once", isolate.shared_packages(shared) == shared, "a second pass changed the copy")

local embedding = isolate.host_embed(APPLICATION)
expect("an embedding copy names the Swift packages that its host carries", embedding:find('set_values("revenant.embed", "swift-runtime", "swift-crypto", "cryptokit", "uniformtypeidentifiers")', 1, true) ~= nil
       and not embedding:find('"libcxx", "swift', 1, true), "the revenant.embed values are missing from the copy")
expect("the embedding rule is carried once", isolate.host_embed(embedding) == embedding, "a second pass changed the copy")

local hosted = isolate.host_libcxx(APPLICATION)
expect("the copy's host no longer carries the libc++ the shared package installs", hosted:find('target("RNHost")', 1, true) ~= nil
       and hosted:find('name ~= "libcxx"', 1, true) ~= nil, "the app.frameworks filter is missing from the copy")
expect("the host rule is carried once", isolate.host_libcxx(hosted) == hosted, "a second pass changed the copy")

local base = workspace.fresh("rn-isolate-cloning")
local old_checkout, old_cache, old_folder = path.join(base, "old", "checkout"), path.join(base, "old", "checkout", ".cache-pp"), path.join(base, "old", "checkout", "iso-x")
local new_cache, new_folder = path.join(base, "new", ".cache-pp"), path.join(base, "new", "iso-y")
os.mkdir(path.join(old_cache, "pkg", "x"))
os.mkdir(path.join(old_cache, "pkg", "rn", "src", "React"))
io.writefile(path.join(old_cache, "pkg", "rn", "src", "React", "a.h"), "// a header\n")
os.mkdir(path.join(old_folder, "build", "pkg-probe-x"))
os.mkdir(path.join(old_folder, "build", "rn-headers", "React"))
os.mkdir(path.join(base, "app"))
io.writefile(path.join(old_folder, "build", "pkg-probe-x", "xmake.lua"), isolate.recipe_probe_text(old_checkout, "x", "1"))
io.writefile(path.join(old_folder, "build", "pkg-probe-x", "installdir.txt"), path.join(old_cache, "pkg", "x") .. "\n")
io.writefile(path.join(old_folder, "build", "isolate-roots.txt"), table.concat({old_folder, old_checkout, old_cache}, "\n") .. "\n")
io.writefile(path.join(old_folder, "xmake.lua"), 'set_project("example-host")\n-- built in ' .. old_folder .. " from " .. old_checkout .. "\n")
os.vrunv("ln", {"-sfn", path.join(old_cache, "pkg", "rn", "src"), path.join(old_folder, "build", "rn-src")})
os.vrunv("ln", {"-sfn", path.join(old_folder, "build", "rn-src", "React", "a.h"), path.join(old_folder, "build", "rn-headers", "React", "a.h")})
os.vrunv("ln", {"-sfn", path.join(base, "app"), path.join(old_folder, "build", "ref")})
os.mkdir(path.directory(new_cache))
os.vrunv("cp", {"-cR", old_cache, new_cache})

local cloned = isolate.clone_project(path.join(base, "old", "..", "old", "checkout", "iso-x"), new_folder, path.join(base, "new", "x", "..", ".cache-pp"),
    path.join(old_cache, "..", ".cache-pp"), path.join(base, "old", "x", "..", "checkout"))
local function naming(root)
    local found = try { function () return os.iorunv("grep", {"-rIlF", "--exclude-dir=ref", root, new_folder}) end, catch { function () return "" end } }
    return found or ""
end
expect("a clone names none of the old roots in its text files", naming(old_folder) == "" and naming(old_checkout) == "" and naming(old_cache) == "",
       "the clone still names the old copy, checkout or cache: " .. naming(old_checkout) .. naming(old_folder))
local rn_src = os.iorunv("readlink", {path.join(new_folder, "build", "rn-src")}):trim()
local header = os.iorunv("readlink", {path.join(new_folder, "build", "rn-headers", "React", "a.h")}):trim()
expect("the rn-src link of a clone points into its own cache and the rn-headers links into its own rn-src", rn_src == path.join(new_cache, "pkg", "rn", "src")
       and header == path.join(new_folder, "build", "rn-src", "React", "a.h") and io.readfile(path.join(new_folder, "build", "rn-headers", "React", "a.h")) == "// a header\n",
       "rn-src is " .. rn_src .. " and the header link is " .. header)
local here = path.absolute(os.projectdir())
local answer = isolate.reusable_answer(path.join(new_folder, "build", "pkg-probe-x"), isolate.recipe_probe_text(here, "x", "1"), path.join(base, "no-recipe"))
expect("a clone's probes answer from their recorded install folders without installing again", answer == path.join(new_cache, "pkg", "x"),
       "the probe answered " .. tostring(answer))
expect("a clone leaves the copy it came from as it was", io.readfile(path.join(old_folder, "build", "pkg-probe-x", "xmake.lua")):find(old_checkout, 1, true) ~= nil
       and os.iorunv("readlink", {path.join(old_folder, "build", "rn-src")}):trim() == path.join(old_cache, "pkg", "rn", "src"), "the old copy was changed")
expect("a clone records its own roots", isolate.read_roots(new_folder).folder == new_folder and isolate.read_roots(new_folder).cache == new_cache
       and isolate.read_roots(new_folder).checkout == here, "the roots file of the clone is wrong")
expect("a clone refuses an existing folder", refusal(function () isolate.clone_project(old_folder, new_folder, new_cache) end) ~= nil, "an existing folder was overwritten")
expect("a clone counts what it rewrote", cloned.rewritten >= 3 and cloned.relinked == 2, cloned.rewritten .. " files, " .. cloned.relinked .. " links")
os.rm(base)
local function build_status(code)
    local ran
    local status = module_build.run("folder", "cache", "expo-x", function (_, args)
        ran = table.concat(args, " ")
        return code
    end)
    return status, ran
end
local failed, command = build_status(3)
expect("module_build returns the status of a failed build", failed == 3, "the status was " .. tostring(failed))
expect("module_build returns 0 for a build that passed", build_status(0) == 0, "a passed build was reported as failed")
expect("module_build builds the base modules and the extra ones", command:find("expo-print,expo-x", 1, true) ~= nil, command)
local recipe = '    add_versions("1.0", "aa")\n    add_patches("1.0", path.join(os.scriptdir(), "patches", "x-ios6.patch"), "11")\n'
local once = patch_wire.register(recipe, "1.0", "x-ios6.patch", "22")
local twice = patch_wire.register(once, "1.0", "x-ios6.patch", "33")
local _, count = twice:gsub("add_patches", "")
expect("patch_wire replaces the registration of a patch whose name has a dash and does not add a second one", count == 1 and twice:find('"33"', 1, true) ~= nil and twice:find('"11"', 1, true) == nil,
       twice)
local fixture = workspace.fresh("rn-closure-fixture")
os.mkdir(path.join(fixture, "frameworks", "ReactNative", "src"))
io.writefile(path.join(fixture, "frameworks", "ReactNative", "src", "coverage.json"), '{"rows": [{"id": "expo-a"}, {"id": "pod-b"}, {"id": "pod-c"}]}')
for name, deps in pairs({["expo-a"] = 'add_deps("pod-b", "swift-runtime")', ["pod-b"] = 'add_deps("pod-c")', ["pod-c"] = 'add_deps("pod-b")'}) do
    os.mkdir(path.join(fixture, "packages", name:sub(1, 1), name))
    io.writefile(path.join(fixture, "packages", name:sub(1, 1), name, "xmake.lua"), 'package("' .. name .. '")\n    ' .. deps .. '\n')
end
local closed = module_build.closure(fixture, {"expo-a"})
expect("module_build closes a package list over the add_deps of the recipes that are coverage rows, once each", table.concat(closed, ",") == "expo-a,pod-b,pod-c", table.concat(closed, ","))
os.tryrm(fixture)

local keyed = workspace.fresh("rn-config-key")
os.mkdir(path.join(keyed, "build"))
io.writefile(path.join(keyed, "xmake.lua"), "set_project('a')\n")
local env = {A = "1", B = "2"}
local key = isolate.config_key(keyed, env, "tree")
expect("a configuration key is the same for the same inputs", key == isolate.config_key(keyed, {B = "2", A = "1"}, "tree"), "the key depends on the order of the environment")
expect("a configuration key changes with the environment", key ~= isolate.config_key(keyed, {A = "1", B = "3"}, "tree"), "an environment change kept the key")
expect("a configuration key changes with the checkout state", key ~= isolate.config_key(keyed, env, "other"), "a checkout change kept the key")
io.writefile(path.join(keyed, "xmake.lua"), "set_project('b')\n")
expect("a configuration key changes with the project's xmake.lua", key ~= isolate.config_key(keyed, env, "tree"), "a project change kept the key")
io.writefile(path.join(keyed, "xmake.lua"), "set_project('a')\n")
io.writefile(path.join(keyed, "build", "config-key"), key .. "\n")
expect("a folder with no .xmake is configured again", not isolate.configured_before(keyed, key), "a folder without configuration counted as configured")
os.mkdir(path.join(keyed, ".xmake"))
expect("a folder configured with the same key is not configured again", isolate.configured_before(keyed, key), "the recorded key was not recognised")
expect("a folder configured with another key is configured again", not isolate.configured_before(keyed, isolate.config_key(keyed, env, "other")), "a stale key was accepted")
os.tryrm(keyed)

local tree = workspace.fresh("rn-config-tree")
os.mkdir(path.join(tree, "frameworks", "X"))
local function git(...) return os.iorunv("git", table.join({"-C", tree}, {...})) end
git("init", "-q")
io.writefile(path.join(tree, "frameworks", "X", "xmake.lua"), "target('x')\n")
io.writefile(path.join(tree, "frameworks", "X", "a.swift"), "let a = 1\n")
local before = isolate.checkout_state(tree)
io.writefile(path.join(tree, "frameworks", "X", "a.swift"), "let a = 2\n")
expect("editing a source file does not change the checkout's configuration state", isolate.checkout_state(tree) == before, "a source edit changed the state")
git("add", "-A")
git("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "c")
expect("committing does not change the checkout's configuration state", isolate.checkout_state(tree) == before, "a commit changed the state")
io.writefile(path.join(tree, "frameworks", "X", "xmake.lua"), "target('y')\n")
local edited = isolate.checkout_state(tree)
expect("editing a build file changes the checkout's configuration state", edited ~= before, "a recipe edit kept the state")
io.writefile(path.join(tree, "frameworks", "X", "b.swift"), "let b = 1\n")
expect("adding a source file changes the checkout's configuration state", isolate.checkout_state(tree) ~= edited, "a new file kept the state")
os.tryrm(tree)

local ambient_dir = workspace.fresh("rn-config-ambient")
io.writefile(path.join(ambient_dir, "xmake.lua"), "set_project('a')\n")
local aenv = {A = "1"}
local base_key = isolate.config_key(ambient_dir, aenv, "tree", {DEVELOPER_DIR = "/Xcode-1"})
expect("a configuration key changes with an inherited variable", base_key ~= isolate.config_key(ambient_dir, aenv, "tree", {DEVELOPER_DIR = "/Xcode-2"}), "another DEVELOPER_DIR kept the key")
expect("a configuration key is the same for the same inherited variables", base_key == isolate.config_key(ambient_dir, aenv, "tree", {DEVELOPER_DIR = "/Xcode-1"}), "the same inherited variables changed the key")
expect("an explicit variable wins over the inherited one in the key", isolate.config_key(ambient_dir, {DEVELOPER_DIR = "/x"}, "tree", {DEVELOPER_DIR = "/Xcode-1"}) == isolate.config_key(ambient_dir, {DEVELOPER_DIR = "/x"}, "tree", {DEVELOPER_DIR = "/Xcode-2"}), "an inherited value reached the key past an explicit one")
local saved = os.getenv("DEVELOPER_DIR")
os.setenv("DEVELOPER_DIR", "/Xcode-A")
local first = isolate.config_key(ambient_dir, aenv, "tree")
os.setenv("DEVELOPER_DIR", "/Xcode-B")
local second = isolate.config_key(ambient_dir, aenv, "tree")
os.setenv("DEVELOPER_DIR", saved or "")
expect("changing DEVELOPER_DIR changes the key a build computes, so xmake f -c runs", first ~= second, "the key ignored DEVELOPER_DIR")
os.setenv("XMAKE_RN_PROBE", "1")
local with_switch = isolate.ambient_environment().XMAKE_RN_PROBE
os.setenv("XMAKE_RN_PROBE", "")
expect("an XMAKE_ variable is part of the inherited environment of the key", with_switch == "1", "XMAKE_RN_PROBE was not read")
os.tryrm(ambient_dir)

local libraries = import("backports_libraries", {rootdir = TOOLS, anonymous = true})
local own = 'add_requires("revenant@backports", {alias = "backports", configs = {libraries = "FoundationBackports,UIKitBackports,MyOwnBackports"}})\n'
expect("the libraries of an application's backports requirement are read from its xmake.lua", table.concat(libraries.declared(own), ",") == "FoundationBackports,UIKitBackports,MyOwnBackports", "the list was not read")
expect("an application with another set keeps its own list and is checked against what the host links", table.concat(libraries.missing(libraries.declared(own), {"FoundationBackports", "MyOwnBackports"}), ",") == "", "an own library was reported missing")
expect("a library the host links and the application lacks is named", table.concat(libraries.missing(libraries.declared(own)), ","):find("CoreTextBackports", 1, true) ~= nil, "a missing host library was not named")
expect("an xmake.lua with no list is not read as one", libraries.declared('add_requires("revenant@backports")\n') == nil, "a requirement without libraries gave a list")

local gapped = workspace.fresh("rn-ref-gap")
os.mkdir(path.join(gapped, "build", "ref"))
os.execv("ln", {"-s", path.join(gapped, "nowhere"), path.join(gapped, "build", "ref", "app")})
local gap = isolate.reference_gap(gapped)
expect("a project whose reference application is gone is refused with how to restore it", gap ~= nil and gap:find("npm ci", 1, true) ~= nil and gap:find("reference/paseo", 1, true) ~= nil, tostring(gap))
os.mkdir(path.join(gapped, "nowhere"))
expect("a project whose reference application is there is not refused", isolate.reference_gap(gapped) == nil, "a present reference was refused")
os.tryrm(gapped)

local slices_dir = workspace.fresh("rn-config-masked")
io.writefile(path.join(slices_dir, "xmake.lua"), "set_project('a')\n")
local slices_saved = os.getenv("REVENANT_SLICES")
os.setenv("REVENANT_SLICES", "armv7")
local with_slices = isolate.config_key(slices_dir, {A = "1"}, "tree")
os.setenv("REVENANT_SLICES", "arm64")
local other_slices = isolate.config_key(slices_dir, {A = "1"}, "tree")
os.setenv("REVENANT_SLICES", slices_saved or "")
expect("a build that differs only in REVENANT_SLICES gets another configuration key", with_slices ~= other_slices, "REVENANT_SLICES did not reach the key")
local device_saved = os.getenv("REVENANT_DEVICE_HOLDER")
os.setenv("REVENANT_DEVICE_HOLDER", "one")
local held_one = isolate.config_key(slices_dir, {A = "1"}, "tree")
os.setenv("REVENANT_DEVICE_HOLDER", "two")
local held_two = isolate.config_key(slices_dir, {A = "1"}, "tree")
os.setenv("REVENANT_DEVICE_HOLDER", device_saved or "")
expect("the phone claim's variables do not change the configuration key", held_one == held_two, "REVENANT_DEVICE_HOLDER reached the key")
os.setenv("REVENANT_RN_PROBE_EMPTY", "")
expect("an empty REVENANT_ variable is not part of the key", isolate.ambient_environment().REVENANT_RN_PROBE_EMPTY == nil, "an empty variable was read")
os.tryrm(slices_dir)
