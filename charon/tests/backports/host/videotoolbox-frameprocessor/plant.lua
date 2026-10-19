-- plant.lua - replace one exact line of one file, or report that the needle is not there.
--
--     xmake l plant.lua FILE FROM TO
--
-- Exits non-zero when the needle is absent. That is the whole point: a plant that quietly did not apply
-- measures the unmutated tree and reports the mutant as caught, which is the same shape of output a real
-- catch has.

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
