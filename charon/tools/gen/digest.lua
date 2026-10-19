-- The declaration digests of the snapshot. A member's digest is the first 16 hex digits of the SHA-256 of its parts joined by
-- the unit separator; a manifest entry is the whole SHA-256 of the text the generator emits (design-spec-driven.md D4).

local sha256 = import("sha256", {anonymous = true})

-- The first 16 hex digits of the SHA-256 of the parts, joined by the unit separator.
function digest(...)
    return string.sub(sha256.hex(table.concat({...}, "\31")), 1, 16)
end

-- The SHA-256 of a text, as 64 hex digits.
function digest_of(text)
    return sha256.hex(text)
end
