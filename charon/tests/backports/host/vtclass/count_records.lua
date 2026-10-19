-- count_records.lua RECORDS.json - prints how many records a records file holds, which is run.sh's
-- "the host answered: N" line, ported from its inline python3 -c len(json.load(...)). A file that is not
-- there, or is not JSON, ends the run with exit 1, as the Python's uncaught exception did.

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
