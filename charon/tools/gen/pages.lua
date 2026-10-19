-- The file names of the pages of one folder of the worker page set (cmd_doc.lua's <out>/<framework>/, behaviour.lua's behaviour/
-- folder of it). A page is named after what it describes, so the name is the entity's own where that is unique, and a name that
-- would be shared is disambiguated from the entity's identity, never from the order the pages are written in:
--   * a class page is <Name>.md and a protocol page is <Name>.protocol.md, so a class and a protocol of one name (NFCReaderSession)
--     are two pages;
--   * two names that differ only in case (Matter's MTRBaseClusterWakeOnLAN and MTRBaseClusterWakeOnLan) are one file on a
--     case-insensitive file system (APFS, HFS+, the default of the machine this runs on). Every page of such a group, and any page
--     whose file name equals one of the folder's own files (index.md, Constants.md, Swift.md) when folded, is named
--     <Name>.<first 8 hex digits of the SHA-256 of "<kind> <Name>">.md (or .protocol.md): a pure function of the entity, the same on
--     every run and every machine. Each name of such a group takes the suffix, so a page keeps its name when a further name of the
--     group appears.
-- The names are checked once more after the disambiguation: two pages that still fold to one file name raise, naming both, instead of
-- one overwriting the other.

local digest = import("digest", {anonymous = true})

local EXTENSION = {class = ".md", protocol = ".protocol.md"}
local SUFFIX_LENGTH = 8

-- The key of an entity in the table names() returns.
function key(kind, name)
    return kind .. " " .. name
end

-- The file names of the pages of one folder. entries: a list of {kind = "class" | "protocol", name = the entity's name}; reserved: the
-- names of the files the folder holds besides these pages. Returns a table from key(kind, name) to the file name.
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
