import("core.project.config")

function version()
    local named = config.get("apple_sdk") or ""
    if named ~= "" then
        return named
    end
    return (config.get("component") or "") == "" and "16.4" or "26.2"
end

function developer(installdir)
    if not installdir then
        return nil
    end
    return path.join(installdir, "Developer.app", "Contents", "Developer")
end

function folder(installdir, release)
    local root = developer(installdir)
    if not root then
        return nil
    end
    return path.join(root, "Platforms", "iPhoneOS.platform", "Developer", "SDKs", "iPhoneOS" .. release .. ".sdk")
end
