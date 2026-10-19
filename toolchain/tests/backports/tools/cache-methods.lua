local objc = import("apple.objc", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "modules"), anonymous = true})

function methods(cachefile, image, classes)
    local rows = {}
    for _, row in ipairs(objc.image_methods(cachefile, image, classes)) do
        table.insert(rows, string.format("%s[%s %s]\t0x%x", row.meta and "+" or "-", row.class, row.selector, row.imp))
    end
    return rows
end

function main(cachefile, image, ...)
    if not cachefile or not image then
        raise("usage: xmake l cache-methods.lua <dyld_shared_cache> <image> [class ...]")
    end
    for _, line in ipairs(methods(cachefile, image, {...})) do
        io.write(line, "\n")
    end
end
