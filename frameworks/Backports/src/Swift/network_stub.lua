function stub()
    return {
        library = "NetworkBackports",
        installName = "/usr/lib/revenant/org.revenant.backports/libNetworkBackports.dylib",
        targets = {"armv7-ios", "arm64-ios", "arm64e-ios"},
        objcClasses = {},
        symbols = {
            "_RevenantTLSOptionsCreate",
            "_RevenantTLSOptionsHasServerCredentials",
            "_RevenantTLSEngineCreate",
            "_RevenantTLSEngineFree",
            "_RevenantTLSEngineHandshake",
            "_RevenantTLSEngineRead",
            "_RevenantTLSEngineWrite",
            "_RevenantTLSEngineClose",
            "_RevenantTLSEngineIsEstablished",
            "_RevenantTLSEngineWantsWrite",
            "_RevenantTLSEngineNegotiatedVersion",
            "_RevenantTLSEngineNegotiatedCipherSuite",
            "_RevenantTLSEngineNegotiatedProtocol",
            "_RevenantTLSEngineOCSPResponse",
        },
    }
end
