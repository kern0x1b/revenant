-- The repositories a package is built from, each at the commit its tag named when the package was written.
--
-- A tag that moved is not the release it names, so every clone is checked against its commit and the build stops when they
-- differ. The clones of a compiler or a runtime are gigabytes, so a source directory that already holds exactly these
-- commits is kept: an install that failed halfway, or a second architecture, does not pay for the download again. What the
-- last install changed in a repository - the patches it applied - is undone, so a build always starts from the release; a
-- build tree kept beside the repositories, rather than inside one, survives that and is the reason to keep them at all.
-- The stamp is written last, so a clone cut short is not mistaken for a finished one.
-- The stamp names the paths a sparse clone holds too: a list that grew is a clone that lacks what was added to it.

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

-- pinned(sourcedir, repositories): clone what is not there yet. A repository is
-- {name = "swift", url = ..., tag = ..., commit = ..., sparse = {"/stdlib/"}}; name is the directory it is cloned into, or
-- nil for a package built from one repository. Answers true when it cloned, false when it kept and restored what was there.
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
