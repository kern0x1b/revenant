function main(cache, ...)
    local root = path.join(os.getenv("HOME"), "Git/projects/ios/charon/modules")
    local dyld = import("apple.dyld", {rootdir = root, anonymous = true})
    local missing, count, loaded = dyld.missing_imports(cache, {...})
    for _, entry in ipairs(missing) do
        print(entry[1] .. "  " .. entry[2])
    end
    print(string.format("binaries=%d missing=%d exports=%d architecture=%s", count, #missing, loaded.count, loaded.architecture))
end
