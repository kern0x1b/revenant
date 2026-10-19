local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})

less = byteorder.less

function strings(list)
    local out = table.move(list, 1, #list, 1, {})
    byteorder.sort(out)
    return out
end

keys = byteorder.keys
