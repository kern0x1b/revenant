local function byteorder_less(a, b)
    local shared = math.min(#a, #b)
    for at = 1, shared do
        local x, y = a:byte(at), b:byte(at)
        if x ~= y then
            return x < y
        end
    end
    return #a < #b
end

function digest(root)
    local files = os.files(path.join(root, "emulator", "**"))
    if #files == 0 then
        return nil
    end
    table.sort(files, byteorder_less)
    local digests = {}
    for _, file in ipairs(files) do
        table.insert(digests, path.relative(file, root) .. "=" .. hash.sha256(file))
    end
    return hash.strhash128(table.concat(digests, ";"))
end

function requirement_configs(root)
    local value = digest(root)
    if value == nil then
        return {}
    end
    return {sources = value}
end
