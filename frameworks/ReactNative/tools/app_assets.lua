import("core.base.json")

local USAGE = [[usage: ./xmakew l -P . frameworks/ReactNative/tools/app_assets.lua [--output DIR] APP_DIR
  makes what an iOS 6 application bundle needs from the Expo configuration of the application, so that the host carries nothing of its own:
  DIR/Icon.png (57 pixels), DIR/Icon@2x.png (114) from `icon`, DIR/Default.png (320 by 480), DIR/Default@2x.png (640 by 960) from the
  splash image and background colour of the expo-splash-screen plugin, and DIR/Info.fragment.plist with CFBundleDisplayName and
  CFBundleIconFiles for the application's own Info.plist. The default DIR is APP_DIR/dist-assets.
  APP_DIR is the folder with app.config.js or app.json; the configuration is read with `npx expo config`.]]

local ICON_SIZES = {{"Icon.png", 57}, {"Icon@2x.png", 114}}
local LAUNCH_SIZES = {{"Default.png", 320, 480, 1}, {"Default@2x.png", 640, 960, 2}}

function plan(config)
    local result = {name = config.name, icon = config.icon, background = "FFFFFF"}
    for _, plugin in ipairs(config.plugins or {}) do
        if type(plugin) == "table" and plugin[1] == "expo-splash-screen" and type(plugin[2]) == "table" then
            local options = plugin[2]
            result.splash = options.image
            result.splash_width = options.imageWidth or 200
            result.background = (options.backgroundColor or "#ffffff"):gsub("^#", ""):upper()
        end
    end
    if not result.name or not result.icon then
        raise("the Expo configuration has no name or no icon")
    end
    return result
end

function fragment(name)
    return table.concat({
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">',
        '<plist version="1.0"><dict>',
        '<key>CFBundleDisplayName</key><string>' .. name .. '</string>',
        '<key>CFBundleIconFiles</key><array><string>Icon.png</string><string>Icon@2x.png</string></array>',
        '<key>UIPrerenderedIcon</key><true/>',
        '</dict></plist>', ''}, "\n")
end

local function sips(...)
    os.vrunv("sips", {...})
end

function main(...)
    local shared = import("@addon.revenant.member", {anonymous = true})
    local given, words = shared.arguments({...}, {output = "value", help = "switch"})
    if given.help or #words ~= 1 then
        print(USAGE)
        return
    end
    local app = path.absolute(words[1])
    local output = path.absolute(given.output or path.join(app, "dist-assets"))
    local text = os.iorunv("npx", {"expo", "config", "--json", "--type", "public"}, {curdir = app, envs = {CI = "1", EXPO_NO_TELEMETRY = "1"}})
    local config = json.decode(text:match("%b{}"))
    local made = plan(config)
    local icon = path.join(app, made.icon)
    if not os.isfile(icon) then
        raise("the icon %s is not a file", icon)
    end
    os.mkdir(output)
    for _, size in ipairs(ICON_SIZES) do
        sips("-z", tostring(size[2]), tostring(size[2]), icon, "--out", path.join(output, size[1]))
    end
    for _, launch in ipairs(LAUNCH_SIZES) do
        local file = path.join(output, launch[1])
        if made.splash and os.isfile(path.join(app, made.splash)) then
            sips("-Z", tostring(made.splash_width * launch[4]), path.join(app, made.splash), "--out", file)
            sips("--padToHeightWidth", tostring(launch[3]), tostring(launch[2]), "--padColor", made.background, file)
        else
            sips("-z", "1", "1", icon, "--out", file)
            sips("--padToHeightWidth", tostring(launch[3]), tostring(launch[2]), "--padColor", made.background, file)
        end
    end
    io.writefile(path.join(output, "Info.fragment.plist"), fragment(made.name))
    print("wrote " .. output)
end
