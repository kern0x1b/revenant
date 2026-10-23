local STUBBED = {
    {
        framework = "Foundation",
        classes = {
            "NSDateInterval", "NSDimension", "NSISO8601DateFormatter", "NSMeasurement", "NSOrderedCollectionChange",
            "NSOrderedCollectionDifference", "NSPersonNameComponents", "NSPresentationIntent", "NSURLComponents",
            "NSURLQueryItem", "NSURLSessionWebSocketMessage", "NSUnitConverterLinear",
        },
    },
    {
        framework = "CFNetwork",
        classes = {"NSURLSessionWebSocketMessage"},
    },
}

function class_names()
    local names, seen = {}, {}
    for _, entry in ipairs(STUBBED) do
        for _, name in ipairs(entry.classes) do
            if not seen[name] then
                seen[name] = true
                table.insert(names, name)
            end
        end
    end
    return names
end

function stub_directory(sdk, out)
    for _, entry in ipairs(STUBBED) do
        local folder = path.join(out, entry.framework .. ".framework")
        os.mkdir(folder)
        local text = io.readfile(path.join(sdk, "System", "Library", "Frameworks", entry.framework .. ".framework", entry.framework .. ".tbd"))
        for _, name in ipairs(entry.classes) do
            text = (text:gsub("([%s,])" .. name .. ",%s*", "%1"))
        end
        io.writefile(path.join(folder, entry.framework .. ".tbd"), text)
    end
    return out
end

function link_flags(out)
    local flags = {"-F", out}
    for _, name in ipairs(class_names()) do
        table.join2(flags, {"-Xlinker", "-U", "-Xlinker", "_OBJC_CLASS_$_" .. name})
    end
    return flags
end
