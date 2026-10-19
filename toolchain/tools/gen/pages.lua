local digest = import("digest", {anonymous = true})

local EXTENSION = {class = ".md", protocol = ".protocol.md"}
local SUFFIX_LENGTH = 8

function key(kind, name)
    return kind .. " " .. name
end

function names(entries, reserved)
    local plain, count = {}, {}
    local function fold(file)
        assert(not string.find(file, "[\128-\255]"), "a page name is ASCII: " .. file)
        return string.lower(file)
    end
    for _, file in ipairs(reserved) do
        count[fold(file)] = (count[fold(file)] or 0) + 1
    end
    for _, entry in ipairs(entries) do
        local extension = EXTENSION[entry.kind]
        assert(extension, "unknown page kind: " .. tostring(entry.kind))
        local file = entry.name .. extension
        plain[key(entry.kind, entry.name)] = file
        count[fold(file)] = (count[fold(file)] or 0) + 1
    end
    local out, owner = {}, {}
    for _, file in ipairs(reserved) do
        owner[fold(file)] = file
    end
    for _, entry in ipairs(entries) do
        local id = key(entry.kind, entry.name)
        local file = plain[id]
        if count[fold(file)] > 1 then
            file = entry.name .. "." .. string.sub(digest.digest_of(id), 1, SUFFIX_LENGTH) .. EXTENSION[entry.kind]
        end
        local clash = owner[fold(file)]
        assert(clash == nil, string.format("pages of %s and %s have one file name on a case-insensitive file system: %s", id,
                                           tostring(clash), file))
        owner[fold(file)] = id
        out[id] = file
    end
    return out
end
