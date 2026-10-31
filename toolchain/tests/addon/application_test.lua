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

function failures(opt)
    local platform = import("apple.platform", {rootdir = opt.modules, anonymous = true})
    local found = {}
    duplicates_step(platform, opt, found)
    differing_step(platform, opt, found)
    return found
end
