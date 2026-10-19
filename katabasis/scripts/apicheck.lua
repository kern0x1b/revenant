function main(cache, architecture, ...)
    local root = path.join(os.getenv("HOME"), "Git/projects/ios/charon/modules")
    local dyld = import("apple.dyld", {rootdir = root, anonymous = true})
    local objc = import("apple.objc", {rootdir = root, anonymous = true})
    local binaries = {...}
    local missing = dyld.missing_imports(cache, binaries)
    print("== imports absent from iOS 6.0 (" .. #missing .. ")")
    for _, entry in ipairs(missing) do
        print("  " .. path.filename(entry[1]) .. "  " .. entry[2])
    end
    local absent = objc.absent_selectors(cache, binaries, architecture)
    for binary, names in pairs(absent) do
        print("== selectors used by " .. path.filename(binary) .. " that iOS 6.0 and the app do not implement (" .. #names .. ")")
        for _, name in ipairs(names) do
            print("  " .. name)
        end
    end
end
