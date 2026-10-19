function main(cache, ...)
    local root = path.join(os.getenv("HOME"), "Git/projects/ios/charon/modules")
    local dyld = import("apple.dyld", {rootdir = root, anonymous = true})
    local missing = dyld.missing_imports(cache, {...})
    for _, entry in ipairs(missing) do
        local symbol = entry[2]:match("^(_OBJC_CLASS_%$_[%w_]+)")
        if symbol then
            print(symbol:sub(#"_OBJC_CLASS_$_" + 1))
        end
    end
end
