local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

function main()
    local src = path.absolute(path.join(os.scriptdir(), "..", "src"))
    local set = lowered.members_of(src, workspace.sdk())
    io.writefile(lowered.members_file(), lowered.serialize(set))
    print(lowered.members_file())
end
