function main(modules, cachefile, install, outputfile)
    local dyld = import("apple.dyld", {rootdir = modules, anonymous = true})
    local taken = dyld.extract(cachefile, install, outputfile)
    local handle = io.open(outputfile, "rb")
    if not handle then
        raise("extract() reported " .. tostring(taken.symbols) .. " symbols but wrote no " .. outputfile)
    end
    local size = handle:seek("end")
    handle:close()
    if size == 0 then
        raise("extract() wrote an empty " .. outputfile)
    end
    print("extracted " .. install .. ": " .. tostring(#taken.segments) .. " segments, "
          .. tostring(taken.symbols) .. " symbols, " .. tostring(math.tointeger(size)) .. " bytes")
end
