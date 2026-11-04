local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})
local lowered = import("lowered", {rootdir = path.join(os.scriptdir(), "..", "..", "modules", "apple"), anonymous = true})

function failures(arguments)
    local found = {}
    local output = workspace.run("overlay-cache")
    os.rm(output)
    os.mkdir(output)
    local first = path.join(output, "first", "overlay")
    local second = path.join(output, "second", "overlay")

    local vfs_first = lowered.overlay(arguments.sdk, first)
    local shared_vfs = nil
    if os.islink(first) then
        shared_vfs = path.join(os.readlink(first), "vfs.yaml")
    else
        table.insert(found, "the first overlay is not a link into the shared overlay folder")
    end
    local built_at = shared_vfs and os.isfile(shared_vfs) and os.mtime(shared_vfs)
    if shared_vfs and not os.isfile(shared_vfs) then
        table.insert(found, "the first overlay is a link to a folder with no vfs.yaml")
    end

    local vfs_second = lowered.overlay(arguments.sdk, second)
    if not os.islink(second) then
        table.insert(found, "the second overlay of the same input is not a link into the shared folder")
    elseif shared_vfs and os.readlink(second) ~= os.readlink(first) then
        table.insert(found, "two outputs of one input link to two overlays: " .. os.readlink(first) .. " and " .. os.readlink(second))
    end
    if not os.isfile(vfs_first) or not os.isfile(vfs_second) then
        table.insert(found, "an overlay call returned a vfs.yaml that is not there")
    end
    if built_at and os.mtime(shared_vfs) ~= built_at then
        table.insert(found, "the second call rebuilt the shared overlay that the first call had built")
    end

    os.rm(path.join(output, "first"))
    if shared_vfs and not os.isfile(shared_vfs) then
        table.insert(found, "removing an output's link removed the shared overlay it points to")
    end
    return found
end
