local COVERED = "measured by the host differential, tests/backports/host/realityfoundation, the check at main.swift:%s: %s"
local DECLARATION = "the declaration in packages/runtimes/swift-runtime/files/, which tests/backports/host/swiftregistry holds to a name, and the interface line it was read from. No check in this series measures it"

function what_this_row_should_say(hit)
    if hit[1] == "covered" then
        return string.format(COVERED, tostring(hit[2]), hit[3]:sub(1, 58))
    end
    return DECLARATION
end
