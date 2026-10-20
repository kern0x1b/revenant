function report(cache, binaries)
    local dyld = import("@addon.revenant.apple.dyld", {anonymous = true})
    local missing, count, loaded = dyld.missing_imports(cache, binaries)
    local lines = {}
    for _, entry in ipairs(missing) do
        table.insert(lines, entry[1] .. "  " .. entry[2])
    end
    table.insert(lines, string.format("binaries=%d missing=%d exports=%d architecture=%s", count, #missing, loaded.count, loaded.architecture))
    return lines
end

function main(cache, ...)
    for _, line in ipairs(report(cache, {...})) do
        print("%s", line)
    end
end
