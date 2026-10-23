local STUBBED = {
    "NSDateInterval", "NSDimension", "NSISO8601DateFormatter", "NSMeasurement", "NSOrderedCollectionChange",
    "NSOrderedCollectionDifference", "NSPersonNameComponents", "NSPresentationIntent", "NSURLComponents",
    "NSURLQueryItem", "NSURLSessionWebSocketMessage", "NSUnitConverterLinear",
}

function class_names()
    local names = {}
    for _, name in ipairs(STUBBED) do
        table.insert(names, name)
    end
    return names
end

function stub_directory(sdk, out)
    local folder = path.join(out, "Foundation.framework")
    os.mkdir(folder)
    local text = io.readfile(path.join(sdk, "System", "Library", "Frameworks", "Foundation.framework", "Foundation.tbd"))
    for _, name in ipairs(STUBBED) do
        text = (text:gsub("([%s,])" .. name .. ",%s*", "%1"))
    end
    io.writefile(path.join(folder, "Foundation.tbd"), text)
    return out
end

function link_flags(out)
    local flags = {"-F", out}
    for _, name in ipairs(class_names()) do
        table.join2(flags, {"-Xlinker", "-U", "-Xlinker", "_OBJC_CLASS_$_" .. name})
    end
    return flags
end
