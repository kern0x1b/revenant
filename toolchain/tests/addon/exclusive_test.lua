import("fixtures")

function failures(opt)
    local exclusive = import("exclusive", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local folder = fixtures.scratch()
    local file = path.join(folder, "one.lock")

    if exclusive.held(file) then
        table.insert(found, "a free lock is reported as held")
    end

    local taken, seen = exclusive.attempt(file, function ()
        return exclusive.held(file)
    end)
    if not taken or seen ~= true then
        table.insert(found, "a lock held by attempt is not reported as held")
    end
    if exclusive.held(file) then
        table.insert(found, "a lock released by attempt is still reported as held")
    end

    os.tryrm(folder)
    return found
end
