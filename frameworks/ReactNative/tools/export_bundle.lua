local USAGE = [[usage: ./xmakew l -P . frameworks/ReactNative/tools/export_bundle.lua [--output DIR] [--hermes] [--hermesc FILE] APP_DIR
  exports the iOS JavaScript bundle of an Expo application as DIR/bundle.js (default DIR is APP_DIR/dist-jsc).
  APP_DIR is the folder with the application's babel.config.js.
  Without --hermes the bundle is for the JavaScriptCore host: babel profile 'default', and frameworks/ReactNative/src/jsc-prelude.js,
  which defines atob and btoa that Hermes has and JavaScriptCore does not, is put in front of it.
  With --hermes the babel profile is 'hermes-stable': with the Hermes profile async functions stay native and return the engine's own
  promises, React Native keeps the engine's Promise, and no prelude is added. With --hermesc FILE the bundle is also compiled to
  DIR/bundle.hbc by that hermesc, which must be the Hermes package of the same version as the engine.]]

local WRAPPER = [[const original = require("./babel.config.hermes.js");
module.exports = function (api) {
  const config = original(api);
  config.presets = config.presets.map((preset) =>
    Array.isArray(preset) && preset[0] === "babel-preset-expo"
      ? [preset[0], { ...preset[1], unstable_transformProfile: "%s" }]
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

function wrapper(profile)
    return WRAPPER:format(profile)
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
    local given, words = shared.arguments({...}, {output = "value", hermes = "switch", hermesc = "value", help = "switch"})
    if given.help or #words ~= 1 or (given.hermesc and not given.hermes) then
        print(USAGE)
        return
    end
    local profile = given.hermes and "hermes-stable" or "default"
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
    io.writefile(config, wrapper(profile))
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
    local bundle = path.join(output, "bundle.js")
    if given.hermes then
        io.writefile(bundle, io.readfile(bundles[1]))
    else
        io.writefile(bundle, joined(io.readfile(prelude()), io.readfile(bundles[1])))
    end
    print("wrote " .. bundle)
    if given.hermesc then
        local bytecode = path.join(output, "bundle.hbc")
        os.vrunv(path.absolute(given.hermesc), {"-O", "-emit-binary", "-out", bytecode, bundle})
        print("wrote " .. bytecode)
    end
end
