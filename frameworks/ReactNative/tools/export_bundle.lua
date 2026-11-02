local USAGE = [[usage: ./xmakew l -P . frameworks/ReactNative/tools/export_bundle.lua [--output DIR] APP_DIR
  exports the iOS JavaScript bundle of an Expo application for the JavaScriptCore host, as DIR/bundle.js (default DIR is APP_DIR/dist-jsc).
  APP_DIR is the folder with the application's babel.config.js.
  Two things differ from the Hermes export. The babel profile is 'default' instead of 'hermes-stable': with the Hermes profile async
  functions stay native and return the engine's own promises, React Native replaces global.Promise because no HermesInternal says it
  owns it, and `result instanceof Promise` is false for every async result. And the bundle is not compiled to bytecode.
  frameworks/ReactNative/src/jsc-prelude.js, which defines atob and btoa that Hermes has and JavaScriptCore does not, is put in front of the bundle.]]

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

local METRO_WRAPPER = [[const config = require("./metro.config.original.%s");
const previous = config.transformer.getTransformOptions;
config.transformer.getTransformOptions = async (...args) => {
  const base = previous ? await previous(...args) : { transform: {} };
  return { ...base, transform: { ...base.transform, inlineRequires: true } };
};
module.exports = config;
]]

function wrapper()
    return WRAPPER
end

function metro_wrapper(extension)
    return METRO_WRAPPER:format(extension)
end

function metro_config(app)
    for _, extension in ipairs({"cjs", "js"}) do
        local file = path.join(app, "metro.config." .. extension)
        if os.isfile(file) then
            return file, extension
        end
    end
end

function prelude()
    return path.join(os.scriptdir(), "..", "src", "jsc-prelude.js")
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
    local metro, extension = metro_config(app)
    local metro_saved = metro and path.join(app, "metro.config.original." .. extension)
    if not os.isfile(config) then
        raise("%s has no babel.config.js", app)
    end
    if not metro then
        raise("%s has no metro.config.cjs or metro.config.js", app)
    end
    for _, left in ipairs({saved, metro_saved}) do
        if os.isfile(left) then
            raise("%s exists: a previous export did not restore the configuration, look at it and its original", left)
        end
    end
    local output = path.absolute(given.output or path.join(app, "dist-jsc"))
    os.cp(config, saved)
    os.cp(metro, metro_saved)
    io.writefile(config, wrapper())
    io.writefile(metro, metro_wrapper(extension))
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
    os.cp(metro_saved, metro)
    os.rm(metro_saved)
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
