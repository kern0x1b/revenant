local tsv = import("tsv", {rootdir = os.scriptdir()})

function main(...)
    local args = {...}
    if #args < 3 then
        io.stderr:write("mutate.lua: pass the file, the API and the value\n")
        os.exit(1)
    end
    local path, api, value = args[1], args[2], args[3]
    local text = tsv.read_text(path)
    local needle = 'const CFStringRef ' .. api .. ' = CFSTR("'
    local count = tsv.count_of(text, needle)
    if count ~= 1 then
        print("expected exactly one " .. api .. ", found " .. count)
        os.exit(1)
    end
    local _, e = text:find(needle, 1, true)
    local start = e + 1
    local close = text:find('");', start, true)
    if not close then
        io.stderr:write("no closing \");\" after " .. api .. "\n")
        os.exit(1)
    end
    local out = text:sub(1, start - 1) .. value .. text:sub(close)
    local handle = assert(io.open(path, "wb"))
    handle:write(out)
    handle:close()
    print("mutated " .. api .. " to [" .. value .. "]")
    os.exit(0)
end
