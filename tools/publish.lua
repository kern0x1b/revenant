-- xmake l tools/publish.lua <member> [<branch>]
--
-- Produces the history of one member as a repository of its own, for the places that consume it that way:
-- apps outside hades take charon with add_repositories("charon <url> <tag>"), and xmake reads a package
-- repository from the top of what it clones, so charon's published repository is this split, not hades.
--
-- `git subtree split --prefix=<member>` rewrites hades' history of that folder into commits of its own. The
-- commits the member had before it came into hades come out as the very same commits (same hashes), so the
-- published repository continues its history and a pin to an old commit stays valid. The result is the local
-- branch <branch> (default publish/<member>); pushing it is a separate, deliberate step.
function main(member, branch)
    assert(member, "usage: xmake l tools/publish.lua <member> [<branch>]")
    local root = path.directory(os.scriptdir())
    assert(os.isdir(path.join(root, member)), "no member folder " .. member)
    branch = branch or ("publish/" .. member)
    os.vrunv("git", {"-C", root, "subtree", "split", "--prefix=" .. member, "-b", branch, "HEAD"})
    local split = os.iorunv("git", {"-C", root, "rev-parse", branch .. "^{tree}"}):trim()
    local here = os.iorunv("git", {"-C", root, "rev-parse", "HEAD:" .. member}):trim()
    assert(split == here, string.format("the split of %s is tree %s, the folder at HEAD is %s", member, split, here))
    print("%s: %s", branch, os.iorunv("git", {"-C", root, "rev-parse", branch}):trim())
end
