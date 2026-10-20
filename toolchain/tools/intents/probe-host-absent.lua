import("core.base.json")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

local USAGE = "usage: xmake l tools/intents/probe-host-absent.lua [--work <dir>] [--out <file>] [registry-file ...]"

local function options_of(arguments)
    local options = {files = {}}
    local index = 1
    while index <= #arguments do
        local key = arguments[index]:match("^%-%-(.+)$")
        if key == "work" or key == "out" then
            if arguments[index + 1] == nil then
                raise(USAGE)
            end
            options[key] = arguments[index + 1]
            index = index + 2
        elseif key then
            raise(USAGE)
        else
            table.insert(options.files, arguments[index])
            index = index + 1
        end
    end
    return options
end

local function rows_of(file)
    local document = json.decode(io.readfile(file))
    local entries
    if type(document) ~= "table" then
        return {}
    elseif document.entries ~= nil then
        entries = document.entries
    elseif document[1] ~= nil then
        entries = document
    else
        return {}
    end
    local name = path.filename(file)
    local rows = {}
    for position, entry in ipairs(entries) do
        table.insert(rows, {absent = entry.status == "absent", kind = entry.kind, api = entry.api, position = position})
    end
    table.sort(rows, function (a, b)
        if a.absent ~= b.absent then
            return a.absent
        end
        if a.api ~= b.api then
            return byteorder.less(a.api, b.api)
        end
        return a.position < b.position
    end)
    local lines = {}
    for _, row in ipairs(rows) do
        table.insert(lines, {file = name, label = row.absent and "absent" or "control", kind = row.kind, api = row.api})
    end
    return lines
end

local function build(here, work)
    local sdk = os.iorunv("xcrun", {"--show-sdk-path"}):trim()
    local probe = path.join(work, "probe")
    local log = path.join(work, "build.log")
    local built = try {
        function ()
            os.execv("xcrun", {"clang", "-target", "arm64-apple-macos14.0", "-isysroot", sdk, "-fobjc-arc", "-Wall",
                               "-Wno-unused-function", path.join(here, "probe-host-absent.m"), "-framework", "Foundation",
                               "-framework", "Intents", "-o", probe}, {stderr = log})
            return true
        end
    }
    if not built then
        local lines = (io.readfile(log) or ""):split("\n")
        local tail = {}
        for index = math.max(1, #lines - 19), #lines do
            table.insert(tail, lines[index])
        end
        raise("the probe did not build; %s says why:\n%s", log, table.concat(tail, "\n"))
    end
    return probe
end

function main(...)
    local options = options_of({...})
    local here = os.scriptdir()
    local root = path.absolute(path.join(here, "..", ".."))
    local workspace = import("workspace", {rootdir = path.join(root, "modules"), anonymous = true})
    local files = options.files
    if #files == 0 then
        files = os.files(path.join(root, "packages", "frameworks", "apple-backports", "registry", "Intents", "*.json"))
        byteorder.sort(files)
    end
    local work = options.work or workspace.fresh("probe-host-absent")
    os.mkdir(work)
    local out = options.out or path.join(work, "probe.log")

    local probe = build(here, work)

    local rows, arguments = {}, {}
    local absent, control = 0, 0
    for _, file in ipairs(files) do
        for _, row in ipairs(rows_of(file)) do
            table.insert(rows, table.concat({row.file, row.label, row.kind, row.api}, "\t"))
            table.insert(arguments, table.concat({row.file, row.kind, row.api}, "\t"))
            if row.label == "absent" then
                absent = absent + 1
            else
                control = control + 1
            end
        end
    end
    io.writefile(path.join(work, "rows.txt"), #rows > 0 and (table.concat(rows, "\n") .. "\n") or "", {encoding = "binary"})

    local answered = path.join(work, "probe.out")
    os.execv(probe, arguments, {stdout = answered})
    local digest = string.format("# absent rows: %d, control rows: %d implemented rows of the same files\n", absent, control)
        .. io.readfile(answered, {encoding = "binary"})
    io.writefile(out, digest, {encoding = "binary"})
    os.rm(answered)
    print("probe digest: %s", out)
    local lines = digest:gsub("\n$", ""):split("\n", {strict = true})
    print(lines[#lines])
end
