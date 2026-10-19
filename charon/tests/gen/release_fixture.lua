-- The SDK folder a command reads for release 26.2, the release the corpus names in these tests carry: SDKSettings.json (the name and
-- version sdk.discover reads), SDKSettings.plist (what tbd checks an SDK folder by), and the framework folder of each framework named,
-- a nested one ("Outer/Inner") in its outer framework's Frameworks folder. write(root, frameworks) writes it under root/sdk-26.2 and
-- returns its path. No .tbd is written: the exports of a framework are empty.

function write(root, frameworks)
    local sdk = path.join(root, "sdk-26.2")
    os.mkdir(sdk)
    io.writefile(path.join(sdk, "SDKSettings.json"),
                 '{"CanonicalName":"iphoneos26.2","DefaultDeploymentTarget":"26.2","Version":"26.2"}\n')
    io.writefile(path.join(sdk, "SDKSettings.plist"), "")
    for _, fw in ipairs(frameworks or {}) do
        local dir = path.join(sdk, "System", "Library", "Frameworks")
        local names = string.split(fw, "/")
        for i, name in ipairs(names) do
            dir = path.join(dir, name .. ".framework")
            os.mkdir(dir)
            if i < #names then
                dir = path.join(dir, "Frameworks")
            end
        end
    end
    return sdk
end
