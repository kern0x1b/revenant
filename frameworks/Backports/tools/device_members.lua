local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

function main()
    local inventory = lowered.inventory_file()
    if not os.isfile(inventory) then
        raise("device_members: no iOS 6.0 inventory at %s; the release's dyld cache inventory is read from ~/.revenant, read only", inventory)
    end
    local set = lowered.device_members_of(workspace.sdk(), inventory)
    io.writefile(lowered.device_members_file(), lowered.device_text(set))
    print(lowered.device_members_file())
end
