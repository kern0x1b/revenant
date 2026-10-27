local OPENS_WITH_ARCHIVE = {["swipe-real"] = "archive"}

function gesture_outcome(scenario, done, logged)
    if not done then
        return false, "the demo did not log gesture: done"
    end
    local expected = OPENS_WITH_ARCHIVE[scenario]
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
