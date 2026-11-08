function stub()
    return {
        {
            library = "UIKitBackports",
            installName = "/usr/lib/revenant/org.revenant.backports/libUIKitBackports.dylib",
            targets = {"armv7-ios", "arm64-ios", "arm64e-ios"},
            objcClasses = {"UTType"},
            symbols = {},
        },
    }
end
