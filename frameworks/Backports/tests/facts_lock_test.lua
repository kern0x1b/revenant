local runjobs = import("async.runjobs")
local tools = path.join(os.scriptdir(), "..", "tools")
local sdkfiles = import("sdk", {rootdir = tools, anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

local ROOT = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
local WORKER = path.join(os.scriptdir(), "facts_lock_worker.lua")
local NAMES = {"FixtureA", "FixtureB"}

local function fixture(folder)
    io.writefile(path.join(folder, "SDKSettings.json"), '{"Version": "99.9"}')
    for _, name in ipairs(NAMES) do
        local header = path.join(folder, "System", "Library", "Frameworks", name .. ".framework", "Headers", name .. ".h")
        os.mkdir(path.directory(header))
        io.writefile(header, "__attribute__((objc_root_class)) @interface " .. name .. "Root\n- (void)hello;\n@end\n")
    end
    return folder
end

function main()
    local base = workspace.fresh("facts-lock-test")
    local sdk = fixture(path.join(base, "sdk"))
    local version = sdkfiles.sdk_version(sdk)
    local logs = path.join(base, "logs")
    local cache = sdkfiles.cache_folder(sdk)
    local key = sdkfiles.cache_key(sdk)
    local root = sdkfiles.shared_root()
    local outputs = {path.join(base, "one.out"), path.join(base, "two.out")}
    local statuses = {}

    runjobs("facts-lock-test", function (index)
        local argv = {"l", "-P", ROOT, WORKER, sdk, version, logs, table.unpack(NAMES)}
        statuses[index] = os.execv(os.programfile(), argv, {stdout = outputs[index], stderr = outputs[index], try = true})
    end, {total = 2, comax = 2})

    for _, index in ipairs({1, 2}) do
        assert(statuses[index] == 0, "extraction " .. index .. " failed with " .. tostring(statuses[index]) .. ":\n" .. io.readfile(outputs[index]))
    end
    local text = io.readfile(outputs[1]) .. "\n" .. io.readfile(outputs[2])
    local extractions = 0
    for _ in text:gmatch("facts extraction") do
        extractions = extractions + 1
    end
    assert(extractions == 1, "expected exactly one process to extract the facts, got " .. extractions .. ":\n" .. text)
    for _, name in ipairs(NAMES) do
        local file = path.join(cache, name .. ".tsv")
        assert(os.isfile(file), name .. " has no facts file")
        local found = false
        for _, row in ipairs(sdkfiles.read_rows(file) or {}) do
            if row.kind == "class" and row.name == name .. "Root" then
                found = true
            end
        end
        assert(found, name .. " has no complete facts")
    end
    for _, file in ipairs(os.files(path.join(logs, "*.failed"))) do
        assert(false, "a failed marker was left behind: " .. file)
    end

    os.tryrm(base)
    os.tryrm(path.join(root, key))
    os.tryrm(path.join(root, key .. ".lock"))
    os.tryrm(path.join(root, key .. ".holder"))
    print("FACTS_LOCK_TEST passed")
end
