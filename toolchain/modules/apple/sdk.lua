function developer(installdir)
    if not installdir then
        return nil
    end
    return path.join(installdir, "Developer.app", "Contents", "Developer")
end

function folder(installdir, version)
    local root = developer(installdir)
    if not root then
        return nil
    end
    return path.join(root, "Platforms", "iPhoneOS.platform", "Developer", "SDKs", "iPhoneOS" .. version .. ".sdk")
end
