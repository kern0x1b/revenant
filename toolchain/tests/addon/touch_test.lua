function failures(opt)
    local touch = import("touch", {rootdir = path.join(path.directory(opt.modules), "..", "frameworks", "ReactNative", "tools"), anonymous = true})
    local found = {}
    local function expect(words, wanted)
        local ok, result = true, nil
        try {
            function ()
                result = touch.command(words)
            end,
            catch {
                function ()
                    ok = false
                end
            }
        }
        if wanted == nil then
            if ok then
                table.insert(found, "touch accepted " .. table.concat(words, " "))
            end
        elseif not ok or result ~= wanted then
            table.insert(found, "touch built " .. tostring(result) .. " for " .. table.concat(words, " ") .. ", wanted " .. wanted)
        end
    end
    expect({"tap", "160", "240"}, "tap 160 240")
    expect({"swipe", "10", "20", "30", "40"}, "swipe 10 20 30 40")
    expect({"swipe", "10", "20", "30", "40", "300"}, "swipe 10 20 30 40 300")
    expect({"scroll", "0", "0", "-120"}, "scroll 0 0 -120")
    expect({"key", "delete"}, "key delete")
    expect({"text", "hello", "world"}, "text hello world")
    expect({"taptext", "Direct connection"}, "taptext Direct connection")
    expect({"methods", "UIView"}, "methods UIView")
    expect({"tap", "160"}, nil)
    expect({"tap", "a", "b"}, nil)
    expect({"key", "enter"}, nil)
    expect({"text"}, nil)
    expect({"text", "it's"}, nil)
    expect({"fling", "1"}, nil)
    local line = touch.script("tap 1 2")
    if not line:find("echo 'tap 1 2' > /var/tmp/rnhost.cmd", 1, true) then
        table.insert(found, "the device script must write the command into /var/tmp/rnhost.cmd")
    end
    return found
end
