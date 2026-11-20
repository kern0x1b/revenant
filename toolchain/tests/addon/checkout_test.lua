import("fixtures")

local function origin(folder)
    local repository = path.join(folder, "origin")
    os.mkdir(path.join(repository, "first"))
    os.mkdir(path.join(repository, "second"))
    io.writefile(path.join(repository, "first", "one.txt"), "one\n")
    io.writefile(path.join(repository, "first", ".gitignore"), "/build*\n")
    io.writefile(path.join(repository, "second", "two.txt"), "two\n")
    local git = function (arguments) os.vrunv("git", table.join({"-C", repository}, arguments)) end
    git({"init", "-q"})
    git({"config", "uploadpack.allowFilter", "true"})
    git({"add", "-A"})
    git({"-c", "user.name=revenant", "-c", "user.email=revenant@example.invalid", "commit", "-q", "-m", "release"})
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

    if checkout.pinned(sourcedir, repositories({"/first/"})) then
        table.insert(found, "a clone of the same repositories and paths is kept")
    end

    local one = path.join("release", "first", "one.txt")
    local build = path.join("release", "first", "build-test", "kept.txt")
    local stray = path.join("release", "first", "stray.txt")
    local mine = checkout.keyed(sourcedir, "aaaa")
    local theirs = checkout.keyed(sourcedir, "bbbb")
    if mine == theirs or mine == sourcedir or theirs == sourcedir then
        table.insert(found, "two builds of one package, and the shared source, are three folders: " .. mine .. " " .. theirs)
    end
    if not os.isfile(path.join(mine, one)) or not os.isfile(path.join(theirs, one)) or os.isfile(path.join(mine, "release", "second", "two.txt")) then
        table.insert(found, "the copy of a build holds the paths the shared source was cut to and no others")
    end
    io.writefile(path.join(mine, one), "patched\n")
    io.writefile(path.join(mine, stray), "stray\n")
    os.mkdir(path.directory(path.join(mine, build)))
    io.writefile(path.join(mine, build), "kept\n")
    if io.readfile(path.join(sourcedir, one)) ~= "one\n" or io.readfile(path.join(theirs, one)) ~= "one\n" then
        table.insert(found, "a patch applied in the copy of one build reaches the shared source or the copy of another build")
    end
    if checkout.keyed(sourcedir, "aaaa") ~= mine then
        table.insert(found, "a build asks for its copy again and is given the same folder")
    end
    if io.readfile(path.join(mine, one)) ~= "one\n" or os.isfile(path.join(mine, stray)) then
        table.insert(found, "the copy a build asks for again is the pristine source, not what the earlier attempt left in it")
    end
    if not os.isfile(path.join(mine, build)) then
        table.insert(found, "the copy a build asks for again keeps its ignored build directory, which an interrupted build resumes in")
    end
    io.writefile(path.join(sourcedir, one), "dirty\n")
    local third = checkout.keyed(sourcedir, "cccc")
    if io.readfile(path.join(third, one)) ~= "one\n" or io.readfile(path.join(sourcedir, one)) ~= "one\n" then
        table.insert(found, "a copy is taken from the pristine source, not from a source an earlier build left changed")
    end

    if not checkout.pinned(sourcedir, repositories({"/first/", "/second/"})) then
        table.insert(found, "a sparse list that grew is a clone made again")
    end
    local grown = checkout.keyed(sourcedir, "aaaa")
    if not os.isfile(path.join(grown, "release", "second", "two.txt")) or os.isfile(path.join(grown, build)) then
        table.insert(found, "the copy of a build made after the pinned sources changed holds the new sources, and none of the old build")
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
