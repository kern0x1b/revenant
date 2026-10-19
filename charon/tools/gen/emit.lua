-- The writer of generated output in tools/gen (design-spec-driven.md D2). The bytes are written by the one atomic writer,
-- tools/atomic.lua, which the declaration driver (tools/found/ir.lua) uses for its shards too: a file the tree already holds is not
-- rewritten, and a changed file is replaced whole or not at all.

local atomic = import("atomic", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})

local written = 0

-- The first run of identifier bytes in text that is not ASCII and not one of the identifiers given (words the SDK's model holds,
-- spelled as the SDK spells them), or nil. A run is a maximal stretch of letters, digits, underscores and bytes above 0x7f, so an
-- identifier is taken whole: a model word inside a longer run is not allowed.
function refused(text, identifiers)
    local allowed = {}
    for _, word in ipairs(identifiers or {}) do
        allowed[word] = true
    end
    for run in string.gmatch(text, "[%w_\128-\255]+") do
        if string.find(run, "[\128-\255]") and not allowed[run] then
            return run
        end
    end
    return nil
end

-- Writes text to filepath when the file does not hold it already. The text is ASCII, except for the identifiers given (see
-- refused). Returns true when the file was written.
function file(filepath, text, identifiers)
    local run = refused(text, identifiers)
    -- the refused run is named in the message in ASCII (each byte above 0x7f as \xhh), so the message itself can be written
    local shown = run and string.gsub(run, "[\128-\255]", function(c) return string.format("\\x%02x", string.byte(c)) end)
    assert(run == nil, "not ASCII: " .. filepath .. " (" .. tostring(shown) .. ")")
    if not atomic.write(filepath, text) then
        return false
    end
    written = written + 1
    return true
end

-- The number of files written since the process started.
function count()
    return written
end
