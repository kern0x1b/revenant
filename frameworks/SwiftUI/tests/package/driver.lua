import("core.base.json")

local BUNDLE = "space.kern0x1b.swiftui.demo"
local APPLICATION = "/Applications/SwiftUIDemo.app"
local PACKAGES = {"org.revenant.backports_", "space.kern0x1b.swiftui_"}
local BLANK = 4096
local DRAWN = 100000

function failures(text, folder)
    local found = {}
    for _, prefix in ipairs(PACKAGES) do
        if not text:find("installed " .. prefix, 1, true) then
            table.insert(found, "the emulator image installed no " .. prefix .. "*.deb")
        end
    end
    if not folder or not os.isdir(folder) then
        table.insert(found, "xmake emulate printed no run folder")
        return found
    end
    local verdict = json.loadfile(path.join(folder, "verdict.json")) or {}
    if verdict.failure then
        table.insert(found, "SpringBoard did not run " .. BUNDLE .. ": " .. tostring(verdict.failure))
    end
    if not verdict.pid then
        table.insert(found, BUNDLE .. " never started a process")
    end
    if verdict.application ~= APPLICATION then
        table.insert(found, "the run launched " .. tostring(verdict.application) .. ", not " .. APPLICATION)
    end
    if verdict.reason ~= "reached" then
        table.insert(found, BUNDLE .. " ran, and the run ended (" .. tostring(verdict.reason) .. ") before its steps were taken")
    end
    local shots = verdict.shots or {}
    if #shots < 1 then
        table.insert(found, BUNDLE .. " was never snapshotted")
    end
    if not verdict.visible_pixels or verdict.visible_pixels < DRAWN then
        table.insert(found, BUNDLE .. " drew nothing on its settled frame: " .. tostring(verdict.visible_pixels) ..
                            " visible pixels, and the status bar alone is about 3300")
    end
    for _, shot in ipairs(shots) do
        if not os.isfile(shot) or os.filesize(shot) < BLANK then
            table.insert(found, "the snapshot " .. shot .. " is missing or blank, so the app drew nothing")
        end
    end
    for _, report in ipairs(os.files(path.join(folder, "results", "reports", "*"))) do
        if path.filename(report):startswith("SwiftUIDemo") then
            table.insert(found, BUNDLE .. " crashed: " .. path.filename(report))
        end
    end
    return found
end
