-- The project's own fixed facts: the compile SDK of the package, the one the protocol bodies are transcribed from. They are options with
-- the project's defaults, not literals inside a step: a step takes sdk16(args), and --sdk16 or CHARON_SDK16 override the default. The
-- release of that SDK is read from it by sdk.discover, so no step names it. This file is the only place a machine path is written.

local DEFAULT_SDK16 = path.join(os.getenv("HOME") or "", ".xmake", "packages", "i", "iphoneos-sdk", "16.4",
                                "cccc080d0cbe42c2a85b1369aba6e290", "Developer.app", "Contents", "Developer", "Platforms",
                                "iPhoneOS.platform", "Developer", "SDKs", "iPhoneOS16.4.sdk")

-- The folder of the compile SDK: args.sdk16, else CHARON_SDK16, else the project's default.
function sdk16(args)
    return args.sdk16 or os.getenv("CHARON_SDK16") or DEFAULT_SDK16
end

-- The release the port is built for: args.release, else CHARON_PORT_RELEASE, else the project's default (what iOS 6.1.3
-- carries, the armv7 release the swift-runtime build makes its port headers for). The registry's implemented APIs are
-- available from it (target_availability.lua).
local DEFAULT_PORT_RELEASE = "6.1.3"

function port_release(args)
    return args.release or os.getenv("CHARON_PORT_RELEASE") or DEFAULT_PORT_RELEASE
end

local DEFAULT_CLANG = path.join(os.getenv("HOME") or "", ".xmake", "packages", "l", "llvm", "23.1.1",
                                "6a8c97aaa69241df9ed69ac86f13a045", "bin", "clang")

-- The clang the header pass compiles with: args.clang, else CHARON_CLANG, else the project's default.
function clang(args)
    return args.clang or os.getenv("CHARON_CLANG") or DEFAULT_CLANG
end
