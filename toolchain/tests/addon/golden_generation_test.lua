import("fixtures")
import("core.base.process")

-- The golden image of the emulator is a published generation, as a package is in the store: an install that replaces it
-- keeps the old one for its readers, and a copy of the golden image is whole however often it is replaced meanwhile.

local PARTS = 40
local WORD = "fixed"

-- the racers are separate processes, since a lock taken twice in one process does not exclude itself across the
-- handles this test opens; each one reads the golden image the way an install or a clone does
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

-- what is left in the golden images folder, with whether each generation is replaced and whether its lock is free
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

    -- one install builds the golden image, publishes it as a link to a generation, and copies it whole
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

    -- a reader that holds the generation keeps it through a replacement, and the replacement is built beside it
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

        -- a replaced generation that nothing holds stays for its grace period, then goes
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

    -- two installs and a reader race a sweep that replaces the golden image; no copy is incomplete, and nothing is left
    local racer = path.join(folder, "racer.lua")
    io.writefile(racer, RACER)
    local modules = opt.modules
    -- the racers run xmake with a store of their own, as the store race test does: the test's own xmake holds the
    -- shared store's locks, and a racer that used it would wait for them
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
    -- a racer's last line is its report; under the test's xmake it does not exit after that, so the report ends it
    local function reported(log)
        local said = os.isfile(log) and io.readfile(log) or ""
        return said:match("reads %d+ violations %d+") ~= nil
    end
    for _, state in ipairs(children) do
        local waited = 0
        while not reported(state.log) and waited < 120000 do
            os.sleep(200)
            waited = waited + 200
        end
        try {function () state.child:kill() end}
        state.child:close()
        local said = os.isfile(state.log) and io.readfile(state.log) or ""
        if not reported(state.log) then
            table.insert(found, state.name .. " racer did not report within 120 seconds, and printed: " .. said)
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

    os.tryrm(folder)
    return found
end
