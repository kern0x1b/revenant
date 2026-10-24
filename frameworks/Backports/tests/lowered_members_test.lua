local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

function main()
    local src = path.absolute(path.join(os.scriptdir(), "..", "src"))
    local committed = io.readfile(lowered.members_file())
    local expected = lowered.members_text(src, workspace.sdk())
    assert(committed == expected, "frameworks/Backports/lowered-members.txt no longer matches frameworks/Backports/src: run "
           .. "./xmakew l -P . frameworks/Backports/tools/lowered_members.lua and commit the result")
    assert(lowered.serialize(lowered.parse(committed)) == committed, "the lowered member list does not survive a parse and serialize")
end
