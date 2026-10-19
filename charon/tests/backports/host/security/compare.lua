local tsv = import("tsv", {rootdir = os.scriptdir()})

local function read_rows(path)
    local dict, count = {}, 0
    for _, line in ipairs(tsv.text_lines(tsv.read_text(path))) do
        if line:find("\t", 1, true) then
            local fields = tsv.split_on(line, "\t")
            if #fields ~= 2 then
                io.stderr:write("compare.lua: " .. path .. ": a row has " .. #fields .. " fields, and 2 are required\n")
                os.exit(1)
            end
            if dict[fields[1]] == nil then
                count = count + 1
            end
            dict[fields[1]] = fields[2]
        end
    end
    return dict, count
end

function main(...)
    local args = {...}
    if args[1] == "--count" then
        if #args ~= 2 then
            io.stderr:write("compare.lua: --count takes one file\n")
            os.exit(1)
        end
        local _, count = read_rows(args[2])
        print(count)
        os.exit(0)
    end
    if #args ~= 2 then
        io.stderr:write("compare.lua: pass the host's rows and the port's rows\n")
        os.exit(1)
    end
    local system, system_count = read_rows(args[1])
    local port = read_rows(args[2])

    local names = {}
    for name in pairs(system) do
        names[#names + 1] = name
    end
    table.sort(names, tsv.byte_less)

    local bad = {}
    for _, name in ipairs(names) do
        local host_value = system[name]
        local port_value = port[name]
        if port_value ~= host_value then
            bad[#bad + 1] = name .. ": the host has [" .. host_value .. "] and the port has [" .. (port_value or "None") .. "]"
        end
    end
    for _, line in ipairs(bad) do
        print("DIFFERS " .. line)
    end
    if #bad > 0 then
        os.exit(1)
    end
    print("compared " .. system_count .. " constants: every one is the host's value")
    os.exit(0)
end
