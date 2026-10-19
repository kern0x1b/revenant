local STAMP = "charon-sources.txt"

local function described(repositories)
    local lines = {}
    for _, repository in ipairs(repositories) do
        local line = string.format("%s %s %s %s", repository.name or ".", repository.url, repository.tag, repository.commit)
        if repository.sparse then
            line = line .. " " .. table.concat(repository.sparse, " ")
        end
        table.insert(lines, line)
    end
    return table.concat(lines, "\n") .. "\n"
end

function pinned(sourcedir, repositories)
    local stamp = path.join(sourcedir, STAMP)
    if os.isfile(stamp) and io.readfile(stamp) == described(repositories) then
        for _, repository in ipairs(repositories) do
            local into = repository.name and path.join(sourcedir, repository.name) or sourcedir
            os.vrunv("git", {"-C", into, "checkout", "--", "."})
            os.vrunv("git", {"-C", into, "clean", "-fd"})
        end
        return false
    end
    local staging = sourcedir .. ".tmp"
    os.tryrm(staging)
    os.mkdir(staging)
    for _, repository in ipairs(repositories) do
        local into = repository.name and path.join(staging, repository.name) or staging
        os.vrunv("git", {"clone", "--depth", "1", "--branch", repository.tag, "--filter=blob:none", "--no-checkout",
                         repository.url, into})
        local head = os.iorunv("git", {"-C", into, "rev-parse", "HEAD"}):trim()
        if head ~= repository.commit then
            raise("%s of %s is %s now, not the %s this package was written against; a tag that moved is not the release it names",
                  repository.tag, repository.url, head, repository.commit)
        end
        if repository.sparse then
            os.vrunv("git", table.join({"-C", into, "sparse-checkout", "set", "--no-cone"}, repository.sparse))
        end
        os.vrunv("git", {"-C", into, "checkout", repository.tag})
    end
    io.writefile(path.join(staging, STAMP), described(repositories))
    os.tryrm(sourcedir)
    os.mv(staging, sourcedir)
    return true
end
