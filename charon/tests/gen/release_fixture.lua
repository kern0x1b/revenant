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
