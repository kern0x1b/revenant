local atomic = import("atomic", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})

local written = 0

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

function file(filepath, text, identifiers)
    local run = refused(text, identifiers)
    local shown = run and string.gsub(run, "[\128-\255]", function(c) return string.format("\\x%02x", string.byte(c)) end)
    assert(run == nil, "not ASCII: " .. filepath .. " (" .. tostring(shown) .. ")")
    if not atomic.write(filepath, text) then
        return false
    end
    written = written + 1
    return true
end

function count()
    return written
end
