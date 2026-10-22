function failures(opt)
    local apple_sdk = import("apple.sdk", {rootdir = opt.modules, anonymous = true})
    local found = {}
    if apple_sdk.apple_sdk_release() ~= "26.2" then
        table.insert(found, "every configure builds against SDK 26.2, the one SDK the graph uses")
    end
    if apple_sdk.folder("/opt/sdk", "26.2") ~= "/opt/sdk/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk" then
        table.insert(found, "the SDK folder is not iPhoneOS<release>.sdk under the install folder")
    end
    return found
end
