import("exclusive")

local STAMP = "revenant-sources.txt"

local function described(repositories)
    local lines = {}
    for _, repository in ipairs(repositories) do
        local line = string.format("%s %s %s %s", repository.name or ".", repository.url, repository.tag or "-", repository.commit)
        if repository.sparse then
            line = line .. " " .. table.concat(repository.sparse, " ")
        end
        table.insert(lines, line)
    end
    return table.concat(lines, "\n") .. "\n"
end

local function reset(folder, text)
    for line in text:gmatch("[^\n]+") do
        local name = line:match("^(%S+)")
        local into = name == "." and folder or path.join(folder, name)
        os.vrunv("git", {"-C", into, "checkout", "--", "."})
        os.vrunv("git", {"-C", into, "clean", "-fd", "-e", STAMP})
    end
end

local function locked(sourcedir, work)
    return exclusive.run(sourcedir .. ".lock", "the sources in " .. sourcedir, work)
end

local function fetch(sourcedir, repositories)
    local stamp = path.join(sourcedir, STAMP)
    if os.isfile(stamp) and io.readfile(stamp) == described(repositories) then
        reset(sourcedir, io.readfile(stamp))
        return false
    end
    local staging = sourcedir .. ".tmp"
    os.tryrm(staging)
    os.mkdir(staging)
    for _, repository in ipairs(repositories) do
        local into = repository.name and path.join(staging, repository.name) or staging
        if repository.tag then
            os.vrunv("git", {"clone", "--depth", "1", "--branch", repository.tag, "--filter=blob:none", "--no-checkout",
                             repository.url, into})
            local head = os.iorunv("git", {"-C", into, "rev-parse", "HEAD"}):trim()
            if head ~= repository.commit then
                raise("%s of %s is %s now, not the %s this package was written against; a tag that moved is not the release it names",
                      repository.tag, repository.url, head, repository.commit)
            end
        else
            os.vrunv("git", {"init", "-q", into})
            os.vrunv("git", {"-C", into, "remote", "add", "origin", repository.url})
            os.vrunv("git", {"-C", into, "fetch", "--depth", "1", "--filter=blob:none", "origin", repository.commit})
        end
        if repository.sparse then
            os.vrunv("git", table.join({"-C", into, "sparse-checkout", "set", "--no-cone"}, repository.sparse))
        end
        os.vrunv("git", {"-C", into, "checkout", "-q", repository.tag or repository.commit})
        if not repository.tag then
            local head = os.iorunv("git", {"-C", into, "rev-parse", "HEAD"}):trim()
            if head ~= repository.commit then
                raise("%s fetched %s, not the commit %s this package was written against", repository.url, head, repository.commit)
            end
        end
    end
    io.writefile(path.join(staging, STAMP), described(repositories))
    os.tryrm(sourcedir)
    os.mv(staging, sourcedir)
    return true
end

function pinned(sourcedir, repositories)
    return locked(sourcedir, function ()
        return fetch(sourcedir, repositories)
    end)
end

function keyed(sourcedir, key)
    return locked(sourcedir, function ()
        local stamp = path.join(sourcedir, STAMP)
        if not os.isfile(stamp) then
            raise("%s holds no pinned sources to take a copy of; they are downloaded before they are installed", sourcedir)
        end
        local text = io.readfile(stamp)
        local folder = sourcedir .. "-" .. key
        local kept = path.join(folder, STAMP)
        if os.isfile(kept) and io.readfile(kept) == text then
            reset(folder, text)
            return folder
        end
        reset(sourcedir, text)
        local staging = folder .. ".tmp"
        os.tryrm(staging)
        os.tryrm(folder)
        os.vrunv("cp", {"-cR", sourcedir, staging})
        os.mv(staging, folder)
        return folder
    end)
end
