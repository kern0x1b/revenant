local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})

function main()
    local src = path.absolute(path.join(os.scriptdir(), "..", "src"))
    local parsed = lowered.parse(io.readfile(lowered.members_file()))
    local device = lowered.read_device_members()
    local shadows = lowered.shadowed_classes(src, parsed, device)
    io.writefile(lowered.shadowed_file(), lowered.shadowed_text(shadows))
    print(lowered.shadowed_file())
end
