local workspace = import("@addon.revenant.workspace", {anonymous = true})
local device = import("@addon.revenant.device", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))

local function first(pattern)
    local values = os.files(pattern)
    return values[1] or raise("no file matches %s", pattern)
end

local function answers(text)
    local found = {}
    for line in text:gmatch("[^\n]+") do
        local label, value = line:match("^(.-) => (.*)$")
        if label then
            found[label] = value
        end
    end
    return found
end

function main()
    local cache = os.getenv("REVENANT_CACHE") or raise("REVENANT_CACHE is unset")
    local packages = path.join(cache, "xmake-global", ".xmake", "packages")
    local sdk = os.dirs(path.join(packages, "i", "iphoneos-sdk", "26.2", "**", "Developer.app", "Contents", "Developer", "Platforms", "iPhoneOS.platform", "Developer", "SDKs", "iPhoneOS*.sdk"))[1]
    local clang = first(path.join(packages, "l", "llvm", "23.1.3", "**", "bin", "clang"))
    local linker = first(path.join(packages, "l", "ld64", "956.6", "**", "bin", "ld"))
    local ldid = first(path.join(packages, "l", "ldid", "2.1.5-procursus7+23.gaf86971", "**", "bin", "ldid"))
    local out = workspace.run("backports-tests", "FoundationBase64Device")
    local fixture = path.join(backports, "tests", "foundation_base64", "main.m")
    local category = path.join(backports, "src", "Foundation", "NSData+Base64.m")
    local libraries = path.join(backports, "..", "..", "build", "iphoneos", "armv7", "release")
    local oracle = path.join(out, "oracle")
    os.vrunv("xcrun", {"clang", "-fobjc-arc", "-framework", "Foundation", "-o", oracle, fixture})
    local expected = answers(os.iorunv(oracle))
    local variants = {
        {name = "release", sources = {fixture}, extra = {"-DREVENANT_RELEASE_PROBE", "-Wno-deprecated-declarations"}},
        {name = "category", sources = {fixture, category}, extra = {}},
        {name = "linked", sources = {fixture}, extra = {"-L", libraries, "-lFoundationBackports"}},
        {name = "linked_probe", sources = {fixture}, extra = {"-DREVENANT_RELEASE_PROBE", "-Wno-deprecated-declarations", "-L", libraries, "-lFoundationBackports"}},
    }
    local settings = device.bind(os.projectdir())
    local panics_before = device.run(settings, "find /Library/Logs/CrashReporter/Panics -type f -print 2>/dev/null", {capture = true})
    local results = {}
    for _, variant in ipairs(variants) do
        local binary = path.join(out, "foundation_base64_" .. variant.name)
        local arguments = {"-target", "armv7-apple-ios6.0", "-miphoneos-version-min=6.0", "-isysroot", sdk, "-Wall", "-Werror",
                           "-Wno-incompatible-sysroot", "-fobjc-arc", "-framework", "Foundation", "-lobjc", "-fuse-ld=" .. linker, "-Wl,-no_encryption"}
        table.join2(arguments, variant.extra)
        table.join2(arguments, {"-o", binary}, variant.sources)
        os.vrunv(clang, arguments)
        os.vrunv(ldid, {"-S", binary})
        local output = device.with_scratch(settings, "backports-base64-" .. variant.name, function (remote)
            device.copy(settings, binary, remote .. "/foundation_base64")
            return device.run(settings, "chmod 755 " .. remote .. "/foundation_base64 && " .. remote .. "/foundation_base64", {capture = true})
        end)
        results[variant.name] = output
        io.writefile(path.join(out, variant.name .. ".txt"), output)
    end
    local panics_after = device.run(settings, "find /Library/Logs/CrashReporter/Panics -type f -print 2>/dev/null", {capture = true})
    assert(panics_after == panics_before, "the phone's kernel panic inventory changed after the base64 fixtures")
    for _, name in ipairs({"release", "linked_probe"}) do
        print(name == "release" and "NSData answers, no Backports library linked:" or "NSData answers, libFoundationBackports linked:")
        for line in results[name]:gmatch("RESPONDS [^\n]+") do
            print("  " .. line)
        end
    end
    for line in results.linked_probe:gmatch("RESPONDS ([^\n]+)") do
        assert(line:find(" yes$"), "libFoundationBackports linked, and NSData does not answer: " .. line)
    end
    for line in results.release:gmatch("RESPONDS ([^\n]+)") do
        local selector = line:match("^(%S+)")
        local expected_answer = (selector == "base64Encoding" or selector == "initWithBase64Encoding:") and " yes$" or " no$"
        assert(line:find(expected_answer), "the iOS 6 release answers differently from what the fixture expects: " .. line)
    end
    local released = answers(results.release)
    local groups = {
        {"base64Encoding against macOS with no options", "^encode length %d+ options 0 string$"},
        {"initWithBase64Encoding: against macOS with options 0", "^decode '.*' options 0 string$"},
        {"initWithBase64Encoding: against macOS with NSDataBase64DecodingIgnoreUnknownCharacters", "^decode '.*' options 1 string$"},
    }
    for _, group in ipairs(groups) do
        local equal, different = 0, {}
        for label, value in pairs(released) do
            if label:match(group[2]) then
                if expected[label] == value then
                    equal = equal + 1
                else
                    table.insert(different, label)
                end
            end
        end
        table.sort(different)
        print(string.format("the release's %s: %d of %d answers equal", group[1], equal, equal + #different))
        for index, label in ipairs(different) do
            if index <= 12 then
                print(string.format("  %s: release %s, macOS %s", label, released[label], expected[label]))
            end
        end
    end
    for _, name in ipairs({"category", "linked"}) do
        local got = answers(results[name])
        local count, bad = 0, 0
        for label, value in pairs(expected) do
            count = count + 1
            if got[label] ~= value then
                bad = bad + 1
                if bad <= 10 then
                    print(string.format("  %s: %s gives %s, macOS %s", label, name, got[label], value))
                end
            end
        end
        assert(bad == 0, string.format("%d of %d answers of the %s fixture differ from macOS", bad, count, name))
        assert(results[name]:find("OUTSIDE_THE_SYSTEM 4", 1, true), "the four selectors are not implemented outside the system in the " .. name .. " fixture")
        print(string.format("%s: %d answers equal to macOS on the iPhone 4S", name, count))
    end
end
