function main(cache, symbols, provided)
    local root = path.join(os.getenv("HOME"), "Git/projects/ios/charon/modules")
    local dyld = import("apple.dyld", {rootdir = root, anonymous = true})
    local loaded = dyld.load(cache)
    local linked = {}
    for line in io.lines(provided) do
        linked[line] = true
    end
    for symbol in io.lines(symbols) do
        if loaded.exports[symbol] == nil and not linked[symbol] then
            print(symbol)
        end
    end
end
