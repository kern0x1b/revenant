local root = path.absolute(path.directory(os.scriptdir()))
local projectdir = path.absolute(os.projectdir())

if path.translate(projectdir) ~= path.translate(root) then
    raise("xmake's project is %s, not this checkout %s: a parent checkout's xmake.lua was taken, so its packages would resolve", projectdir, root)
end
if not os.isfile(path.join(projectdir, "packages", "d", "dynarmic", "xmake.lua")) then
    raise("the project %s has no packages tree of its own", projectdir)
end
print("worktree_root: ok " .. projectdir)
