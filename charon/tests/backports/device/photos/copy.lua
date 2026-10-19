-- tests/backports/device/photos/copy.lua -- one file between this host and a device, through the
-- driver's own transport (which checks the claim, the tunnel and the UDID; a raw scp checks none).
--
--   CHARON_ROOT=<worktree> xmake l tests/backports/device/photos/copy.lua <local> <remote>   # push
--   CHARON_ROOT=<worktree> xmake l tests/backports/device/photos/copy.lua <remote> <local> --fetch
--
-- CHARON_DEVICE=<name> picks device.<name>.env, the same -d the transport itself takes. A missing
-- argument is a failure and not a silent no-op: this script's whole job is the transfer, and a run
-- that pushed nothing must not look like one that did.
import("device", {rootdir = path.join(os.getenv("HOME"), "Git/projects/ios/charon/modules")})

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
