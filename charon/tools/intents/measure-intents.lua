function main(list, sdkdir, output, modules)
    local dyld = import("apple.dyld", {rootdir = modules, anonymous = true})
    local symbols = {}
    for line in io.readfile(list):gmatch("[^\n]+") do
        local name = line:match("^%s*(.-)%s*$")
        if name ~= "" then
            table.insert(symbols, "_OBJC_CLASS_$_" .. name)
        end
    end
    local ladder = dyld.held_ladder({"armv7", "armv7s"})
    print("ladder: %d releases, %s .. %s", #ladder, ladder[1].release, ladder[#ladder].release)
    local first = dyld.first_releases(ladder, sdkdir, symbols)
    local lines, measured, none = {}, {}, {}
    for _, symbol in ipairs(symbols) do
        local name, release = symbol:sub(14), first[symbol]
        if release then
            measured[release] = (measured[release] or 0) + 1
            table.insert(lines, string.format("%s\t%s", name, release))
        else
            table.insert(none, name)
        end
    end
    io.writefile(output, table.concat(lines, "\n") .. "\n")
    if #none > 0 then
        io.writefile(output .. ".absent", table.concat(none, "\n") .. "\n")
    end
    for _, release in ipairs({"10.0.1", "10.1.1", "10.2", "10.2.1", "10.3", "10.3.4", "11.0", "12.0", "16.0", "18.0"}) do
        if measured[release] then
            print("first exported in %s: %d classes", release, measured[release])
        end
    end
    print("no held release exports %d of them: %s", #none, table.concat(none, " "))
end
