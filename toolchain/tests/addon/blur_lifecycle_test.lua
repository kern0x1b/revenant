function failures(opt)
    local root = path.absolute(path.join(opt.modules, "..", ".."))
    local patch = io.readfile(path.join(root, "packages", "e", "expo-blur", "patches", "blur-ios6.patch"))
    local found = {}
    for line in patch:gmatch("[^\n]+") do
        table.insert(found, line)
    end
    local problems = {}
    local observers = 0
    local stopped = false
    local started = false
    local in_background = false
    local in_active = false
    for index, line in ipairs(found) do
        if line:find("addObserver", 1, true) and line:find("applicationDidEnterBackground", 1, true) then
            observers = observers + 1
            if not line:find("UIApplication.didEnterBackgroundNotification", 1, true) then
                table.insert(problems, string.format("line %d observes the background transition without UIApplication.didEnterBackgroundNotification", index))
            end
        end
        if line:find("addObserver", 1, true) and line:find("applicationDidBecomeActive", 1, true) then
            observers = observers + 1
            if not line:find("UIApplication.didBecomeActiveNotification", 1, true) then
                table.insert(problems, string.format("line %d observes the active transition without UIApplication.didBecomeActiveNotification", index))
            end
        end
        if line:find('Notification.Name("UIApplication', 1, true) then
            table.insert(problems, string.format("line %d uses a string literal instead of the real notification name", index))
        end
        if line:find("func applicationDidEnterBackground", 1, true) then
            in_background = true
            in_active = false
        end
        if line:find("func applicationDidBecomeActive", 1, true) then
            in_active = true
            in_background = false
        end
        if in_background and line:find("stopTimer", 1, true) then
            stopped = true
        end
        if in_active and line:find("startTimer", 1, true) then
            started = true
        end
    end
    if observers ~= 2 then
        table.insert(problems, string.format("found %d lifecycle observers, expected 2", observers))
    end
    if not stopped then
        table.insert(problems, "the background handler does not stop the display link")
    end
    if not started then
        table.insert(problems, "the active handler does not start the display link")
    end
    return problems
end
