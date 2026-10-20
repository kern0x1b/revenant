local SHOWN = 60

local function count(text, old)
    local found, at = 0, 1
    while true do
        local first, last = text:find(old, at, true)
        if not first then
            return found
        end
        found = found + 1
        at = last + 1
    end
end

local function replaced(text, old, new, limit)
    local pieces, at, done = {}, 1, 0
    while not limit or done < limit do
        local first, last = text:find(old, at, true)
        if not first then
            break
        end
        table.insert(pieces, text:sub(at, first - 1))
        table.insert(pieces, new)
        at = last + 1
        done = done + 1
    end
    table.insert(pieces, text:sub(at))
    return table.concat(pieces)
end

local MODES = {
    first = function (found)
        return found >= 1, 1, "at least once"
    end,
    once = function (found)
        return found == 1, 1, "exactly once"
    end,
    all = function (found)
        return found >= 1, nil, "at least once"
    end
}

function substitute(mode, file, edits)
    local rule = MODES[mode]
    if not rule then
        raise("substitute.lua: the mode is first, once or all, not %s", tostring(mode))
    end
    if #edits == 0 or #edits % 2 ~= 0 then
        raise("substitute.lua: pass the text to replace and its replacement in pairs")
    end
    local text = io.readfile(file, {encoding = "binary"})
    for index = 1, #edits, 2 do
        local old, new = edits[index], edits[index + 1]
        local found = count(text, old)
        local fits, limit, wanted = rule(found)
        if not fits then
            raise("the mutation did not apply, so this run proves nothing: %s holds %q %d times and it has to be there %s",
                  file, old:sub(1, SHOWN), found, wanted)
        end
        text = replaced(text, old, new, limit)
    end
    io.writefile(file, text, {encoding = "binary"})
end

function main(mode, file, ...)
    local failure
    local arguments = {...}
    try {
        function ()
            substitute(mode, file, arguments)
        end,
        catch {
            function (errors)
                failure = tostring(errors)
            end
        }
    }
    if failure then
        io.stderr:write("FAIL " .. failure .. "\n")
        os.exit(1)
    end
end
