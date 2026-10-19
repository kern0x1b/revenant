-- Packages of charon whose sources are another member of hades (styx, eidolon, shade).
--
-- Inside hades, charon/ has those members beside it, and a package builds the member as it is in this
-- checkout instead of fetching a pinned commit of the member's old repository. Outside hades (charon
-- consumed as a repository of its own) a package keeps its urls and versions and nothing here applies.
--
-- A package from a member folder still has a version, and it keys the install: the member's tree at HEAD
-- (git's own id of that folder), and when the folder has changes not committed, a digest of them on top.
-- The same sources therefore reuse one install, and any change is another one. The build never runs in
-- the member folder: the files git lists for it (tracked and new, not ignored) are copied to the
-- package's own working folder first, as a fresh clone would be.

-- A recipe decides in its description whether it is inside hades (a package description cannot import
-- this module), with the same test everywhere: hades' third_party/fetch.lua four folders above the recipe,
-- and the member folder beside charon. It then calls set_sourcedir(<member>) instead of add_urls/add_versions,
-- and its on_load and on_install use version() and stage() below.

-- git's standard output only (os.iorunv also returns the error output)
local function git(dir, args)
    local out = os.iorunv("git", table.join({"-C", dir}, args))
    return out
end

-- the version a member folder's sources are: tree.<id>, plus +<digest> of uncommitted changes. A build that
-- also reads other folders of hades (shade reads the third_party pins) names them, and their trees and
-- changes are folded into the same version.
function version(dir, others)
    local dirs = table.join({dir}, others or {})
    local trees = {}
    local changes = {}
    for _, each in ipairs(dirs) do
        -- a folder not committed yet has no tree at HEAD: all of it is then the uncommitted part
        local tree = try { function () return git(each, {"rev-parse", "--verify", "-q", "HEAD:./"}) end }
        table.insert(trees, tree and tree:trim() or "new")
        if #git(each, {"status", "--porcelain", "--untracked-files=all", "--", "."}) > 0 then
            table.insert(changes, git(each, {"diff", "HEAD", "--binary", "--", "."}))
            for _, file in ipairs(git(each, {"ls-files", "--others", "--exclude-standard"}):split("\n")) do
                table.insert(changes, file .. "=" .. hash.sha256(path.join(each, file)))
            end
        end
    end
    local tree = #trees == 1 and trees[1] or hash.strhash128(table.concat(trees, "\n"))
    local result = "tree." .. tree:sub(1, 16)
    if #changes > 0 then
        result = result .. "+" .. hash.strhash128(table.concat(changes, "\n")):sub(1, 16)
    end
    return result
end

-- copies the member's files into the package's working folder and returns that folder
function stage(package, dir)
    local work = path.join(package:cachedir(), "member-source")
    os.tryrm(work)
    os.mkdir(work)
    -- tracked and new files that are there: a tracked file deleted and not committed is not copied
    local files = {}
    for _, file in ipairs(git(dir, {"ls-files", "--cached", "--others", "--exclude-standard"}):split("\n")) do
        if os.isfile(path.join(dir, file)) or os.islink(path.join(dir, file)) then
            table.insert(files, file)
        end
    end
    local list = path.join(package:cachedir(), "member-files.txt")
    io.writefile(list, table.concat(files, "\n") .. "\n")
    os.vrunv("rsync", {"-a", "--files-from=" .. list, dir .. "/", work .. "/"})
    return work
end

-- the top of hades, for a package that needs its third_party pins
function root(dir)
    return path.directory(dir)
end
