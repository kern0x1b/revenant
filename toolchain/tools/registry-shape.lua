import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "modules")})
import("registry_rows", {rootdir = os.scriptdir()})

local ROOT = path.absolute(path.join(os.scriptdir(), ".."))
local DEFAULT = path.join(ROOT, "packages", "a", "apple-backports", "registry")
local SCRATCH = path.join(ROOT, ".agent-work", "runs", "registry-shape")

local function git(args, into)
    return os.execv("git", args, {try = true, stdout = into or os.nuldev(), stderr = os.nuldev()})
end

local function resolves(ref)
    return git({"rev-parse", "--verify", "--quiet", ref .. "^{commit}"}) == 0
end

local function apis_in(ref, relative)
    os.mkdir(SCRATCH)
    local shown = path.join(SCRATCH, "show.txt")
    local status = git({"show", ref .. ":packages/a/apple-backports/registry/" .. relative}, shown)
    if status ~= 0 then
        os.tryrm(shown)
        return nil
    end
    local root = registry_rows.parse(io.readfile(shown, {encoding = "binary"}))
    os.tryrm(shown)
    return registry_rows.apis(root, ref .. ":" .. relative)
end

local function same(before, after)
    if #before ~= #after then
        return false
    end
    for index = 1, #before do
        if before[index] ~= after[index] then
            return false
        end
    end
    return true
end

local function missing(from, to)
    local absent = {}
    for _, name in ipairs(from) do
        local held = false
        for _, other in ipairs(to) do
            if other == name then
                held = true
                break
            end
        end
        if not held then
            table.insert(absent, tostring(name))
        end
    end
    return absent
end

local function listed(names)
    return #names > 0 and table.concat(names, ", ") or "none"
end

function main(...)
    local registry = DEFAULT
    local against = nil
    local arguments = {...}
    local index = 1
    while index <= #arguments do
        local argument = arguments[index]
        if argument == "--against" and index < #arguments then
            against = arguments[index + 1]
            index = index + 2
        else
            if argument:sub(1, 2) ~= "--" then
                registry = path.absolute(argument)
            end
            index = index + 1
        end
    end
    os.cd(ROOT)

    local files = os.files(path.join(registry, "**.json"))
    byteorder.sort(files)
    if #files == 0 then
        raise("no registry file under %s: nothing was checked, so nothing is claimed", registry)
    end
    if against and not resolves(against) then
        raise("--against %s does not resolve in this repository: nothing was compared against it, so nothing is claimed",
              against)
    end

    local bad = 0
    local compared = 0
    local roots = {}
    for _, file in ipairs(files) do
        local root, objects = registry_rows.read(file)
        roots[file] = root
        for _, object_ in ipairs(objects) do
            if #object_.repeated > 0 then
                bad = bad + 1
                local api = object_.map.api
                print(string.format("DUPLICATE KEYS %s in %s: %s", table.concat(object_.repeated, ","), file,
                                    api and api.kind == "string" and api.value or "None"))
            end
        end
    end

    if against then
        for _, file in ipairs(files) do
            local relative = path.relative(file, registry)
            local before = apis_in(against, relative)
            if before ~= nil then
                compared = compared + 1
                local after = registry_rows.apis(roots[file], file)
                if not same(before, after) then
                    bad = bad + 1
                    print(string.format("ROW LIST CHANGED %s: lost %s, gained %s", relative,
                                        listed(missing(before, after)), listed(missing(after, before))))
                end
            end
        end
        if compared == 0 then
            raise("--against %s resolved but no registry file of %s existed there: nothing was compared, so nothing is claimed",
                  against, registry)
        end
    end

    print(string.format("%d registry file(s) read under %s, %d problem(s)%s", #files, registry, bad,
                        against and string.format(", %d row list(s) compared against %s", compared, against) or ""))
    if bad > 0 then
        raise("%d problem(s) in the registry", bad)
    end
end
