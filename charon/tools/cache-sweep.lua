import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "modules")})

local FAMILIES = {"sdk-owners", "first-release"}

local function live_checkouts(given)
    local root = path.absolute(path.join(os.scriptdir(), ".."))
    local found = {}
    local listed = os.iorunv("git", {"-C", root, "worktree", "list", "--porcelain"})
    for line in listed:gmatch("[^\n]+") do
        local checkout = line:match("^worktree (.+)$")
        if checkout then
            table.insert(found, checkout)
        end
    end
    for _, checkout in ipairs(given) do
        table.insert(found, path.absolute(checkout))
    end
    local kept = {}
    for _, checkout in ipairs(table.unique(found)) do
        if os.isfile(path.join(checkout, "modules", "apple", "dyld.lua")) then
            table.insert(kept, checkout)
        end
    end
    return kept
end

local function sdkdirs()
    local found = os.dirs(path.join(os.getenv("HOME"), ".xmake", "packages", "i", "iphoneos-sdk", "*", "*", "Developer.app",
                                    "Contents", "Developer", "Platforms", "iPhoneOS.platform", "Developer", "SDKs", "iPhoneOS*.sdk"))
    byteorder.sort(found)
    return found
end

function sweep_checkout(checkout, sdks, cache_root)
    local modules = path.join(checkout, "modules")
    local names, failure
    local ok = try {
        function ()
            local dyld = import("apple.dyld", {rootdir = modules, anonymous = true})
            local backports = import("apple.backports", {rootdir = modules, anonymous = true})
            local architectures = import("apple.architectures", {rootdir = modules, anonymous = true})
            local ladders = {}
            for _, architecture in ipairs(architectures.names()) do
                table.insert(ladders, dyld.held_ladder(backports.compatible(architecture)))
            end
            names = dyld.kept_files(sdks or sdkdirs(), ladders, cache_root)
            return true
        end,
        catch {
            function (errors)
                failure = tostring(errors)
                return false
            end
        }
    }
    if ok and names then
        return {files = names, checkout = checkout}
    elseif failure then
        return {checkout = checkout, reason = failure:match("([^\n]+)") or failure}
    end
    return {checkout = checkout}
end

function main(...)
    local dry, given = false, {}
    for _, argument in ipairs({...}) do
        if argument == "--dry-run" then
            dry = true
        else
            table.insert(given, argument)
        end
    end
    local sdks = sdkdirs()
    local read, older = {}, {}
    local folder = path.join(path.directory(import("apple.dyld", {rootdir = path.join(os.scriptdir(), "..", "modules"), anonymous = true}).root()), "cache")
    local skipped = {}
    for _, checkout in ipairs(live_checkouts(given)) do
        local outcome = sweep_checkout(checkout, sdks, folder)
        if outcome.files then
            for _, file in ipairs(outcome.files) do
                read[path.filename(file)] = true
            end
        elseif outcome.reason then
            table.insert(skipped, {checkout = outcome.checkout, reason = outcome.reason})
        else
            table.insert(older, outcome.checkout)
        end
    end
    local removed, kept, failed = 0, 0, {}
    for _, family in ipairs(FAMILIES) do
        for _, file in ipairs(os.files(path.join(folder, family .. "-*.tsv"))) do
            local name = path.filename(file)
            local rest = name:sub(#family + 2, -5)
            local unkeyed = not rest:find("-", 1, true)
            if read[name] or (unkeyed and #older > 0) then
                kept = kept + 1
            elseif dry then
                print("would remove %s", name)
                removed = removed + 1
            else
                local reason
                try {
                    function ()
                        os.rm(file)
                    end,
                    catch {
                        function (errors)
                            reason = tostring(errors)
                        end
                    }
                }
                reason = reason or (os.isfile(file) and "still there after removal" or nil)
                if reason then
                    table.insert(failed, name .. ": " .. reason)
                else
                    removed = removed + 1
                end
            end
        end
    end
    print("cache-sweep: %s: kept %d, %s %d", folder, kept, dry and "would remove" or "removed", removed)
    for _, entry in ipairs(skipped) do
        print("cache-sweep: skipped %s, and its cache is kept whole: %s", entry.checkout, entry.reason)
    end
    if #older > 0 then
        print("cache-sweep: files named without a code key stay, read by code older than that naming in: %s", table.concat(older, " "))
    end
    if #failed > 0 then
        raise("cache-sweep: could not remove %d file(s):\n%s", #failed, table.concat(failed, "\n"))
    end
    if #skipped > 0 then
        local names = {}
        for _, entry in ipairs(skipped) do
            table.insert(names, entry.checkout)
        end
        raise("cache-sweep: %d checkout(s) could not be read, and their cache is kept: %s", #skipped,
              table.concat(names, ", "))
    end
end
