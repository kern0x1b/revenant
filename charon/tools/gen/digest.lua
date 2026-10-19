local sha256 = import("sha256", {anonymous = true})

function digest(...)
    return string.sub(sha256.hex(table.concat({...}, "\31")), 1, 16)
end

function digest_of(text)
    return sha256.hex(text)
end
