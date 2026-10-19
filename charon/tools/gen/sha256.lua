import("core.base.bytes")

local EMPTY = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

function hex(message)
    if message == "" then
        return EMPTY
    end
    return hash.sha256(bytes(message))
end
