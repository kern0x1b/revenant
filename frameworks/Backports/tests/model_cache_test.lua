local sdkfiles = import("sdk", {rootdir = path.join(os.scriptdir(), "..", "tools"), anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

local function sdk_at(folder)
    os.mkdir(path.join(folder, "System", "Library", "Frameworks"))
    io.writefile(path.join(folder, "SDKSettings.json"), '{"Version": "26.2"}')
    return folder
end

function main()
    local base = workspace.fresh("model-cache-test")
    local real = sdk_at(path.join(base, "sdk"))
    local copy = sdk_at(path.join(base, "copy"))
    os.ln(real, path.join(base, "link"))

    local cache = sdkfiles.model_cache(real)
    local root = path.join(workspace.home(), "modcache") .. "/"
    assert(cache:startswith(root), "the module cache is not in the cache's modcache folder: " .. cache)
    assert(sdkfiles.model_cache(path.join(base, "link")) == cache, "a symlink to the same SDK gets another module cache")
    assert(sdkfiles.model_cache(copy) ~= cache, "two SDK folders share one module cache, so the modules built for one are read for the other")

    os.tryrm(base)
    print("MODEL_CACHE_TEST passed")
end
