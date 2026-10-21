local modules = path.join(os.scriptdir(), "..", "..", "modules")
local emulator = import("emulator", {rootdir = modules, anonymous = true})
local workspace = import("workspace", {rootdir = modules, anonymous = true})

function folder(name)
    local given = os.getenv("OUT_DIR")
    if given and given ~= "" then
        return given
    end
    return workspace.run(name)
end

function images()
    return path.join(emulator.root(), "images.noindex")
end

function split(text)
    local found = {}
    for line in text:gmatch("[^\n]+") do
        table.insert(found, line)
    end
    return found
end

function lines(file)
    return split(os.isfile(file) and io.readfile(file) or "")
end

function contains(file, text)
    local content = os.isfile(file) and io.readfile(file) or ""
    return content:find(text, 1, true) ~= nil
end

function images_of(project)
    local found = {}
    for _, file in ipairs(os.files(path.join(images(), "*", "*", "image.json"))) do
        if contains(file, project) then
            table.insert(found, path.directory(file))
        end
    end
    table.sort(found)
    return found
end

function uuid(file)
    local output = try {
        function ()
            return os.iorunv("/usr/bin/otool", {"-l", file})
        end,
        catch {
            function ()
                return ""
            end
        }
    }
    local listed = split(output)
    for index, line in ipairs(listed) do
        if line:find("LC_UUID", 1, true) and listed[index + 2] then
            return listed[index + 2]:match("^%s*%S+%s+(%S+)")
        end
    end
end
