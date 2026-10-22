function failures(opt)
    local apple_sdk = import("apple.sdk", {rootdir = opt.modules, anonymous = true})
    local found = {}
    if apple_sdk.apple_sdk_release(nil) ~= "16.4" then
        table.insert(found, "a configuration without a component builds against SDK 16.4")
    end
    if apple_sdk.apple_sdk_release("") ~= "16.4" then
        table.insert(found, "an empty component builds against SDK 16.4")
    end
    if apple_sdk.apple_sdk_release("Backports") ~= "26.2" then
        table.insert(found, "the Backports component builds against SDK 26.2")
    end
    if apple_sdk.folder("/opt/sdk", "26.2") ~= "/opt/sdk/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk" then
        table.insert(found, "the SDK folder is not iPhoneOS<release>.sdk under the install folder")
    end
    return found
end
