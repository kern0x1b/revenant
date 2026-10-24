import("fixtures")
import("core.base.json")
import("core.base.process")

local PARTS = 40
local WORD = "fixed"

local RACER = [[
local PARTS = 40
local WORD = "fixed"

local function whole(dir)
    for index = 1, PARTS do
        local file = path.join(dir, "payload", string.format("part-%02d", index))
        local text = nil
        try {function () text = io.readfile(file) end, catch {function () text = nil end}}
        if text ~= WORD .. " " .. string.rep("x", 200) .. "\n" then
            return false, file
        end
    end
    return true
end

local function boot(opt)
    return {reason = "reached", seconds = 1, state = {springboard = true, migrated = true}, log = "none"}
end

function main(mode, modules, root, firmware, folder, count)
    local emulator = import("emulator", {rootdir = modules, anonymous = true})
    local generations = import("generations", {rootdir = modules, anonymous = true})
    local opt = {root = root, identifier = "fake", build = "1A1", emulator_hash = "fixture", deadline = 30,
                 firmware = firmware, boot = boot}
    local reads, violations, details = 0, 0, {}
    for index = 1, tonumber(count) do
        reads = reads + 1
        local problem = nil
        if mode == "install" then
            local destination = path.join(folder, tostring(index), "rootfs")
            local ok, errors = try {function () emulator.clone_golden(opt, destination) return true end,
                                    catch {function (caught) return false, caught end}}
            if not ok then
                problem = "the install raised: " .. tostring(errors)
            else
                local whole_copy, file = whole(destination)
                if not whole_copy then
                    problem = "the install's copy is incomplete at " .. file
                end
            end
        else
            local generation = emulator.golden(opt)
            local lock = generations.hold(generation)
            os.sleep(200)
            local still = os.isfile(path.join(generation, "golden.json"))
            local whole_golden, file = whole(path.join(generation, "rootfs"))
            generations.release(lock)
            if not still or not whole_golden then
                problem = "the reader's held generation is incomplete at " .. tostring(file or generation)
            end
        end
        if problem then
            violations = violations + 1
            if #details < 4 then
                table.insert(details, problem)
            end
        end
    end
    print("reads " .. reads .. " violations " .. violations)
    for _, line in ipairs(details) do
        print("DETAIL " .. line)
    end
end
]]

local BLOCKED = [[
function main(modules, lockpath, mark, shared)
    local generations = import("generations", {rootdir = modules, anonymous = true})
    io.writefile(mark .. ".waiting", "")
    local lock = generations.take(lockpath, shared == "1")
    io.writefile(mark .. ".acquired", tostring(os.mclock()))
    os.sleep(500)
    generations.release(lock)
end
]]

local function write_firmware(firmware)
    os.mkdir(path.join(firmware, "payload"))
    for index = 1, PARTS do
        io.writefile(path.join(firmware, "payload", string.format("part-%02d", index)), WORD .. " " .. string.rep("x", 200) .. "\n")
    end
end

local function whole(dir)
    for index = 1, PARTS do
        local text = nil
        try {function () text = io.readfile(path.join(dir, "payload", string.format("part-%02d", index))) end,
             catch {function () text = nil end}}
        if text ~= WORD .. " " .. string.rep("x", 200) .. "\n" then
            return false
        end
    end
    return true
end

local function generation_count(root)
    return #os.dirs(path.join(root, "golden.noindex", "*.g*"))
end

local function leftovers(parent)
    local said = {}
    for _, item in ipairs(table.join(os.dirs(path.join(parent, "*")), os.files(path.join(parent, "*")))) do
        local detail = os.islink(item) and "a link" or (os.isdir(item) and "a folder" or "a file")
        if os.isdir(item) then
            local marker = path.join(item, ".replaced")
            detail = detail .. (os.isfile(marker) and (", replaced at " .. io.readfile(marker)) or ", not replaced")
            local lock = io.openlock(item .. ".lock")
            if lock and lock:trylock() then
                detail = detail .. ", unlocked"
                lock:unlock()
            else
                detail = detail .. ", locked"
            end
            if lock then
                lock:close()
            end
        end
        table.insert(said, path.filename(item) .. " is " .. detail)
    end
    return said
end

local function blocked_session(found, generations, modules, folder, envs, label, lockpath, shared)
    local script = path.join(folder, label .. ".lua")
    io.writefile(script, BLOCKED)
    local mark = path.join(folder, label)
    local holder = generations.take(lockpath)
    local waiter = process.openv(os.programfile(), {"l", script, modules, lockpath, mark, shared and "1" or "0"},
                                 {curdir = folder, envs = envs, stdout = mark .. ".log", stderr = mark .. ".log"})
    local waited = 0
    while not os.isfile(mark .. ".waiting") and waited < 60000 do
        os.sleep(100)
        waited = waited + 100
    end
    os.sleep(1000)
    os.tryrm(lockpath)
    local successor = generations.take(lockpath)
    generations.release(holder)
    os.sleep(1500)
    if os.isfile(mark .. ".acquired") then
        table.insert(found, label .. ": the session waiting on it took the lock while the session that replaced its file held it")
    end
    local released = os.mclock()
    generations.release(successor)
    local exited, status = waiter:wait(20000)
    if exited ~= 1 then
        try {function () waiter:kill() end}
    end
    waiter:close()
    local acquired = os.isfile(mark .. ".acquired") and tonumber(io.readfile(mark .. ".acquired")) or nil
    if not acquired then
        table.insert(found, label .. ": the session waiting on it never took the lock, and printed " .. (os.isfile(mark .. ".log") and io.readfile(mark .. ".log") or ""))
    elseif acquired < released then
        table.insert(found, label .. ": the session waiting on it took the lock before the session that replaced its file released it")
    end
    if exited ~= 1 or status ~= 0 then
        table.insert(found, label .. ": the session waiting on it did not exit cleanly: exited " .. tostring(exited) .. ", status " .. tostring(status))
    end
end

function failures(opt)
    local found = {}
    local folder = fixtures.scratch()
    local emulator = import("emulator", {rootdir = opt.modules, anonymous = true})
    local generations = import("generations", {rootdir = opt.modules, anonymous = true})
    local root = path.join(folder, "emulator")
    os.mkdir(root)
    local firmware = path.join(folder, "firmware")
    write_firmware(firmware)
    local golden = {root = root, identifier = "fake", build = "1A1", emulator_hash = "fixture", deadline = 30,
                    firmware = firmware, boot = function () return {reason = "reached", seconds = 1, state = {springboard = true, migrated = true}, log = "none"} end}
    local published = emulator.golden_published(golden)

    emulator.clone_golden(golden, path.join(folder, "first", "rootfs"))
    if not whole(path.join(folder, "first", "rootfs")) then
        table.insert(found, "the first install's copy is not whole")
    end
    if not os.islink(published) then
        table.insert(found, "the published golden image is not a link to its generation")
    end
    local first = generations.resolve(published)
    if not first or not os.isfile(path.join(first, "golden.json")) then
        table.insert(found, "the published generation has no golden.json")
    end

    if first then
        local held = generations.hold(first)
        emulator.clean({root = root, goldens = true})
        emulator.clone_golden(golden, path.join(folder, "second", "rootfs"))
        if not os.isdir(first) or not whole(path.join(first, "rootfs")) then
            table.insert(found, "a generation a reader holds was removed or cut short while its replacement was built")
        end
        local second = generations.resolve(published)
        if not second or second == first or not whole(path.join(second, "rootfs")) then
            table.insert(found, "the replacement is not published whole beside the generation it replaces")
        end
        if not whole(path.join(folder, "second", "rootfs")) then
            table.insert(found, "the install that replaced the golden image copied an incomplete one")
        end
        generations.release(held)

        emulator.clean({root = root})
        if not os.isdir(first) then
            table.insert(found, "a generation that was replaced a moment ago is gone before its grace period has ended")
        end
        os.setenv("REVENANT_GENERATION_GRACE", "0")
        emulator.clean({root = root})
        os.setenv("REVENANT_GENERATION_GRACE", "3600")
        if os.isdir(first) then
            table.insert(found, "a replaced generation nothing holds is still there after its grace period of zero")
        end
        local current = generations.resolve(published)
        if not os.islink(published) or not current or not whole(path.join(current, "rootfs")) then
            table.insert(found, "the current generation is not the published one after the replaced one was swept")
        end
    end

    local racer = path.join(folder, "racer.lua")
    io.writefile(racer, RACER)
    local modules = opt.modules
    local store = path.join(folder, "store")
    os.mkdir(store)
    local envs = {XMAKE_GLOBALDIR = store, XMAKE_MAIN_REPO = fixtures.empty_repository(folder)}
    local children = {}
    for _, racing in ipairs({{"install", "a"}, {"install", "b"}, {"cloner", "c"}}) do
        local log = path.join(folder, racing[2] .. ".log")
        local child = process.openv(os.programfile(), {"l", racer, racing[1], modules, root, firmware, path.join(folder, racing[2]), "6"},
                                    {curdir = folder, envs = envs, stdout = log, stderr = log})
        table.insert(children, {child = child, log = log, name = racing[1]})
    end
    for _ = 1, 12 do
        os.sleep(300)
        emulator.clean({root = root, goldens = true})
    end
    for _, state in ipairs(children) do
        local exited, status = state.child:wait(120000)
        if exited ~= 1 then
            try {function () state.child:kill() end}
        end
        state.child:close()
        local said = os.isfile(state.log) and io.readfile(state.log) or ""
        if exited ~= 1 then
            table.insert(found, state.name .. " racer did not exit within 120 seconds, and printed: " .. said)
        elseif status ~= 0 then
            table.insert(found, state.name .. " racer exited with status " .. tostring(status) .. ", and printed: " .. said)
        end
        local reads, violations = said:match("reads (%d+) violations (%d+)")
        if not reads then
            table.insert(found, state.name .. " racer did not report its reads: " .. said)
        elseif tonumber(violations) > 0 then
            table.insert(found, state.name .. " racer read an incomplete golden image in " .. violations .. " of " .. reads .. " reads: " .. said)
        end
    end
    emulator.clean({root = root, goldens = true})
    if generation_count(root) ~= 0 then
        table.insert(found, "after the race and a final clean, " .. generation_count(root) .. " golden generations are left: "
                     .. table.concat(leftovers(path.join(root, "golden.noindex")), "; "))
    end
    if os.isfile(published .. ".build.lock") then
        table.insert(found, "after the race and a final clean, the build lock of the golden image is still there")
    end

    local legacy_opt = table.join(golden, {emulator_hash = "legacy"})
    local legacy = emulator.golden_published(legacy_opt)
    os.mkdir(path.join(legacy, "rootfs"))
    os.execv("cp", {"-R", path.join(firmware, "payload"), path.join(legacy, "rootfs", "payload")})
    json.savefile(path.join(legacy, "golden.json"), {identifier = "fake", build = "1A1", emulator = "legacy", seconds = 1})
    emulator.clone_golden(legacy_opt, path.join(folder, "legacy", "rootfs"))
    if os.islink(legacy) or not os.isdir(legacy) then
        table.insert(found, "a golden folder from before generations was replaced by a link while it was only read")
    end
    if not whole(path.join(folder, "legacy", "rootfs")) then
        table.insert(found, "a copy of a golden folder from before generations is not whole")
    end
    local held_legacy = generations.hold(legacy)
    emulator.clean({root = root, goldens = true})
    local moved = os.dirs(legacy .. ".g*")
    if #moved ~= 1 or not whole(path.join(moved[1], "rootfs")) then
        table.insert(found, "a golden folder from before generations that a reader holds was not kept whole when a clean replaced it")
    end
    generations.release(held_legacy)

    emulator.clean({root = root})
    if #os.dirs(legacy .. ".g*") ~= 1 then
        table.insert(found, "a golden folder replaced a moment ago is gone before its grace period has ended")
    end
    os.setenv("REVENANT_GENERATION_GRACE", "0")
    emulator.clean({root = root})
    os.setenv("REVENANT_GENERATION_GRACE", "3600")
    if #os.dirs(legacy .. ".g*") ~= 0 then
        table.insert(found, "a replaced golden folder that nothing holds is still there after its grace period of zero")
    end

    emulator.clone_golden(legacy_opt, path.join(folder, "rebuilt", "rootfs"))
    if not os.islink(legacy) or not whole(path.join(folder, "rebuilt", "rootfs")) then
        table.insert(found, "an install after a golden folder from before generations did not publish a whole link")
    end
    emulator.clean({root = root, goldens = true})
    if os.islink(legacy) or os.isfile(legacy .. ".build.lock") or generation_count(root) ~= 0 then
        table.insert(found, "after a golden folder from before generations is replaced and cleaned, something is left: "
                     .. table.concat(leftovers(path.join(root, "golden.noindex")), "; "))
    end

    blocked_session(found, generations, modules, folder, envs, "build-lock", path.join(folder, "blocked.build.lock"), false)
    local generation_published = path.join(folder, "blocked-generation")
    local generation_lock = generation_published .. ".g1.lock"
    blocked_session(found, generations, modules, folder, envs, "generation-lock", generation_lock, true)

    generations.sweep(generation_published)
    if os.isfile(generation_lock) then
        table.insert(found, "a sweep leaves the lock file of a generation that has no folder")
    end

    os.tryrm(folder)
    return found
end
