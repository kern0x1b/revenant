-- Whether a device scenario passed, from the lines the demo logged. A picture alone never passes: the phone may show
-- the home screen when the demo has already quit.

-- What a gesture scenario's log line must show: its swipe reached the action of the row it swiped.
local EXPECTED = {["swipe-real"] = "archive"}

function gesture_outcome(scenario, done, logged)
    if not done then
        return false, "the demo did not log gesture: done"
    end
    local expected = EXPECTED[scenario]
    if expected and not (logged and logged:find(expected, 1, true)) then
        return false, "the demo's gesture log does not show " .. expected .. ": " .. (logged or "no gesture: log line")
    end
    return true
end

function live_outcome(ready)
    if not ready then
        return false, "the demo did not log live: ready"
    end
    return true
end
