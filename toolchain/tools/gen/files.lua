local order = import("order", {anonymous = true})

function read_text(filepath)
    if not os.isfile(filepath) then
        return nil
    end
    local handle = io.open(filepath, "rb")
    local text = handle:read("a")
    handle:close()
    return text
end

function glob(pattern)
    local found = os.files(pattern)
    table.sort(found, order.less)
    return found
end

function parent_name(filepath)
    return path.filename(path.directory(filepath))
end
