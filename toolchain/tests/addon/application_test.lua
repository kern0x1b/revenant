import("fixtures")

local DARWIN = [[
static int hidden(void) { return %d; }
int (*const table[])(void) = { hidden };
int darwin_value(void) { return table[0](); }
]]

local function package(name, installdir)
    return {name = function () return name end, installdir = function () return installdir end,
            envs = function () return {} end}
end

local function application_target(folder, frameworks, packages, executable)
    local values = {["app.frameworks"] = frameworks}
    return {
        name = function () return "App" end,
        basename = function () return "App" end,
        targetdir = function () return folder end,
        targetfile = function () return executable end,
        scriptdir = function () return folder end,
        arch = function () return "armv7" end,
        values = function (_, key) return values[key] end,
        pkg = function (_, name) return packages[name] end,
        dep = function () return nil end,
        orderdeps = function () return {} end,
        toolchain = function () return {load = function () end, config = function () return "6.0" end} end
    }
end

local function packages_of(opt, folder, cryptokit_darwin)
    local runtime = path.join(folder, "swift-runtime", "lib")
    local cryptokit = path.join(folder, "cryptokit", "lib")
    os.mkdir(runtime)
    os.mkdir(cryptokit)
    io.writefile(path.join(folder, "libSystem.tbd"), fixtures.system_stub())
    io.writefile(path.join(folder, "darwin.c"), DARWIN:format(1))
    fixtures.link(folder, opt.ld64, path.join(runtime, "libswiftDarwin.dylib"), "armv7-apple-ios6.0", "darwin.c",
                  {"-dynamiclib", "-fPIC", "-install_name", "@rpath/libswiftDarwin.dylib"})
    io.writefile(path.join(folder, "darwin-cryptokit.c"), DARWIN:format(cryptokit_darwin))
    fixtures.link(folder, opt.ld64, path.join(cryptokit, "libswiftDarwin.dylib"), "armv7-apple-ios6.0", "darwin-cryptokit.c",
                  {"-dynamiclib", "-fPIC", "-install_name", "@rpath/libswiftDarwin.dylib"})
    io.writefile(path.join(folder, "crypto.c"), "extern int darwin_value(void);\nint crypto_value(void) { return darwin_value(); }\n")
    fixtures.link(folder, opt.ld64, path.join(cryptokit, "libswiftCryptoKit.dylib"), "armv7-apple-ios6.0", "crypto.c",
                  {"-dynamiclib", "-install_name", "@rpath/libswiftCryptoKit.dylib", "-L" .. runtime, "-lswiftDarwin"})
    io.writefile(path.join(folder, "main.c"), "int main(void) { return 0; }\n")
    local executable = fixtures.link(folder, opt.ld64, "App", "armv7-apple-ios6.0", "main.c", {})
    local ldid = opt.ldid
    return {
        ["swift-runtime"] = package("swift-runtime", path.join(folder, "swift-runtime")),
        cryptokit = package("cryptokit", path.join(folder, "cryptokit")),
        ldid = package("ldid", path.directory(path.directory(ldid)))
    }, executable
end

local function slice_only(action)
    local previous = os.getenv("REVENANT_SLICE")
    os.setenv("REVENANT_SLICE", "1")
    local refused = fixtures.refusal(action)
    os.setenv("REVENANT_SLICE", previous)
    return refused
end

local function duplicates_step(platform, opt, found)
    local folder = fixtures.scratch()
    local packages, executable = packages_of(opt, folder, 1)
    local app = application_target(path.join(folder, "target"), {"swift-runtime", "cryptokit"}, packages, executable)
    os.mkdir(app:targetdir())
    local refused = slice_only(function () platform.application(app) end)
    if refused then
        table.insert(found, "an app that carries the same library from two packages, with one copy, must bundle: " .. refused)
        return
    end
    local frameworks = path.join(app:targetdir(), "App.app", "Frameworks")
    local listed = os.files(path.join(frameworks, "*.dylib"))
    local names = {}
    for _, file in ipairs(listed) do
        table.insert(names, path.filename(file))
    end
    table.sort(names)
    if table.concat(names, " ") ~= "libswiftCryptoKit.dylib libswiftDarwin.dylib" then
        table.insert(found, "the app must carry each destination once, got: " .. table.concat(names, " "))
    end
end

local function differing_step(platform, opt, found)
    local folder = fixtures.scratch()
    local packages, executable = packages_of(opt, folder, 2)
    local app = application_target(path.join(folder, "target"), {"swift-runtime", "cryptokit"}, packages, executable)
    os.mkdir(app:targetdir())
    local refused = slice_only(function () platform.application(app) end) or ""
    if not refused:find("libswiftDarwin.dylib", 1, true) or not refused:find("swift-runtime", 1, true) or not refused:find("cryptokit", 1, true) then
        table.insert(found, "two packages that carry differing copies of one library must be refused, naming both packages: " .. refused)
    end
end

local function staged_package(shared, folder, alias, name, library, needs)
    local installdir = path.join(folder, alias)
    shared.stage({packages = {{name = name, version = "1.0+11111111", title = alias, description = "A library of " .. alias,
                               libraries = library}},
                  root = path.join(installdir, "share", "root"), metadata = path.join(installdir, "share", "shared-packages"), strip = {"-x"}})
    local found = package(alias, installdir)
    found.envs = function () return {REVENANT_SHARED_PACKAGE = needs and (name .. "=" .. needs) or name} end
    return found, path.join(installdir, "share", "root", "usr", "lib", "revenant", name)
end

local function embed_step(platform, opt, found)
    local shared = import("apple.shared_runtime", {rootdir = opt.modules, anonymous = true})
    local folder = fixtures.scratch()
    io.writefile(path.join(folder, "libSystem.tbd"), fixtures.system_stub())
    local function library(leaf, source, extra)
        io.writefile(path.join(folder, leaf .. ".c"), source)
        return fixtures.link(folder, opt.ld64, "lib" .. leaf .. ".dylib", "armv7-apple-ios6.0", leaf .. ".c",
                             table.join({"-dynamiclib", "-install_name", "@rpath/lib" .. leaf .. ".dylib"}, extra or {}))
    end
    local base = library("base", "int base(void) { return 1; }\n")
    local unused = library("unused", "int unused(void) { return 2; }\n")
    local top = library("top", "extern int base(void);\nint top(void) { return base(); }\n", {"-L.", "-lbase"})
    local kept = library("kept", "int kept(void) { return 3; }\n")
    local first, second, third = "org.example.base-11111111", "org.example.top-11111111", "org.example.kept-11111111"
    local runtime, runtime_folder = staged_package(shared, folder, "swift-runtime", first, {base, unused})
    local cryptokit, cryptokit_folder = staged_package(shared, folder, "cryptokit", second, {top, base}, first)
    os.rm(path.join(cryptokit_folder, "libbase.dylib"))
    local types, types_folder = staged_package(shared, folder, "uniformtypeidentifiers", third, {kept})
    os.vrunv("xcrun", {"install_name_tool", "-change", "/usr/lib/revenant/" .. second .. "/libbase.dylib",
                       "/usr/lib/revenant/" .. first .. "/libbase.dylib", path.join(cryptokit_folder, "libtop.dylib")})

    local carrier = path.join(folder, "carrier")
    os.mkdir(path.join(carrier, "lib"))
    io.writefile(path.join(folder, "other.c"), "int base(void) { return 9; }\n")
    fixtures.link(folder, opt.ld64, path.join(carrier, "lib", "libbase.dylib"), "armv7-apple-ios6.0", "other.c",
                  {"-dynamiclib", "-install_name", "@rpath/libbase.dylib"})

    io.writefile(path.join(folder, "main.c"), "extern int top(void);\nextern int kept(void);\nint main(void) { return top() + kept(); }\n")
    local executable = fixtures.link(folder, opt.ld64, "App", "armv7-apple-ios6.0", "main.c",
                                     {path.join(cryptokit_folder, "libtop.dylib"), path.join(types_folder, "libkept.dylib")})
    local packages = {["swift-runtime"] = runtime, cryptokit = cryptokit, uniformtypeidentifiers = types,
                      carrier = package("carrier", carrier), ldid = package("ldid", path.directory(path.directory(opt.ldid)))}
    local app = application_target(path.join(folder, "target"), {"carrier"}, packages, executable)
    local declared = {["app.frameworks"] = {"carrier"}, ["revenant.embed"] = {"swift-runtime", "cryptokit"}}
    app.values = function (_, key) return declared[key] end
    os.mkdir(app:targetdir())
    local refused = slice_only(function () platform.application(app) end)
    if refused then
        table.insert(found, "an app that embeds two shared packages must bundle: " .. refused)
        return
    end

    local bundled = path.join(app:targetdir(), "App.app")
    local names = {}
    for _, file in ipairs(os.files(path.join(bundled, "Frameworks", "*.dylib"))) do
        table.insert(names, path.filename(file))
    end
    table.sort(names)
    if table.concat(names, " ") ~= "libbase.dylib libtop.dylib" then
        table.insert(found, "an app carries the embedded libraries it reaches and no other, got: " .. table.concat(names, " "))
        return
    end
    local function listing(flag, file)
        return fixtures.run(folder, "xcrun", {"otool", flag, file})
    end
    local copy_of_base = path.join(bundled, "Frameworks", "libbase.dylib")
    local copy_of_top = path.join(bundled, "Frameworks", "libtop.dylib")
    local linked = listing("-L", path.join(bundled, "App"))
    if not linked:find("@executable_path/Frameworks/libtop.dylib", 1, true) or
       not linked:find("/usr/lib/revenant/" .. third .. "/libkept.dylib", 1, true) or linked:find(second, 1, true) then
        table.insert(found, "the app must load an embedded library from its Frameworks and a kept one from the device: " .. linked)
    end
    local reached = listing("-L", copy_of_top)
    if not reached:find("@executable_path/Frameworks/libbase.dylib", 1, true) or reached:find("/usr/lib/revenant/", 1, true) then
        table.insert(found, "one embedded library must load another from Frameworks: " .. reached)
    end
    if not listing("-D", copy_of_base):find("@executable_path/Frameworks/libbase.dylib", 1, true) then
        table.insert(found, "an embedded copy must be named by its place in Frameworks")
    end
    if not listing("-tV", copy_of_base):find("_base", 1, true) or listing("-tV", copy_of_base):find("#0x9", 1, true) then
        table.insert(found, "the embedded copy replaces a carried library of the same name")
    end
    for _, file in ipairs({copy_of_base, copy_of_top}) do
        local again = path.join(folder, "resigned", path.filename(file))
        os.mkdir(path.directory(again))
        os.cp(file, again)
        os.vrunv(opt.ldid, {"-S", again})
        if not listing("-l", file):find("LC_CODE_SIGNATURE", 1, true) or hash.sha256(file) ~= hash.sha256(again) then
            table.insert(found, "an embedded copy must carry the signature of its final bytes: " .. path.filename(file))
        end
    end
    local provided = {}
    for _, file in ipairs(platform.provided_libraries(app)) do
        table.insert(provided, path.filename(file))
    end
    if table.concat(provided, " ") ~= "libkept.dylib" then
        table.insert(found, "what an app embeds is not provided to the import check, and what stays on the device is, got: " .. table.concat(provided, " "))
    end
end

function failures(opt)
    local platform = import("apple.platform", {rootdir = opt.modules, anonymous = true})
    local found = {}
    duplicates_step(platform, opt, found)
    differing_step(platform, opt, found)
    embed_step(platform, opt, found)
    return found
end
