local USAGE = [[usage: ./xmakew l frameworks/ReactNative/tools/export_bundle.lua [--output DIR] APP_DIR
  exports the iOS JavaScript bundle of an Expo application for the JavaScriptCore host, as DIR/bundle.js (default DIR is APP_DIR/dist-jsc).
  APP_DIR is the folder with the application's babel.config.js.
  Two things differ from the Hermes export. The babel profile is 'default' instead of 'hermes-stable': with the Hermes profile async
  functions stay native and return the engine's own promises, React Native replaces global.Promise because no HermesInternal says it
  owns it, and `result instanceof Promise` is false for every async result. And the bundle is not compiled to bytecode.
  frameworks/ReactNative/host/jsc-prelude.js, which defines atob and btoa that Hermes has and JavaScriptCore does not, is put in front of the bundle.]]

local WRAPPER = [[const original = require("./babel.config.hermes.js");
module.exports = function (api) {
  const config = original(api);
  config.presets = config.presets.map((preset) =>
    Array.isArray(preset) && preset[0] === "babel-preset-expo"
      ? [preset[0], { ...preset[1], unstable_transformProfile: "default" }]
      : preset,
  );
  return config;
};
]]

function wrapper()
    return WRAPPER
end

function prelude()
    return path.join(os.scriptdir(), "..", "host", "jsc-prelude.js")
end

function joined(front, bundle)
    return front .. "\n" .. bundle
end

function main(...)
    local shared = import("@addon.revenant.member", {anonymous = true})
    local given, words = shared.arguments({...}, {output = "value", help = "switch"})
    if given.help or #words ~= 1 then
        print(USAGE)
        return
    end
    local app = path.absolute(words[1])
    local config = path.join(app, "babel.config.js")
    local saved = path.join(app, "babel.config.hermes.js")
    if not os.isfile(config) then
        raise("%s has no babel.config.js", app)
    end
    if os.isfile(saved) then
        raise("%s exists: a previous export did not restore babel.config.js, look at both files", saved)
    end
    local output = path.absolute(given.output or path.join(app, "dist-jsc"))
    os.cp(config, saved)
    io.writefile(config, wrapper())
    local ok, failure = true, nil
    try {
        function ()
            os.execv("npx", {"expo", "export", "--platform", "ios", "--no-bytecode", "--clear", "--output-dir", output},
                     {curdir = app, envs = {CI = "1", EXPO_NO_TELEMETRY = "1"}})
        end,
        catch {
            function (raised)
                ok, failure = false, tostring(raised)
            end
        }
    }
    os.cp(saved, config)
    os.rm(saved)
    if not ok then
        raise("expo export failed: %s", failure)
    end
    local bundles = os.files(path.join(output, "_expo", "static", "js", "ios", "*.js"))
    if #bundles ~= 1 then
        raise("expected one iOS bundle under %s, found %d", output, #bundles)
    end
    io.writefile(path.join(output, "bundle.js"), joined(io.readfile(prelude()), io.readfile(bundles[1])))
    print("wrote " .. path.join(output, "bundle.js"))
end
