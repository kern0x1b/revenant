local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})
local facts = import("facts", {rootdir = os.scriptdir(), anonymous = true})

function main()
    local src = path.absolute(path.join(os.scriptdir(), "..", "src"))
    local sdk = workspace.sdk()
    io.writefile(lowered.members_file(), lowered.members_text(src, sdk, facts.constant_intros(sdk)))
    print(lowered.members_file())
end
