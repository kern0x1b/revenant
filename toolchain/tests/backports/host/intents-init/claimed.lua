local json = import("core.base.json")
local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "..", "modules"), anonymous = true})

function main(folder)
    local files = os.files(path.join(folder, "ios*.json"))
    byteorder.sort(files)
    local names, count = {}, 0
    for _, file in ipairs(files) do
        local document = json.decode(io.readfile(file))
        for _, entry in ipairs(document.entries or document) do
            if entry.status == "implemented" then
                local name = entry.api:match("^%-%[([%w_]+) init%]$")
                if name and not names[name] then
                    names[name] = true
                    count = count + 1
                end
            end
        end
    end
    print(count)
end
