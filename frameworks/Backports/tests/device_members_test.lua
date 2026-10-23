local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

function main()
    local inventory = lowered.inventory_file()
    if not os.isfile(inventory) then
        print("device_members_test: skipped, no iOS 6.0 inventory at " .. inventory .. "; the committed device-members.txt was not checked against it")
        return
    end
    local committed = io.readfile(lowered.device_members_file())
    local expected = lowered.device_text(lowered.device_members_of(workspace.sdk(), inventory))
    assert(committed == expected, "frameworks/Backports/tools/device-members.txt no longer matches the iOS 6.0 inventory: run "
           .. "./xmakew l -P . frameworks/Backports/tools/device_members.lua and commit the result")
end
