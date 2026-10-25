local root = path.absolute(path.directory(os.scriptdir()))

local BOOTED = path.join(root, "emulator", "src", "kernel", "test", "kernel_snapshot_booted_members.hpp")

local USAGE = [[usage: ./xmakew l tools/booted_members.lua CENSUS [OUTPUT]

Regenerates the booted-state list in kernel_snapshot_booted_members.hpp from a census
file. The census is written by `emulator boot --ticks N --census-output CENSUS` at the
bounded stop. Names are sorted and de-duplicated. OUTPUT defaults to the list header.]]

local MEMBER = "^[%a][%w_]*%.[%w_]+$"

function main(...)
    local arguments = {...}
    if #arguments == 0 or arguments[1] == "help" or arguments[1] == "--help" then
        print(USAGE)
        return
    end
    if #arguments > 2 then
        raise("too many arguments\n" .. USAGE)
    end
    local census = arguments[1]
    local output = arguments[2] or BOOTED
    local header = io.readfile(BOOTED)
    local head = header:sub(1, header:find("inline constexpr", 1, true) - 1)
    local seen = {}
    local names = {}
    for name in io.readfile(census):gmatch("[^\n]+") do
        if not name:match(MEMBER) then
            raise("census line is not a snapshot member name: " .. name)
        end
        if not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    if #names == 0 then
        raise("census " .. census .. " names no members")
    end
    table.sort(names)
    local body = {}
    for _, name in ipairs(names) do
        body[#body + 1] = '    "' .. name .. '",'
    end
    local text = head .. "inline constexpr std::array<std::string_view, " .. #names ..
        "> booted_populated_members {\n" .. table.concat(body, "\n") .. "\n};\n\n}\n"
    io.writefile(output, text)
    print("wrote " .. #names .. " booted members to " .. output)
end
