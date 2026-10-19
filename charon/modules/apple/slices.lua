-- The release the slice of a universal target is built for. The slices are built one architecture at a time, and
-- apple_minimum names the oldest release any of them keeps: an architecture that first ran a later release (arm64: 7.0) has
-- its slice built for that release, and the port is told so. An architecture built alone, or with slices none of which keeps
-- the declared release, is not one of these: the toolchain refuses it, since no slice would keep what the port declared.
-- The file has no imports so that a project's includes can include it as well as a rule import it, and the toolchain's
-- own bounds, in architectures.lua, are not its to change (they are in the digest of every package's build): a test
-- compares the two.
local FLOORS = {armv6 = "2.0", armv7 = "3.0", armv7s = "6.0", arm64 = "7.0"}
local LASTS = {armv6 = "4.2.1"}

local function release_older(a, b)
    local left, right = {}, {}
    for number in a:gmatch("%d+") do table.insert(left, tonumber(number)) end
    for number in b:gmatch("%d+") do table.insert(right, tonumber(number)) end
    for index = 1, math.max(#left, #right) do
        if (left[index] or 0) ~= (right[index] or 0) then
            return (left[index] or 0) < (right[index] or 0)
        end
    end
    return false
end

-- slices is what packaging hands a slice build (CHARON_SLICES): the architectures of the universal target, comma-separated.
-- Answers the release the slice is built for, and the other slice that keeps the declared release where it is not that.
function slice_minimum(architecture, declared, slices)
    if not slices or not FLOORS[architecture] or not release_older(declared, FLOORS[architecture]) then
        return declared
    end
    for other in slices:gmatch("[^,]+") do
        if other ~= architecture and FLOORS[other] and not release_older(declared, FLOORS[other]) and
           not (LASTS[other] and release_older(LASTS[other], declared)) then
            return FLOORS[architecture], other
        end
    end
    return declared
end

function slice_floors()
    return FLOORS, LASTS
end
