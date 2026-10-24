local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})
local facts = import("facts", {rootdir = path.join(os.scriptdir(), "..", "tools"), anonymous = true})

function main()
    local src = path.absolute(path.join(os.scriptdir(), "..", "src"))
    local committed = io.readfile(lowered.members_file())
    local sdk = workspace.sdk()
    local expected = lowered.serialize(lowered.members_of(src, sdk, facts.constant_intros(sdk)))
    assert(committed == expected, "frameworks/Backports/lowered-members.txt no longer matches frameworks/Backports/src: run "
           .. "./xmakew l -P . frameworks/Backports/tools/lowered_members.lua and commit the result")
    assert(lowered.serialize(lowered.parse(committed)) == committed, "the lowered member list does not survive a parse and serialize")
end
