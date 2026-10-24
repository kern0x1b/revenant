import("core.base.scheduler")

local driver = import("driver", {rootdir = os.scriptdir(), anonymous = true})

function main()
    local calls = 0
    local results = {}
    local function body()
        calls = calls + 1
        os.sleep(50)
        return "value", true, ""
    end
    scheduler.co_group_begin("runtime-once", function ()
        for index = 1, 2 do
            scheduler.co_start(function ()
                local value, finished = driver.once("same-key", body)
                results[index] = {value, finished}
            end)
        end
    end)
    scheduler.co_group_wait("runtime-once")
    assert(calls == 1, "two cases with one key ran the body " .. calls .. " times")
    for index = 1, 2 do
        assert(results[index] and results[index][1] == "value" and results[index][2] == true,
               "case " .. index .. " did not get the first run's result")
    end
end
