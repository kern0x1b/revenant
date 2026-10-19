-- registry-shape.lua: does a registry file's shape survive an edit? Two questions, one tool.
--
--   xmake l tools/registry-shape.lua [registry-root] [--against <git-ref>]
--
-- 1. Does any object carry the same key twice? A JSON parser does not say: it keeps the last of a duplicate key,
--    so a file that lost a brace between two entries parses cleanly and silently merges them. That is not a shape
--    a parse can see and a reader cannot - it has already been committed once in this package, and the fix is a
--    check rather than a habit. This reads every object and names any object that carries a key twice.
--
-- 2. Did an edit change the set of rows? With --against <ref>, every registry file that differs from that ref is
--    read at both and the api lists are compared: a file may gain rows, lose rows or gain duplicates, and a parse
--    that succeeds is not a shape being right.
--
-- A run that reads no registry file at all is refused rather than reported as clean. Every failure is a raise, so
-- the exit status is 1 whatever the run printed first.

import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "modules")})
import("registry_rows", {rootdir = os.scriptdir()})

local ROOT = path.absolute(path.join(os.scriptdir(), ".."))
local DEFAULT = path.join(ROOT, "packages", "a", "apple-backports", "registry")
local SCRATCH = path.join(ROOT, ".agent-work", "runs", "registry-shape")

-- git with its output going to `into` (a file), or nowhere; the status comes back.
local function git(args, into)
    return os.execv("git", args, {try = true, stdout = into or os.nuldev(), stderr = os.nuldev()})
end

-- Does this ref name a commit in this repository? Asked before any comparison, so a typo cannot turn a comparison
-- into a run that reports nothing and exits 0.
local function resolves(ref)
    return git({"rev-parse", "--verify", "--quiet", ref .. "^{commit}"}) == 0
end

-- The api lists of the file `relative` (under the registry) at `ref`, or nil when the file did not exist there.
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

-- The names in `from` that `to` does not hold.
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
    -- git runs from the checkout, so every path above is absolute by now
    os.cd(ROOT)

    local files = os.files(path.join(registry, "**.json"))
    byteorder.sort(files)
    if #files == 0 then
        raise("no registry file under %s: nothing was checked, so nothing is claimed", registry)
    end
    if against and not resolves(against) then
        -- A ref that does not resolve is not a comparison that found nothing: it is a comparison that never
        -- happened, and the run has to say so and fail rather than report 0 problems.
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
            -- the ref resolves but this file did not exist there: not a row list to compare
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
