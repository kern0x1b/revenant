local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

function main()
    local src = path.absolute(path.join(os.scriptdir(), "..", "src"))
    io.writefile(lowered.members_file(), lowered.members_text(src, workspace.sdk()))
    print(lowered.members_file())
end
