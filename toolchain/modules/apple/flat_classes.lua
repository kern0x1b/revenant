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
    {
        framework = "CoreText",
        functions = {
            "CTFrameDraw", "CTFrameGetLineOrigins", "CTFramesetterSuggestFrameSizeWithConstraints", "CTLineDraw",
            "CTLineGetBoundsWithOptions", "CTLineGetImageBounds", "CTLineGetTypographicBounds", "CTRunDraw",
        },
    },
}

local EXPORTED = {NSURLComponents = true, NSURLQueryItem = true}

local function symbol_of(entry, name)
    if entry.functions then
        return "_" .. name
    end
    return "_OBJC_CLASS_$_" .. name
end

local function names_of(entry)
    return entry.classes or entry.functions
end

function class_names()
    local names, seen = {}, {}
    for _, entry in ipairs(STUBBED) do
        for _, name in ipairs(entry.classes or {}) do
            if not seen[name] then
                seen[name] = true
                table.insert(names, name)
            end
        end
    end
    return names
end

function weak_class_names()
    local names = {}
    for _, name in ipairs(class_names()) do
        if not EXPORTED[name] then
            table.insert(names, name)
        end
    end
    return names
end

function stubbed_symbols()
    local symbols, seen = {}, {}
    for _, entry in ipairs(STUBBED) do
        for _, name in ipairs(names_of(entry)) do
            local symbol = symbol_of(entry, name)
            if not seen[symbol] then
                seen[symbol] = true
                table.insert(symbols, symbol)
            end
        end
    end
    return symbols
end

local function cut(text, name)
    text = text:gsub("'" .. name .. "',%s*", "")
    text = text:gsub("([%s,%[])" .. name .. ",%s*", "%1")
    return text
end

local function listed(text, name)
    return text:find("[%s,%[']" .. name .. "'?[,%]%s]") ~= nil
end

function stub_directory(sdk, out)
    for _, entry in ipairs(STUBBED) do
        local folder = path.join(out, entry.framework .. ".framework")
        os.mkdir(folder)
        local text = io.readfile(path.join(sdk, "System", "Library", "Frameworks", entry.framework .. ".framework", entry.framework .. ".tbd"))
        for _, name in ipairs(names_of(entry)) do
            local listed_as = entry.functions and "_" .. name or name
            text = cut(text, listed_as)
            assert(not listed(text, listed_as), entry.framework .. ".tbd still lists " .. listed_as .. " after the stub cut it")
        end
        io.writefile(path.join(folder, entry.framework .. ".tbd"), text)
    end
    return out
end

function link_flags(out)
    local flags = {"-F", out}
    for _, symbol in ipairs(stubbed_symbols()) do
        table.join2(flags, {"-Xlinker", "-U", "-Xlinker", symbol})
    end
    return flags
end

function flat_symbols()
    local symbols = {}
    for _, symbol in ipairs(stubbed_symbols()) do
        symbols[symbol] = true
    end
    return symbols
end

function app_link_flags(sdk, out)
    local flags = {"-F", stub_directory(sdk, out)}
    for _, symbol in ipairs(stubbed_symbols()) do
        table.insert(flags, "-Wl,-U," .. symbol)
    end
    return flags
end
