function developer(installdir)
    if not installdir then
        return nil
    end
    return path.join(installdir, "Developer.app", "Contents", "Developer")
end

function apple_sdk_release(component)
    if (component or "") == "" then
        return "16.4"
    end
    return "26.2"
end

function folder(installdir, release)
    local root = developer(installdir)
    if not root then
        return nil
    end
    return path.join(root, "Platforms", "iPhoneOS.platform", "Developer", "SDKs", "iPhoneOS" .. release .. ".sdk")
end
