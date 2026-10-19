local files = import("files", {anonymous = true})
local json = import("core.base.json")

function discover(sdk)
    local file = path.join(sdk, "SDKSettings.json")
    local text = files.read_text(file)
    assert(text, "no SDKSettings.json in " .. sdk .. ": not an SDK folder")
    local settings = json.decode(text)
    assert(type(settings) == "table", "SDKSettings.json is not a JSON object: " .. file)
    assert(settings.CanonicalName and settings.CanonicalName ~= "", "no CanonicalName in " .. file)
    assert(settings.Version and settings.Version ~= "", "no Version in " .. file)
    assert(settings.DefaultDeploymentTarget, "no DefaultDeploymentTarget in " .. file)
    return {
        path = sdk,
        name = settings.CanonicalName,
        version = settings.Version,
        deployment = settings.DefaultDeploymentTarget,
        triple = "arm64e-apple-ios" .. settings.DefaultDeploymentTarget,
    }
end

function names(release)
    local cache = "cache-" .. release
    return {
        cache_dir = cache,
        surface = "sdk-" .. release .. "-surface.tsv",
        oracle_defaults = cache .. "/oracle-defaults.tsv",
        objc_parts = {"objc-" .. release .. "-part1.tsv.gz", "objc-" .. release .. "-part2.tsv.gz", "objc-" .. release .. "-part3.tsv.gz"},
        swift_interface = cache .. "/swiftinterface-" .. release .. ".tsv",
        ios_table = cache .. "/constants-" .. release .. ".tsv.gz",
        sdk_id = "sdk-" .. release .. "-headers",
        ios_value = "ios-" .. release .. "-cache",
    }
end
