-- The member rows of a framework from its shard facts (headers.shard_facts, design-foundation.md 5.7): the port of member_rows in
-- tools/gen.py@52253c0650 on the IR. One row per member, the first occurrence per api. A member's api is side, "[", the class, a space, the
-- name and "]": the class is the one the USR names (a category member keeps its class), and the side is the shard's: "+" for a
-- class method or class property (section 3.5). Protocol members are not in the shards (the protocols transcriber owns them).
-- The spec's type column is the shard's type (the typed shards, design-foundation.md 5.7); the declaration text is not a spec column
-- (ruling D8: the docs generator re-derives it at doc time). The availability is the text rendered from the IR's fields (ruling D7);
-- the hash is the declaration hash (the IR's declhash).

-- The mangled key of an api: a C identifier. A class member's key starts with class_, so it never collides with an instance member
-- of the same selector (mangle in tools/gen.py@52253c0650).
function mangle(api)
    local body = string.gsub(string.gsub(api, "[^A-Za-z0-9]+", "_"), "^_+", "")
    body = string.gsub(body, "_+$", "")
    if string.sub(api, 1, 1) == "+" then
        return "class_" .. body
    end
    return body
end

-- The spec rows of a framework's members, from its shard facts. classes is the set of the class names the arm64 slice exports
-- (tbd.exports), or nil when no SDK is given (the in-memory build of gen and check): the tbd column is then "-". tbd is
-- "class-exported" for a member whose class is in the set, else "class-not-exported". No consumer reads a member's tbd; a constant's
-- is read (render, scope and diff).
function rows(members, classes, framework)
    local out, seen = {}, {}
    for _, m in ipairs(members) do
        if not seen[m.api] then
            seen[m.api] = true
            local tbd = "-"
            if classes ~= nil then
                tbd = classes[m.cls] and "class-exported" or "class-not-exported"
            end
            table.insert(out, {kind = m.kind, api = m.api, cls = m.cls, key = mangle(m.api), introduced = "-", type = m.type or "-",
                               availability = m.text ~= "" and m.text or "-", hash = m.hash, value_status = "-", value = "-",
                               host_value = "-", value_source = "-", owned = "-", tbd = tbd, shape = "-", measured = "-"})
        end
    end
    return out
end
