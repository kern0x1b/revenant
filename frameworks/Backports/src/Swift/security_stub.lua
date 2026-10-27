function stub()
    return {
        library = "SecurityBackports",
        installName = "/usr/lib/revenant/org.revenant.backports/libSecurityBackports.dylib",
        targets = {"armv7-ios", "arm64-ios", "arm64e-ios"},
        objcClasses = {"RevenantSecProtocolOptions"},
        symbols = {},
    }
end
