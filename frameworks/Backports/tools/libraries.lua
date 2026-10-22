local reader = import("reader", {rootdir = os.scriptdir(), anonymous = true})

local function objc()
    return import("@addon.revenant.apple.objc", {anonymous = true})
end

function read(libdir)
    local files = os.files(path.join(libdir, "lib*.dylib"))
    assert(#files > 0, "no lib*.dylib in " .. libdir)
    local libraries, index = {}, {}
    for _, file in ipairs(files) do
        local library = {name = path.filename(file), symbols = {}, methods = {}}
        table.insert(libraries, library)
        index[file] = library
    end
    reader.each_output("nm", {"-gU"}, files, function (file, line)
        local letter, name = line:match("^%x+ (%a) (%S+)$")
        if name then
            index[file].symbols[name] = letter
        end
    end)
    local inventory = objc()
    for _, file in ipairs(files) do
        local found = inventory.binary_inventory(file, "armv7")
        assert(found, "no armv7 Objective-C metadata in " .. file)
        local library = index[file]
        for name, class in pairs(found.classes) do
            local owner = name
            if name:startswith("Revenant") and library.symbols["_OBJC_CLASS_$_" .. name:sub(9)] then
                owner = name:sub(9)
            end
            for selector in pairs(class.instance) do
                library.methods["instance method|" .. owner .. "|" .. selector:sub(2)] = true
            end
            for selector in pairs(class.class) do
                library.methods["class method|" .. owner .. "|" .. selector:sub(2)] = true
            end
        end
    end
    local symbols, methods = 0, 0
    for _, library in ipairs(libraries) do
        for _ in pairs(library.symbols) do
            symbols = symbols + 1
        end
        for _ in pairs(library.methods) do
            methods = methods + 1
        end
    end
    assert(symbols > 0 and methods > 0, string.format("%d symbols and %d methods read from %s", symbols, methods, libdir))
    return libraries
end
