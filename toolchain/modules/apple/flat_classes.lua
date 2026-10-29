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
        framework = "UIKit",
        classes = {"UIPointerEffect", "UIPointerShape", "UIPointerStyle"},
    },
    {
        framework = "CoreText",
        functions = {
            "CTFrameDraw", "CTFrameGetLineOrigins", "CTFramesetterSuggestFrameSizeWithConstraints", "CTLineDraw",
            "CTLineGetBoundsWithOptions", "CTLineGetImageBounds", "CTLineGetTypographicBounds", "CTRunDraw",
        },
    },
}

local EXPORTED = {NSURLComponents = true, NSURLQueryItem = true, UIPointerEffect = true, UIPointerShape = true, UIPointerStyle = true}

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

function is_exported(name)
    return EXPORTED[name] == true
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

local WRITTEN = {}

local function stubs_present(out)
    for _, entry in ipairs(STUBBED) do
        if not os.isfile(path.join(out, entry.framework .. ".framework", entry.framework .. ".tbd")) then
            return false
        end
    end
    return true
end

function stub_directory(sdk, out)
    local key = sdk .. "\n" .. out
    if WRITTEN[key] and stubs_present(out) then
        return out
    end
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
    WRITTEN[key] = true
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
