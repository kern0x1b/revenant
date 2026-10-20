local json = import("core.base.json")
local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "..", "modules"), anonymous = true})

function main(folder, header)
    local files = os.files(path.join(folder, "*.json"))
    byteorder.sort(files)
    local rows = {}
    for _, file in ipairs(files) do
        local document = json.decode(io.readfile(file))
        for _, entry in ipairs(document.entries or {}) do
            if entry.kind == "protocol" and entry.status == "implemented" then
                table.insert(rows, entry.api)
            end
        end
    end
    local quoted = {}
    for _, name in ipairs(rows) do
        table.insert(quoted, '@"' .. name .. '"')
    end
    local text = "// Written by protocol-check.sh from registry/Accessibility's protocol rows, so that this check\n"
        .. "// asks about what the registry claims. One macro per implemented protocol row.\n"
        .. "#import <Foundation/Foundation.h>\n\n"
        .. "#define REVENANT_PROTOCOLS @[" .. table.concat(quoted, ", ") .. "]\n"
        .. "#define REVENANT_PROTOCOL_COUNT " .. #rows .. "\n"
    io.writefile(header, text, {encoding = "binary"})
    print("registry protocol rows read: " .. #rows)
    for index, name in ipairs(rows) do
        print(string.format("  [%d] %s", index, name))
    end
end
