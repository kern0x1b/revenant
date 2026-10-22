local function raised_by(run)
    local message
    try {
        run,
        catch {
            function (raised)
                message = tostring(raised)
            end
        }
    }
    return message
end

local function target(plat, kind)
    local data = {}
    return {
        is_plat = function (_, value) return value == plat end,
        kind = function () return kind end,
        data = function (_, key) return data[key] end,
        data_set = function (_, key, value) data[key] = value end,
    }
end

function failures(opt)
    local found = {}
    local binding = import("binding", {rootdir = opt.modules, anonymous = true})

    local stray = target("iphoneos", "static")
    local message = raised_by(function () binding.check({stray = stray}) end)
    if not message or not message:find("stray", 1, true) then
        table.insert(found, "an iphoneos target without the apple-ios rule must make check raise, and name it")
    end

    local ready = target("iphoneos", "static")
    binding.mark(ready)
    if raised_by(function () binding.check({ready = ready}) end) then
        table.insert(found, "an iphoneos target marked by the apple-ios rule must pass check")
    end

    if raised_by(function () binding.check({host = target("macosx", "static")}) end) then
        table.insert(found, "a target for another platform must pass check without the apple-ios rule")
    end

    if raised_by(function () binding.check({group = target("iphoneos", "phony")}) end) then
        table.insert(found, "a phony iphoneos target must pass check without the apple-ios rule")
    end

    message = raised_by(function () binding.check({ready = ready, stray = stray}) end)
    if not message or not message:find("stray", 1, true) or message:find("ready", 1, true) then
        table.insert(found, "check must name only the unbound iphoneos target among bound ones")
    end

    return found
end
