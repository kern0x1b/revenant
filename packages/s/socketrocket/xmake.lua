package("socketrocket")
    set_homepage("https://github.com/facebook/SocketRocket")
    set_description("SocketRocket 0.7.1, the RFC 6455 WebSocket client React Native 0.86 pins through its CocoaPods helpers, as a static libSocketRocket for armv7 iOS 6 with the Objective-C runtime and ARC, linked against the Security and CFNetwork frameworks of that release")
    set_license("BSD-3-Clause")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/facebook/SocketRocket.git")
    add_versions("0.7.1", "21ac000390781823dd4bd87fdc419976e05dd7a6")
    add_links("SocketRocket")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "1", readonly = true})

    on_load("iphoneos", function (package)
        package:add("deps", "revenant@libcxx", {alias = "libcxx"})
        package:add("frameworks", "Foundation", "CFNetwork", "Security")
    end)

    local SOURCES = {
        "SocketRocket/NSRunLoop+SRWebSocket.m", "SocketRocket/NSURLRequest+SRWebSocket.m",
        "SocketRocket/SRSecurityPolicy.m", "SocketRocket/SRWebSocket.m",
        "SocketRocket/Internal/Delegate/SRDelegateController.m",
        "SocketRocket/Internal/IOConsumer/SRIOConsumer.m", "SocketRocket/Internal/IOConsumer/SRIOConsumerPool.m",
        "SocketRocket/Internal/Proxy/SRProxyConnect.m", "SocketRocket/Internal/RunLoop/SRRunLoopThread.m",
        "SocketRocket/Internal/SRConstants.m", "SocketRocket/Internal/Security/SRPinningSecurityPolicy.m",
        "SocketRocket/Internal/Utilities/SRError.m", "SocketRocket/Internal/Utilities/SRHTTPConnectMessage.m",
        "SocketRocket/Internal/Utilities/SRHash.m", "SocketRocket/Internal/Utilities/SRLog.m",
        "SocketRocket/Internal/Utilities/SRMutex.m", "SocketRocket/Internal/Utilities/SRRandom.m",
        "SocketRocket/Internal/Utilities/SRSIMDHelpers.m", "SocketRocket/Internal/Utilities/SRURLUtilities.m"
    }

    local INCLUDE_DIRS = {
        ".", "SocketRocket", "SocketRocket/Internal", "SocketRocket/Internal/Delegate",
        "SocketRocket/Internal/IOConsumer", "SocketRocket/Internal/Proxy", "SocketRocket/Internal/RunLoop",
        "SocketRocket/Internal/Security", "SocketRocket/Internal/Utilities"
    }

    on_install("iphoneos", function (package)
        local sources = import("@addon.revenant.apple.sources", {anonymous = true})
        os.mkdir(package:installdir("lib"))
        sources.static(package, {
            files = SOURCES,
            includedirs = INCLUDE_DIRS,
            mflags = {"-fobjc-arc"},
            headers = {"SocketRocket/*.h"},
            licenses = {"LICENSE", "PATENTS"},
            name = "SocketRocket"
        })
    end)

    on_test(function (package)
        for _, file in ipairs({"lib/libSocketRocket.a", "include/SocketRocket/SRWebSocket.h", "include/SocketRocket/SocketRocket.h"}) do
            assert(os.isfile(path.join(package:installdir(), file)), file .. " is not installed")
        end
        local probe = import("@addon.revenant.apple.probe", {anonymous = true})
        local ok, output = probe.check(package, {name = "probe.m", source = [[
#import <Foundation/Foundation.h>
#import <SocketRocket/SRWebSocket.h>
int main(int argc, char **argv) {
    (void)argv;
    @autoreleasepool {
        NSURL *url = [NSURL URLWithString:@"wss://example.com/socket"];
        SRWebSocket *socket = [[SRWebSocket alloc] initWithURL:url];
        return socket.readyState == SR_CONNECTING && argc > 0 ? 0 : 1;
    }
}
]], deps = {"libcxx"}, flags = {"-fobjc-arc"}, link = true,
            ldflags = {"-fobjc-arc", "-lSocketRocket", "-framework", "Foundation", "-framework", "CFNetwork", "-framework", "Security"},
            bound = {_os_unfair_lock_lock = "libc++", _SecRandomCopyBytes = "Security", _CFHTTPMessageCreateRequest = "CFNetwork"},
            linked = "@rpath/libc++.1.dylib"})
        assert(ok, "SocketRocket does not compile and link against armv7 libc++ with ARC: " .. output)
        probe.require_architecture(path.join(package:installdir("lib"), "libSocketRocket.a"), "armv7")
    end)
