local function dyld()
    return import("apple.dyld", {rootdir = path.join(os.scriptdir(), "..", "..", "toolchain", "modules"), anonymous = true})
end

function absent(cache, symbols, provided)
    local loaded = dyld().load(cache)
    local linked = {}
    for line in io.lines(provided) do
        linked[line] = true
    end
    local found = {}
    for symbol in io.lines(symbols) do
        if loaded.exports[symbol] == nil and not linked[symbol] then
            table.insert(found, symbol)
        end
    end
    return found
end

function main(cache, symbols, provided)
    for _, symbol in ipairs(absent(cache, symbols, provided)) do
        print("%s", symbol)
    end
end
