import("fixtures")

-- A repository of two directories with a tag, served the way a remote is, so a clone can be cut to a sparse list.
local function origin(folder)
    local repository = path.join(folder, "origin")
    os.mkdir(path.join(repository, "first"))
    os.mkdir(path.join(repository, "second"))
    io.writefile(path.join(repository, "first", "one.txt"), "one\n")
    io.writefile(path.join(repository, "second", "two.txt"), "two\n")
    local git = function (arguments) os.vrunv("git", table.join({"-C", repository}, arguments)) end
    git({"init", "-q"})
    git({"config", "uploadpack.allowFilter", "true"})
    git({"add", "-A"})
    git({"-c", "user.name=charon", "-c", "user.email=charon@example.invalid", "commit", "-q", "-m", "release"})
    git({"tag", "release-1"})
    return "file://" .. repository, os.iorunv("git", {"-C", repository, "rev-parse", "HEAD"}):trim()
end

function failures(opt)
    local checkout = import("checkout", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local folder = fixtures.scratch()
    local url, commit = origin(folder)
    local sourcedir = path.join(folder, "source")
    local function repositories(sparse)
        return {{name = "release", url = url, tag = "release-1", commit = commit, sparse = sparse}}
    end
    local first = path.join(sourcedir, "release", "first", "one.txt")
    local second = path.join(sourcedir, "release", "second", "two.txt")

    if not checkout.pinned(sourcedir, repositories({"/first/"})) then
        table.insert(found, "a source directory with nothing in it is cloned")
    end
    if not os.isfile(first) or os.isfile(second) then
        table.insert(found, "a sparse clone holds the paths it was cut to and no others")
    end

    -- The same list is the same sources: they are kept, not cloned again.
    if checkout.pinned(sourcedir, repositories({"/first/"})) then
        table.insert(found, "a clone of the same repositories and paths is kept")
    end

    -- A list that grew names sources the clone lacks, so it is made again; before the stamp named the paths, the clone
    -- was kept and the new directory was never there.
    if not checkout.pinned(sourcedir, repositories({"/first/", "/second/"})) then
        table.insert(found, "a sparse list that grew is a clone made again")
    end
    if not os.isfile(first) or not os.isfile(second) then
        table.insert(found, "the clone made again holds every path of the grown list")
    end
    if checkout.pinned(sourcedir, repositories({"/first/", "/second/"})) then
        table.insert(found, "the grown list, asked again, keeps the clone it made")
    end

    os.tryrm(folder)
    return found
end
