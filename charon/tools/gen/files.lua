-- Reading the inputs: a whole file as text (nil when it is absent) and a glob in sorted order. Reads only; every write goes
-- through emit.

local order = import("order", {anonymous = true})

-- The text of a file, or nil when there is no such file.
function read_text(filepath)
    if not os.isfile(filepath) then
        return nil
    end
    local handle = io.open(filepath, "rb")
    local text = handle:read("a")
    handle:close()
    return text
end

-- The paths matching a pattern, sorted by their full path, in byte order.
function glob(pattern)
    local found = os.files(pattern)
    table.sort(found, order.less)
    return found
end

-- The name of the directory that holds a path.
function parent_name(filepath)
    return path.filename(path.directory(filepath))
end
