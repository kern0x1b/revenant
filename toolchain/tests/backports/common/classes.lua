local SYMBOL = "_OBJC_CLASS_$_"

local function trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

function defined(file)
    local names, seen = {}, {}
    for line in io.lines(file) do
        local name = trim(line)
        if name:sub(1, #SYMBOL) == SYMBOL then
            name = name:sub(#SYMBOL + 1)
        end
        if name ~= "" and not seen[name] then
            seen[name] = true
            table.insert(names, name)
        end
    end
    return names, seen
end

function implemented(folder, prefix)
    local names, seen = {}, {}
    local files = os.isfile(folder) and {folder} or os.files(path.join(folder, "*.m"))
    table.sort(files)
    for _, file in ipairs(files) do
        for line in io.lines(file) do
            local name = line:match("^@implementation%s+([%w_]+)")
            if name and name:sub(1, #prefix) == prefix and not seen[name] then
                seen[name] = true
                table.insert(names, name)
            end
        end
    end
    table.sort(names)
    return names
end

function write(names, header, prefix)
    local out = {}
    for _, name in ipairs(names) do
        table.insert(out, string.format("#define %s %s%s\n", name, prefix or "Revenant", name))
    end
    io.writefile(header, table.concat(out))
end

local commands = {}

function commands.rename(defines, header)
    local names = defined(defines)
    local renamable = {}
    for _, name in ipairs(names) do
        if not name:find("^Revenant") then
            table.insert(renamable, name)
        end
    end
    write(renamable, header)
    print(string.format("classes the port defines: %d, renamed: %d", #names, #renamable))
end

function commands.implemented(folder, prefix, header)
    write(implemented(folder, prefix), header)
end

function commands.require(defines, ...)
    local _, seen = defined(defines)
    local wanted = {...}
    local missing = {}
    for _, name in ipairs(wanted) do
        if not seen[name] then
            table.insert(missing, name)
        end
    end
    if #missing > 0 then
        print("the port's objects do not define: " .. table.concat(missing, ", "))
        os.exit(1)
    end
    print(string.format("the port's objects define all %d classes this harness compares", #wanted))
end

function main(command, ...)
    local run = commands[command or ""]
    if not run then
        io.stderr:write("usage: classes.lua rename <defines> <rename.h> | implemented <folder-or-file> <prefix> <rename.h> | require <defines> <class>...\n")
        os.exit(2)
    end
    run(...)
end
