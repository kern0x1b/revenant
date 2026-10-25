function failures(opt)
    local emulator = import("emulator", {rootdir = opt.modules, anonymous = true})
    local found = {}
    if #emulator.core_arguments({}) ~= 0 then
        table.insert(found, "a boot without a cores option must pass no --cores, so the emulator keeps its own default")
    end
    local argv = emulator.core_arguments({cores = 1})
    if #argv ~= 2 or argv[1] ~= "--cores" or argv[2] ~= "1" then
        table.insert(found, "a boot with cores = 1 must pass --cores 1 to the emulator")
    end
    local now = 10000000
    if emulator.boot_expired(now, now - 899000, now - 899000, 900) ~= nil then
        table.insert(found, "a boot that wrote output 899 seconds ago under a 900-second limit must not be stopped")
    end
    if emulator.boot_expired(now, now - 901000, now - 901000, 900) ~= "stalled" then
        table.insert(found, "a boot that wrote nothing for 901 seconds under a 900-second limit must be stopped as stalled")
    end
    if emulator.boot_expired(now, now - 901000, now - 901000, 900, 4) ~= nil then
        table.insert(found, "a boot that wrote nothing for 901 seconds on a host four times busier than its cores must not be stopped")
    end
    if emulator.boot_expired(now, now - 5000000, now - 1000, 900) ~= nil then
        table.insert(found, "a boot that is still writing output must not be stopped before ten times its limit")
    end
    if emulator.boot_expired(now, now - 9001000, now - 1000, 900) ~= "deadline" then
        table.insert(found, "a boot that runs past ten times its limit must be stopped")
    end
    return found
end
