local function names_of(text, names, engine)
    for line in (text .. "\n"):gmatch("(.-)\n") do
        local class = line:match("^@interface%s+(MLC[%w_]+)") or line:match("^@implementation%s+(MLC[%w_]+)")
        if class then
            names[class] = true
        end
        local function_name = line:match("^NSString %*%s+(MLC[%w_]+)%(")
            or line:match("^NSUInteger%s+(MLC[%w_]+)%(")
            or line:match("^void%s+(MLC[%w_]+)%(")
            or line:match("^BOOL%s+(MLC[%w_]+)%(")
            or (engine and line:match("^double%s+(MLC[%w_]+)%("))
        if function_name then
            names[function_name] = true
        end
        local bare = line:match("^%s*(MLC[%w_]+),?$")
        if bare then
            names[bare] = true
        end
    end
    for word in text:gmatch("[%w_]+") do
        if (word:sub(1, 11) == "MLCDataType" and #word > 11) or (word:sub(1, 14) == "MLCPoolingType" and #word > 14) then
            names[word] = true
        end
    end
end

function rename(port, header, engine)
    local names = {}
    local files = {}
    local patterns = {"*.m", "*.h"}
    if engine then
        table.insert(patterns, "*.mm")
    end
    for _, pattern in ipairs(patterns) do
        for _, file in ipairs(os.files(path.join(port, pattern))) do
            table.insert(files, file)
        end
    end
    table.sort(files)
    for _, file in ipairs(files) do
        names_of(io.readfile(file), names, engine)
    end
    local sorted = {}
    for name in pairs(names) do
        table.insert(sorted, name)
    end
    table.sort(sorted)
    local out = {}
    for _, name in ipairs(sorted) do
        table.insert(out, string.format("#define %s Revenant%s\n", name, name))
    end
    io.writefile(header, table.concat(out))
    print(string.format("renamed %d names", #sorted))
    return 0
end

function main(port, header, engine)
    os.exit(rename(port, header, engine == "engine"))
end
