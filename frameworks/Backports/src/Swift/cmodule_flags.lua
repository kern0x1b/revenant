function apply(target, root, folder, cmodules)
    for _, cmodule in ipairs(cmodules) do
        local directory = path.join(root, folder, cmodule)
        target:add("values", "swift.flags", "-I" .. directory)
        for _, header in ipairs(os.files(path.join(directory, "*"))) do
            target:add("values", "swift.inputs", header)
        end
    end
end
