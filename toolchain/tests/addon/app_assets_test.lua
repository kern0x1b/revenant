function failures(opt)
    local tools = path.join(path.directory(opt.modules), "..", "frameworks", "ReactNative", "tools")
    local assets = import("app_assets", {rootdir = tools, anonymous = true})
    local found = {}
    local made = assets.plan({name = "Demo", icon = "./icon.png", plugins = {{"expo-router", {}}, {"expo-splash-screen", {image = "./s.png", imageWidth = 120, backgroundColor = "#a1b2c3"}}}})
    if made.name ~= "Demo" or made.icon ~= "./icon.png" then
        table.insert(found, "the plan must carry the name and the icon of the configuration")
    end
    if made.splash ~= "./s.png" or made.splash_width ~= 120 or made.background ~= "A1B2C3" then
        table.insert(found, "the plan must take the image, width and background of the expo-splash-screen plugin")
    end
    local plain = assets.plan({name = "Demo", icon = "./icon.png"})
    if plain.splash ~= nil or plain.background ~= "FFFFFF" then
        table.insert(found, "without a splash plugin the launch image is white with no picture")
    end
    local refused
    try { function () assets.plan({name = "Demo"}) end, catch { function () refused = true end } }
    if not refused then
        table.insert(found, "a configuration without an icon must be refused")
    end
    local plist = assets.fragment("Demo")
    for _, wanted in ipairs({"<key>CFBundleDisplayName</key><string>Demo</string>", "<string>Icon@2x.png</string>", "UIPrerenderedIcon"}) do
        if not plist:find(wanted, 1, true) then
            table.insert(found, "the Info.plist fragment lacks " .. wanted)
        end
    end
    return found
end
