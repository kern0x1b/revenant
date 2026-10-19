local counter = 0

local function read_bytes(filepath)
    if not os.isfile(filepath) then
        return nil
    end
    local handle = assert(io.open(filepath, "rb"))
    local data = handle:read("a")
    handle:close()
    return data
end

local function sibling_of(filepath)
    while true do
        counter = counter + 1
        local sibling = string.format("%s.charon-new.%d.%d", filepath, os.getpid(), counter)
        if not os.exists(sibling) then
            return sibling
        end
    end
end

function write(filepath, text)
    if read_bytes(filepath) == text then
        return false
    end
    os.mkdir(path.directory(filepath))
    local sibling = sibling_of(filepath)
    try {
        function()
            local handle = assert(io.open(sibling, "wb"))
            handle:write(text)
            assert(handle:close())
            os.mv(sibling, filepath)
        end,
        catch {
            function(err)
                os.tryrm(sibling)
                raise("%s", err)
            end
        }
    }
    return true
end
