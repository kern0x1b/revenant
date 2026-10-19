-- xmake l ladder.lua <modules> <out> : first release on the cache ladder carrying each SCNView-related name, both ways
local CLASSES = {"SCNView", "SCNScene", "SCNNode", "SCNRenderer", "SCNTransaction", "SCNAction",
    "UIView" --[[ positive control ]], "CharonNoSuchClassXYZ" --[[ negative control ]]}
local PROTOCOLS = {"SCNSceneRenderer", "SCNSceneRendererDelegate", "SCNAnimatable"}
local SELECTORS = {
    {"UIView", "-", "setNeedsLayout"} --[[ selector control ]], {"UIView", "-", "charonNoSuchSelector"} --[[ negative ]], {"SCNView", "-", "initWithFrame:options:"}, {"SCNView", "-", "initWithFrame:"},
    {"SCNView", "-", "scene"}, {"SCNView", "-", "setScene:"},
    {"SCNView", "-", "delegate"}, {"SCNView", "-", "setDelegate:"},
    {"SCNView", "-", "preferredFramesPerSecond"}, {"SCNView", "-", "setPreferredFramesPerSecond:"},
    {"SCNView", "-", "isJitteringEnabled"}, {"SCNView", "-", "setJitteringEnabled:"},
    {"SCNView", "-", "snapshot"}, {"SCNView", "-", "play:"}, {"SCNView", "-", "pause:"},
    {"SCNView", "-", "isPlaying"}, {"SCNView", "-", "setPlaying:"}, {"SCNView", "-", "loops"},
    {"SCNView", "-", "allowsCameraControl"}, {"SCNView", "-", "antialiasingMode"},
    {"SCNView", "-", "eaglContext"}, {"SCNView", "-", "pointOfView"}, {"SCNView", "-", "autoenablesDefaultLighting"},
    {"SCNView", "-", "rendersContinuously"}, {"SCNView", "-", "sceneTime"},
    {"SCNNode", "-", "addAnimation:forKey:"}, {"SCNNode", "-", "removeAnimationForKey:"},
    {"SCNNode", "-", "animationKeys"}, {"SCNNode", "-", "removeAllAnimations"},
    {"SCNNode", "-", "removeAnimationForKey:blendOutDuration:"},
    {"SCNNode", "-", "eulerAngles"}, {"SCNNode", "-", "setEulerAngles:"},
    {"SCNNode", "-", "presentationNode"}, {"SCNNode", "-", "transform"}, {"SCNNode", "-", "worldTransform"},
    {"SCNMaterialProperty", "-", "addAnimation:forKey:"}, {"SCNMaterialProperty", "-", "contentsTransform"},
    {"SCNMaterialProperty", "-", "setContentsTransform:"},
    {"SCNParticleSystem", "-", "speedFactor"}, {"SCNParticleSystem", "-", "warmupDuration"},
    {"SCNParticleSystem", "-", "particleIntensity"}, {"SCNParticleSystem", "-", "particleColorVariation"},
    {"SCNParticleSystem", "-", "propertyControllers"},
}
local SYMBOLS = {"_SCNPreferredRenderingAPIKey", "_SCNPreferLowPowerDeviceKey",
    "_SCNParticlePropertySize", "_SCNParticlePropertyColor", "_SCNParticlePropertyOpacity",
    "_SCNLightingModelBlinn", "_SCNLightingModelPhysicallyBased",
    "_UIApplicationDidBecomeActiveNotification" --[[ control ]]}
local RELEASES = {"6.1.3", "7.0", "7.1.2", "8.0", "8.1.3", "8.4.1", "9.0", "9.3", "10.0.1", "10.3", "11.0", "12.0", "16.0"}

function main(modules, output)
    local dyld = import("apple.dyld", {rootdir = modules, anonymous = true})
    local objc = import("apple.objc", {rootdir = modules, anonymous = true})
    local first, lines = {}, {}
    local function note(key, release) if not first[key] then first[key] = release end end
    for _, release in ipairs(RELEASES) do
        local folder = path.join(dyld.root(), release)
        local cache
        for _, arch in ipairs({"armv7", "armv7s", "arm64", "arm64e"}) do
            cache = dyld.held_source(folder, arch)
            if cache and os.isfile(cache) then break end
            cache = nil
        end
        if cache then
            local loaded = dyld.load(cache)
            for _, s in ipairs(SYMBOLS) do if loaded.exports[s] then note(s, release) end end
            local found = objc.inventory(cache)
            for _, c in ipairs(CLASSES) do if found.classes[c] then note(c, release) end end
            for _, p in ipairs(PROTOCOLS) do if found.protocols and found.protocols[p] then note("@protocol " .. p, release) end end
            for _, e in ipairs(SELECTORS) do
                local class = found.classes[e[1]]
                local side = class and (e[2] == "+" and class.class or class.instance)
                if side and (side[e[2] .. e[3]] or side["-" .. e[3]] or side[e[3]]) then note(e[2] .. "[" .. e[1] .. " " .. e[3] .. "]", release) end
            end
            table.insert(lines, "# read " .. release .. " " .. path.filename(cache))
        else
            table.insert(lines, "# no cache for " .. release)
        end
    end
    local keys = {}
    for _, c in ipairs(CLASSES) do table.insert(keys, c) end
    for _, p in ipairs(PROTOCOLS) do table.insert(keys, "@protocol " .. p) end
    for _, e in ipairs(SELECTORS) do table.insert(keys, e[2] .. "[" .. e[1] .. " " .. e[3] .. "]") end
    for _, s in ipairs(SYMBOLS) do table.insert(keys, s) end
    for _, k in ipairs(keys) do table.insert(lines, k .. "\t" .. (first[k] or "none")) end
    io.writefile(output, table.concat(lines, "\n") .. "\n")
end
