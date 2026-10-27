import("fixtures")
import("core.base.process")

local OLD = "202001010000"

local function folder_with(home, name, old)
    local folder = path.join(home, "scratch", name)
    os.mkdir(folder)
    io.writefile(path.join(folder, "data"), name .. "\n")
    if old then
        os.vrunv("touch", {"-t", OLD, path.join(folder, "data")})
        os.vrunv("touch", {"-t", OLD, folder})
    end
    return folder
end

function failures(arguments)
    local found = {}
    local retention = import("retention", {rootdir = arguments.modules, anonymous = true})
    local home = fixtures.scratch()
    local xmake = path.join(home, "xmake")
    local xmake_global = path.join(home, "xmake-global")
    os.mkdir(xmake)
    os.mkdir(xmake_global)
    local live = folder_with(home, "live-task", true)
    local recent = folder_with(home, "recent-task", false)
    local held = folder_with(home, "held-task", true)
    local orphan = folder_with(home, "old-orphan", true)
    local log = path.join(home, "holder.log")
    local holder = process.openv("tail", {"-f", path.join(held, "data")}, {stdout = log, stderr = log})
    os.sleep(500)
    local live_names = {["live-task"] = true}

    local dry = retention.sweep(home, {live = live_names, days = 7, dry = true})
    if not dry.error then
        local selected = false
        for _, folder in ipairs(dry.removed) do
            if folder == orphan then
                selected = true
            end
        end
        if not selected then
            table.insert(found, "a dry run did not select the old orphan")
        end
    end
    if not os.isdir(orphan) then
        table.insert(found, "a dry run removed a folder")
    end

    local report = retention.sweep(home, {live = live_names, days = 7})
    holder:kill()
    holder:close()
    if report.error then
        table.insert(found, "the sweep stopped: " .. report.error)
    end
    if os.isdir(orphan) then
        table.insert(found, "the old orphan, which no worktree names and nothing touched, was kept")
    end
    if not os.isdir(live) then
        table.insert(found, "the scratch of a live worktree was removed")
    end
    if not os.isdir(recent) then
        table.insert(found, "a folder modified in the last seven days was removed")
    end
    if not os.isdir(held) then
        table.insert(found, "a folder a process has files open in was removed")
    end
    if not os.isdir(xmake) or not os.isdir(xmake_global) then
        table.insert(found, "the package store or xmake itself was touched")
    end
    if not os.isfile(path.join(home, ".scratch-swept")) then
        table.insert(found, "the sweep did not record that it ran")
    end
    if type(report.freed_kib) ~= "number" then
        table.insert(found, "the sweep did not report the disk it freed")
    end

    os.tryrm(home)
    return found
end
