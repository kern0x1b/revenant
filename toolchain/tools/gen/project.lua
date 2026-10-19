local DEFAULT_SDK16 = path.join(os.getenv("HOME") or "", ".xmake", "packages", "i", "iphoneos-sdk", "16.4",
                                "cccc080d0cbe42c2a85b1369aba6e290", "Developer.app", "Contents", "Developer", "Platforms",
                                "iPhoneOS.platform", "Developer", "SDKs", "iPhoneOS16.4.sdk")

function sdk16(args)
    return args.sdk16 or os.getenv("REVENANT_SDK16") or DEFAULT_SDK16
end

local DEFAULT_PORT_RELEASE = "6.1.3"

function port_release(args)
    return args.release or os.getenv("REVENANT_PORT_RELEASE") or DEFAULT_PORT_RELEASE
end

local DEFAULT_CLANG = path.join(os.getenv("HOME") or "", ".xmake", "packages", "l", "llvm", "23.1.1",
                                "6a8c97aaa69241df9ed69ac86f13a045", "bin", "clang")

function clang(args)
    return args.clang or os.getenv("REVENANT_CLANG") or DEFAULT_CLANG
end
