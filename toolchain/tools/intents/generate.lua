import("core.base.json")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

local FACTS = "facts/Intents/Intents.md"
local LATER = "a class of a later group of this same delivery"

local REGISTRY_RUNS = {
    {groups = {"10_0_1", "10_3"}, release = "10.0.1", file = "ios10.json", protocols = true},
    {groups = {"11_0"}, release = "11.0", file = "ios11.json", hand_written = "CharonIntents110.m"},
    {groups = {"12_0"}, release = "12.0", file = "ios12.json"},
    {groups = {"13_4", "16_0"}, release = "16.0", file = "ios16.json"},
    {groups = {"18_0"}, release = "18.0", file = "ios18.json"},
}

local CONSTANT_RUNS = {
    {file = "ios10.json", release = "10.0.1"},
    {file = "ios18.json", release = "18.0"},
}

local USAGE = "usage: xmake l tools/intents/generate.lua [--port-sdk <SDK>] [--work <dir>] [--registry <dir>] "
    .. "[--manifest <constants.json>] [--objects <dir>]"

local function options_of(arguments)
    local options = {}
    local index = 1
    while index <= #arguments do
        local key = arguments[index]:match("^%-%-(.+)$")
        if not key or arguments[index + 1] == nil then
            raise(USAGE)
        end
        options[key] = arguments[index + 1]
        index = index + 2
    end
    for key in pairs(options) do
        if key ~= "port-sdk" and key ~= "work" and key ~= "registry" and key ~= "manifest" and key ~= "objects" then
            raise(USAGE)
        end
    end
    return options
end

local function constant_rows_held(registry)
    local held = {}
    local files = os.files(path.join(registry, "ios*.json"))
    byteorder.sort(files)
    for _, file in ipairs(files) do
        local document = json.decode(io.readfile(file))
        for _, entry in ipairs(document.entries or document) do
            if entry.kind == "constant" then
                held[entry.api] = path.filename(file)
            end
        end
    end
    return held
end

function main(...)
    local options = options_of({...})
    local here = os.scriptdir()
    local root = path.absolute(path.join(here, "..", ".."))
    local workspace = import("workspace", {rootdir = path.join(root, "modules"), anonymous = true})
    local generator = import("gen-registry", {rootdir = here, anonymous = true})

    local sdk = workspace.sdk()
    local corpus = workspace.corpus("sdk-26.2-surface.tsv")
    local work = options.work or workspace.run("intents-generation")
    local objects = options.objects or path.join(root, "packages", "a", "apple-backports", ".gen", "Intents")
    local registry = options.registry or path.join(root, "packages", "a", "apple-backports", "registry", "Intents")
    local manifest = options.manifest or path.join(here, "constants.json")
    local groups = path.join(here, "groups")
    os.mkdir(work)
    os.mkdir(registry)

    local arguments = {"l", path.join(here, "objects.lua"), "--sdk", sdk, "--out", objects, "--work", work}
    if options["port-sdk"] then
        table.join2(arguments, {"--port-sdk", options["port-sdk"]})
    end
    os.execv(os.programfile(), arguments)

    local causes = path.join(work, "causes.json")
    os.execv(os.programfile(), {"l", path.join(here, "gen-causes.lua"), "--out", causes})

    for _, run in ipairs(REGISTRY_RUNS) do
        local given = {"--corpus", corpus, "--classes"}
        for _, group in ipairs(run.groups) do
            table.insert(given, path.join(groups, group .. ".txt"))
        end
        for _, group in ipairs(run.groups) do
            table.join2(given, {"--report", path.join(work, "report-" .. group .. ".json")})
        end
        table.join2(given, {"--out", path.join(registry, run.file), "--facts", FACTS, "--release", run.release,
                            "--causes", causes, "--reason", LATER})
        if not run.protocols then
            table.insert(given, "--no-protocols")
        end
        if run.hand_written then
            table.join2(given, {"--hand-written", run.hand_written})
        end
        generator.registry(generator.options_of(given))
    end

    if not os.isfile(manifest) then
        raise("no %s; run tools/intents/emit-intents-constants.lua first", manifest)
    end
    for _, run in ipairs(CONSTANT_RUNS) do
        local file = path.join(registry, run.file)
        generator.registry(generator.options_of({"--corpus", corpus, "--merge-into", file, "--constants", manifest,
                                                 "--out", file, "--facts", FACTS, "--release", run.release}))
    end

    local wanted = byteorder.keys(json.decode(io.readfile(manifest)).constants)
    local held = constant_rows_held(registry)
    local missing = {}
    for _, name in ipairs(wanted) do
        if not held[name] then
            table.insert(missing, name)
        end
    end
    if #missing > 0 then
        raise("the run lost %d constant rows: %s", #missing, table.concat(missing, " "))
    end
    print("  %d constant rows, all of them present", #wanted)
    print("regenerated: %d object files in %s, %d registry files", #os.files(path.join(objects, "IN*.m")), objects,
          #os.files(path.join(registry, "ios*.json")))
end
