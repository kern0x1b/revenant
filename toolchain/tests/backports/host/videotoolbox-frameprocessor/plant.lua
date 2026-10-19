function main(...)
    local args = { ... }
    if #args ~= 3 then
        print("plant.lua: pass FILE FROM TO")
        os.exit(2)
    end
    local file, needle, replacement = args[1], args[2], args[3]
    local text = io.readfile(file)
    local first, last = text:find(needle, 1, true)
    if not first then
        io.stderr:write(string.format("plant.lua: %q is not in %s\n", needle, file))
        os.exit(1)
    end
    io.writefile(file, text:sub(1, first - 1) .. replacement .. text:sub(last + 1))
    os.exit(0)
end
