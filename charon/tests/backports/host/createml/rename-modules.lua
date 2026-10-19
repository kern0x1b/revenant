function main(root)
    for _, file in ipairs(os.files(path.join(root, "**.swift"))) do
        local text = io.readfile(file)
        assert(not text:find("PortCreateMLComponents", 1, true), file)
        assert(not text:find("PortCoreML", 1, true), file)
        text = text:gsub("%f[%w_]CreateMLComponents%f[^%w_]", "PortCreateMLComponents")
        if path.filename(path.directory(file)) ~= "CoreML" then
            text = renameCoreMLImports(text)
        end
        io.writefile(file, text)
    end
end

function renameCoreMLImports(text)
    text = "\n" .. text
    local changed = true
    while changed do
        local count
        text, count = text:gsub("\nimport CoreML\n", "\nimport PortCoreML\n")
        changed = count > 0
    end
    text = text:gsub("\nimport CoreML$", "\nimport PortCoreML")
    return text:sub(2)
end
