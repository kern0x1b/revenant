local USAGE = [[usage: ./xmakew l -P . frameworks/ReactNative/tools/app_config.lua --output DIR APP_DIR
  writes DIR/EXConstants.bundle/app.config, the manifest expo-constants reads on iOS, from the application's own Expo configuration.
  APP_DIR is the folder with app.json or app.config.js. The file is what `npx expo config --type public --json` prints, which is
  what the Expo build phase of an Xcode project embeds. Put the EXConstants.bundle folder into the application bundle next to the
  executable's resources. Without it Constants.expoConfig is null, and expo-linking, expo-router and the scheme of the
  application fail at the first screen.]]

function public_json(app)
    local text = os.iorunv("npx", {"expo", "config", "--type", "public", "--json"}, {curdir = app, envs = {CI = "1", EXPO_NO_TELEMETRY = "1"}})
    local json = text:match("(%b{})%s*$")
    if not json or not json:find('"scheme"', 1, true) and not json:find('"name"', 1, true) then
        raise("expo config printed no configuration:\n%s", text)
    end
    return json
end

function main(...)
    local shared = import("@addon.revenant.member", {anonymous = true})
    local given, words = shared.arguments({...}, {output = "value", help = "switch"})
    if given.help or #words ~= 1 or not given.output then
        print(USAGE)
        return
    end
    local app = path.absolute(words[1])
    if not os.isfile(path.join(app, "app.json")) and not os.isfile(path.join(app, "app.config.js")) and not os.isfile(path.join(app, "app.config.ts")) then
        raise("%s has no app.json, app.config.js or app.config.ts", app)
    end
    local json = public_json(app)
    local bundle = path.join(path.absolute(given.output), "EXConstants.bundle")
    os.mkdir(bundle)
    local file = path.join(bundle, "app.config")
    io.writefile(file, json)
    print("wrote " .. file)
end
