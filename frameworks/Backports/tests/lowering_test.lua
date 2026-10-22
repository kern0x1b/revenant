local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

local IMPLEMENTED = [=[
#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import <Metal/Metal.h>

void revenantProbe(NSString *text, NSFileManager *files)
{
    (void)[[NSData alloc] initWithBase64EncodedString:@"" options:0];
    (void)[text stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
    (void)[files containerURLForSecurityApplicationGroupIdentifier:@"group"];
    (void)[WKWebView class];
    (void)MTLCreateSystemDefaultDevice();
}
]=]

local UNIMPLEMENTED = [=[
#import <Foundation/Foundation.h>

void revenantProbe(NSURL *url)
{
    (void)[NSURL URLByResolvingAliasFileAtURL:url options:0 error:NULL];
}
]=]

local function compiles(sdk, vfs, source, log)
    local code = os.execv("xcrun", {"clang", "-target", "armv7-apple-ios6.0", "-isysroot", sdk, "-fobjc-arc",
                                    "-Werror=unguarded-availability-new", "-Werror=unguarded-availability",
                                    "-ivfsoverlay", vfs, "-c", source, "-o", log .. ".o"},
                          {try = true, stdout = log, stderr = log})
    return code == 0, io.readfile(log) or ""
end

local function count(text, word)
    local _, found = text:gsub(word, "")
    return found
end

function main()
    local out = workspace.run("backports-lowering")
    local sdk = workspace.sdk()
    local vfs = lowered.overlay(sdk, path.join(out, "overlay"))
    local probes = path.join(out, "probes")
    os.mkdir(probes)

    local implemented = path.join(probes, "implemented.m")
    io.writefile(implemented, IMPLEMENTED)
    local ok, text = compiles(sdk, vfs, implemented, path.join(probes, "implemented.log"))
    assert(ok, "the lowered SDK headers do not compile the implemented members at iOS 6.0:\n" .. text)

    local unimplemented = path.join(probes, "unimplemented.m")
    io.writefile(unimplemented, UNIMPLEMENTED)
    local refused, refusal = compiles(sdk, vfs, unimplemented, path.join(probes, "unimplemented.log"))
    assert(not refused and refusal:find("is only available on iOS 8.0 or newer", 1, true),
           "a member that Backports does not implement must keep its iOS 8 availability:\n" .. refusal)

    local members = {classes = {NSData = {["-initWithBase64EncodedString:options:"] = true,
                                          ["-initWithBase64EncodedData:options:"] = false}}, functions = {MTLCreateSystemDefaultDevice = true}}
    local sample = table.concat({
        "@interface NSData : NSObject",
        "- (instancetype)initWithBase64EncodedString:(NSString *)value options:(NSUInteger)options API_AVAILABLE(macos(10.9), ios(7.0));",
        "- (instancetype)initWithBase64EncodedData:(NSData *)value options:(NSUInteger)options API_AVAILABLE(macos(10.9), ios(7.0));",
        "@end",
        "MTL_EXTERN id <MTLDevice> __nullable MTLCreateSystemDefaultDevice(void) API_AVAILABLE(macos(10.11), ios(8.0));",
    }, "\n")
    local lowering = lowered.lower_header(sample, members)
    assert(count(lowering, "AVAILABLE") == 1, "only the member that Backports does not implement may keep its availability:\n" .. lowering)
    assert(not lowering:find("MTLCreateSystemDefaultDevice(void) API_AVAILABLE", 1, true), "the implemented C function kept its availability:\n" .. lowering)
end
