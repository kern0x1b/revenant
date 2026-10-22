-- Writes frameworks/Backports/lowered-members.txt: the lowered API set the iPhoneOS SDK lowering reads from the sources.
-- Run it after a change to frameworks/Backports/src changes what is backported:
--   ./xmakew l -P . frameworks/Backports/tools/lowered_members.lua
local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

function main()
    local src = path.absolute(path.join(os.scriptdir(), "..", "src"))
    local set = lowered.members_of(src, workspace.sdk())
    io.writefile(lowered.members_file(), lowered.serialize(set))
    print(lowered.members_file())
end
