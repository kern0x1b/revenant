import("device", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "..", "modules")})

function main(source, destination, ...)
    local fetch = ({...})[1] == "--fetch"
    assert(source and destination, "usage: copy.lua <local> <remote> | copy.lua <remote> <local> --fetch")
    local bound = device.bind(os.projectdir(), nil)
    if fetch then
        device.fetch(bound, source, destination)
    else
        device.copy(bound, source, destination)
    end
end
