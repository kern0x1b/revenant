function run(phase, action, minimum)
    local started = os.mclock()
    local result = action()
    local seconds = (os.mclock() - started) / 1000
    if seconds >= (minimum or 0) then
        print(string.format("timing: %s: %.1f s", phase, seconds))
    end
    return result
end
