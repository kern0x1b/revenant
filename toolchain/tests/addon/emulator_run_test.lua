import("fixtures")

function failures(opt)
    local emulator = import("emulator", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local folder = fixtures.scratch()
    local run = path.join(folder, "run")
    local locked = path.join(run, "rootfs", "System", "Library", "Caches")
    emulator.directory(locked)
    local shared = path.join(locked, "dyld_shared_cache_armv7")
    io.writefile(shared, "shared cache")
    os.vrunv("chmod", {"0444", shared})
    os.vrunv("chmod", {"0555", locked})
    emulator.directory(path.join(run, "tmp"))
    local refusal = fixtures.refusal(function () emulator.remove(run) end)
    if refusal or os.exists(run) then
        table.insert(found, "a run folder whose clone holds a read-only file is removed when the run ends: " .. tostring(refusal))
    end
    os.tryrm(folder)
    return found
end
