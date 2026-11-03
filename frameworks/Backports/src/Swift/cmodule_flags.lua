function apply(target, root, folder, cmodules)
    for _, cmodule in ipairs(cmodules) do
        target:add("values", "swift.flags", "-I" .. path.join(root, folder, cmodule))
    end
end
