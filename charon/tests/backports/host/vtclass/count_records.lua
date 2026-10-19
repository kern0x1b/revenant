local V = import("vtlib", {rootdir = os.scriptdir()})
local R = import("records_json", {rootdir = os.scriptdir()})

function main(path)
    if not os.isfile(path) then
        V.fail("count_records.lua: " .. path .. " is not there")
    end
    local map
    try {
        function()
            map = R.read_object(path)
        end,
        catch {
            function(err)
                V.fail("count_records.lua: " .. path .. " is not JSON: " .. tostring(err))
            end
        }
    }
    print(V.count_entries(map))
end
