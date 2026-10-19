-- SHA-256 (FIPS 180-4) of a string in memory, through xmake's own native implementation: hash.sha256 hashes a bytes object as well as
-- a file path, and the generator hashes text it has not written anywhere (design-spec-driven.md D4). The pure Lua rounds this module
-- held first took 3.7 s of a 7 s cold `gen --all` (31 MB of rendered text) and the declaration digests of every shard on top; the
-- native call takes the same text in tens of milliseconds and gives the same digests (tests/gen/gen_test.lua holds the FIPS vectors).

import("core.base.bytes")

-- xmake refuses an empty buffer ("invalid data and size(0)"), so the empty message is answered here: its digest is FIPS 180-4's
-- (NIST's published vector for the message of no bytes).
local EMPTY = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

-- The lowercase hex digest of a string (64 digits).
function hex(message)
    if message == "" then
        return EMPTY
    end
    return hash.sha256(bytes(message))
end
