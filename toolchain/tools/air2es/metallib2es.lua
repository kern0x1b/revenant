import("core.base.json")

local binary = {encoding = "binary"}

local function quoted(text)
    local escapes = {['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t'}
    return '"' .. text:gsub('[%c"\\]', function(c)
        return escapes[c] or string.format("\\u%04x", c:byte())
    end) .. '"'
end

local function install_name(data)
    local name = nil
    local pos = 1
    while true do
        local found = data:find("NAME", pos, true)
        if found == nil or #data < found + 5 then
            break
        end
        local length = string.unpack("<I2", data, found + 4)
        local stop = found + 6 + length
        if data:sub(stop, stop + 3) == "ENDT" then
            name = data:sub(found + 6, stop - 1):gsub("%z$", "")
        end
        pos = found + 1
    end
    return name
end

function main(tool, metallib, out)
    local data = io.readfile(metallib, binary)
    local installName = install_name(data)
    os.mkdir(out)
    local functions = {}
    local pos = 1
    local index = 0
    while true do
        local found = data:find("\xDE\xC0\x17\x0B", pos, true)
        if found == nil then
            break
        end
        local _, _, start, size = string.unpack("<I4I4I4I4I4", data, found)
        local module = path.join(out, "module" .. index .. ".bc")
        io.writefile(module, data:sub(found + start, found + start + size - 1), binary)
        local prefix = path.join(out, "module" .. index)
        local stdout = prefix .. ".out"
        local rc = os.execv(tool, {module, prefix}, {try = true, stdout = stdout, stderr = os.nuldev()})
        io.write(io.readfile(stdout, binary))
        os.rm(stdout)
        os.rm(module)
        if rc == 0 then
            local reflection = json.decode(io.readfile(prefix .. ".json"))
            local source = path.basename(prefix) .. (reflection.stage == "vertex" and ".vert" or ".frag")
            table.insert(functions, {name = reflection.entry, stage = reflection.stage, source = source,
                                     reflection = path.basename(prefix) .. ".json"})
        end
        index = index + 1
        pos = found + 4
    end

    local lines = {"{"}
    if #functions == 0 then
        table.insert(lines, installName and ' "functions": [],' or ' "functions": []')
    else
        table.insert(lines, ' "functions": [')
        for i, f in ipairs(functions) do
            table.insert(lines, "  {")
            table.insert(lines, '   "name": ' .. quoted(f.name) .. ",")
            table.insert(lines, '   "stage": ' .. quoted(f.stage) .. ",")
            table.insert(lines, '   "source": ' .. quoted(f.source) .. ",")
            table.insert(lines, '   "reflection": ' .. quoted(f.reflection))
            table.insert(lines, i < #functions and "  }," or "  }")
        end
        table.insert(lines, installName and " ]," or " ]")
    end
    if installName then
        table.insert(lines, ' "installName": ' .. quoted(installName))
    end
    table.insert(lines, "}")
    io.writefile(path.join(out, "library.json"), table.concat(lines, "\n"), binary)
end
