local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})

local SKIPPED = {"*.png", "*.plist", "*.nib", "*.car", "*.json", "*.strings"}

local function checkout()
    local named = os.getenv("CHARON_ROOT_DIR")
    if named and named ~= "" and os.isdir(path.join(named, "modules")) then
        return named
    end
    return workspace.root()
end

local function binaries(app)
    local argv = {app, "-type", "f"}
    for _, pattern in ipairs(SKIPPED) do
        table.join2(argv, {"!", "-name", pattern})
    end
    local scratch = workspace.fresh("scan-app")
    local listing = path.join(scratch, "files.txt")
    os.execv("find", argv, {stdout = listing, stderr = os.nuldev(), try = true})
    local listed = io.readfile(listing)
    os.tryrm(scratch)
    local found = {}
    for file in listed:gmatch("[^\n]+") do
        local kind = try {function () return os.iorunv("file", {file}) end} or ""
        if kind:find("Mach-O", 1, true) then
            table.insert(found, file)
        end
    end
    return found
end

function main(name, app)
    if not name or not app then
        raise("usage: xmake l tools/corpus/scan-app.lua <app-name> <path-to-.app>")
    end
    local corpus = workspace.corpus()
    local root = checkout()
    local out = path.join(corpus, name .. ".scan.tsv")
    local errors = path.join(corpus, name .. ".scan.err")
    local bins = binaries(app)
    print(string.format("[%s] %d Mach-O binaries under bundle", name, #bins))
    local argv = {"l", path.join(os.scriptdir(), "corpus-scan.lua"), "6.0"}
    table.join2(argv, bins)
    local status = os.execv(os.programfile(), argv, {stdout = out, stderr = errors, envs = {CHARON_ROOT = root}, try = true})
    if status ~= 0 then
        print("scan failed; see " .. errors)
        local lines = {}
        for line in io.lines(errors) do
            table.insert(lines, line)
        end
        for i = math.max(1, #lines - 9), #lines do
            print(lines[i])
        end
        os.exit(1)
    end
    os.execv(os.programfile(), {"l", path.join(os.scriptdir(), "aggregate.lua"), "ingest", name, app})
end
