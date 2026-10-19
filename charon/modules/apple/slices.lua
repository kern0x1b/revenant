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
