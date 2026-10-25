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
    (void)[text stringByRemovingPercentEncoding];
    (void)[[NSCalendar currentCalendar] startOfDayForDate:[NSDate date]];
    (void)[[NSCalendar currentCalendar] dateByAddingUnit:NSCalendarUnitDay value:1 toDate:[NSDate date] options:0];
    (void)[[NSCalendar currentCalendar] isDateInToday:[NSDate date]];
    NSDate *weekend = nil;
    NSTimeInterval weekendInterval = 0;
    (void)[[NSCalendar currentCalendar] rangeOfWeekendStartDate:&weekend interval:&weekendInterval containingDate:[NSDate date]];
    if (@available(iOS 10.0, *)) {
        NSDateInterval *interval = nil;
        (void)[interval initWithStartDate:[NSDate date] duration:1.0];
    }
    NSDateComponents *components = nil;
    (void)[components isValidDate];
    if (@available(iOS 7.0, *)) {
        NSURLComponents *url = nil;
        (void)[url percentEncodedHost];
    }
    (void)[WKWebView class];
    (void)MTLCreateSystemDefaultDevice();
}
]=]

local ACCEPTANCE = [=[
#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import <Contacts/Contacts.h>
#import <UIKit/UIKit.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <CoreLocation/CoreLocation.h>
#import <AVFoundation/AVFoundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <Metal/Metal.h>
#import <Accelerate/Accelerate.h>

void revenantAcceptance(NSString *text, NSFileManager *files, CLLocationManager *manager)
{
    WKWebView *web = [[WKWebView alloc] initWithFrame:CGRectZero];
    web.navigationDelegate = nil;
    id<WKNavigationDelegate> navigation = web.navigationDelegate;
    (void)navigation;
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    (void)[device newCommandQueue];
    (void)[device newBufferWithLength:16 options:0];
    (void)[text stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
    (void)[text stringByRemovingPercentEncoding];
    (void)[files containerURLForSecurityApplicationGroupIdentifier:@"group"];
    NSDataBase64DecodingOptions decoding = NSDataBase64DecodingIgnoreUnknownCharacters;
    (void)[[NSData alloc] initWithBase64EncodedString:@"" options:decoding];
    (void)[[WKWebViewConfiguration alloc] init];
    (void)[[CNPostalAddress alloc] init];
    (void)[[LAContext alloc] init];
    (void)[UIGraphicsImageRenderer class];
    (void)[manager allowsBackgroundLocationUpdates];
    (void)UIApplicationUserDidTakeScreenshotNotification;
    NSSet<UIScene *> *scenes = [[UIApplication sharedApplication] connectedScenes];
    (void)scenes;
    (void)[UIWindowScene class];
    (void)[UIStatusBarManager class];
    UIWindowScene *scene = nil;
    (void)scene.activityItemsConfigurationSource;
    (void)[[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[]];
    (void)AVAudioSessionPortBluetoothLE;
    AVAssetWriter *writer = nil;
    AVAssetWriterInput *input = nil;
    [writer addInput:input];
    vImage_ARGBToYpCbCrMatrix matrix;
    vImage_YpCbCrPixelRange range = {0, 128, 255, 255, 255, 1, 255, 0};
    vImage_ARGBToYpCbCr info;
    (void)vImageConvert_ARGBToYpCbCr_GenerateConversion(&matrix, &range, &info, kvImageARGB8888, kvImage420Yp8_Cb8_Cr8, 0);
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
    local cache = path.join(path.directory(log), "module-cache")
    os.mkdir(cache)
    local code = os.execv("xcrun", {"clang", "-target", "armv7-apple-ios6.0", "-isysroot", sdk, "-fobjc-arc",
                                    "-Werror=unguarded-availability-new", "-Werror=unguarded-availability",
                                    "-fmodules-cache-path=" .. cache,
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

    local acceptance = path.join(probes, "acceptance.m")
    io.writefile(acceptance, ACCEPTANCE)
    local accepted, accepting = compiles(sdk, vfs, acceptance, path.join(probes, "acceptance.log"))
    assert(accepted, "the lowered SDK headers do not compile the acceptance members at iOS 6.0:\n" .. accepting)

    local fixture = lowered.overlay(sdk, path.join(out, "fixture-overlay"), lowered.members_of(path.join(os.scriptdir(), "data", "src"), sdk))
    local unimplemented = path.join(probes, "unimplemented.m")
    io.writefile(unimplemented, UNIMPLEMENTED)
    local refused, refusal = compiles(sdk, fixture, unimplemented, path.join(probes, "unimplemented.log"))
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
    local property = table.concat({
        "@interface NSString (RevenantTest)",
        "@property (nullable, readonly, copy) NSString *stringByRemovingPercentEncoding API_AVAILABLE(macos(10.9), ios(7.0));",
        "@end",
    }, "\n")
    local lowered_property = lowered.lower_header(property, {classes = {NSString = {["-stringByRemovingPercentEncoding"] = true}}, functions = {}})
    assert(count(lowered_property, "AVAILABLE") == 0, "an implemented property kept its availability:\n" .. lowered_property)
    local swift = table.concat({
        "extension StringProtocol where Index == String.Index {",
        "  @available(macOS 10.9, iOS 7.0, *)",
        "  public func addingPercentEncoding(",
        "    withAllowedCharacters allowedCharacters: CharacterSet",
        "  ) -> String? {",
        "  }",
        "  @available(macOS 10.9, iOS 7.0, *)",
        "  public var removingPercentEncoding: String? {",
        "    return _ns.removingPercentEncoding",
        "  }",
        "  @available(macOS 10.9, iOS 7.0, *)",
        "  public var unrelated: String? {",
        "  }",
        "}",
        "",
    }, "\n")
    local names = lowered.swift_names({classes = {NSString = {["-stringByRemovingPercentEncoding"] = true,
                                                             ["-stringByAddingPercentEncodingWithAllowedCharacters:"] = true}}, functions = {}})
    local swift_lowered = lowered.lower_swift_text(swift, names)
    assert(count(swift_lowered, "@available") == 1 and swift_lowered:find("@available(macOS 10.9, iOS 7.0, *)\n  public var unrelated", 1, true),
           "the Swift overlay must lower the availability of the members Backports implements and keep the others:\n" .. swift_lowered)
    local lowering = lowered.lower_header(sample, members)
    assert(count(lowering, "AVAILABLE") == 1, "only the member that Backports does not implement may keep its availability:\n" .. lowering)
    assert(not lowering:find("MTLCreateSystemDefaultDevice(void) API_AVAILABLE", 1, true), "the implemented C function kept its availability:\n" .. lowering)
    local typedefs = table.concat({
        "typedef NS_OPTIONS(NSUInteger, SampleOptions) {",
        "    SampleOne = 1UL << 0",
        "} API_AVAILABLE(macos(10.9), ios(7.0));",
        "typedef NS_OPTIONS(NSUInteger, SampleOther) {",
        "    SampleTwo = 1UL << 0",
        "} API_AVAILABLE(macos(10.9), ios(7.0));",
        "API_AVAILABLE(ios(14.3))",
        "typedef NS_ENUM(NSInteger, SampleLeading) {",
        "    SampleLead = 0",
        "};",
        "typedef void (^SampleBlock)(void) API_AVAILABLE(ios(9.0));",
        "@interface SampleReader : NSObject",
        "- (void)readWithOptions:(SampleOptions)options block:(SampleBlock)block API_AVAILABLE(macos(10.9), ios(7.0));",
        "@end",
        "",
    }, "\n")
    local typed = lowered.lower_header(typedefs, {classes = {SampleReader = {["-readWithOptions:block:"] = true}}, functions = {}, globals = {}, protocols = {},
                                                  types = {SampleOptions = true, SampleLeading = true, SampleBlock = true}})
    assert(count(typed, "AVAILABLE") == 1 and typed:find("} ;\n", 1, true) and typed:find("} API_AVAILABLE(macos(10.9), ios(7.0));\n", 1, true),
           "a typedef the backported signatures use lowers with them, and the one they do not use keeps its availability:\n" .. typed)
    assert(not typed:find("API_AVAILABLE(ios(14.3))", 1, true) and not typed:find("API_AVAILABLE(ios(9.0))", 1, true),
           "an availability written before a typedef, and on a block typedef, lowers with the typedef:\n" .. typed)
    local base64 = table.concat({
        "@available(macOS 10.9, iOS 7.0, *)",
        "public typealias Base64DecodingOptions = NSData.Base64DecodingOptions",
        "extension Data {",
        "  @available(macOS 10.9, iOS 7.0, *)",
        "  public init?(base64Encoded base64String: __shared String, options: Data.Base64DecodingOptions = []) {",
        "  }",
        "  @available(macOS 10.9, iOS 7.0, *)",
        "  public init?(base64Encoded base64Data: __shared Data, options: Data.Base64DecodingOptions = []) {",
        "  }",
        "}",
        "",
    }, "\n")
    local base64_names = lowered.swift_names({classes = {NSData = {["-initWithBase64EncodedString:options:"] = true}}, functions = {}, globals = {}})
    local base64_lowered = lowered.lower_swift_text(base64, base64_names, {NSDataBase64DecodingOptions = true})
    assert(count(base64_lowered, "@available") == 1 and base64_lowered:find("@available(macOS 10.9, iOS 7.0, *)\n  public init?(base64Encoded base64Data", 1, true),
           "the Swift base64 initializer and the typealias of its options lower with the Objective-C member, and the Data overload keeps its availability:\n" .. base64_lowered)
    local released = {AVSampleWriter = {instance = {"addInput:", "count", "oldMethod:"}, ["class"] = {}},
                      AVSampleLater = {instance = {}, ["class"] = {}}}
    local device_sample = table.concat({
        "API_AVAILABLE(ios(8.0))",
        "@interface AVSampleLater : NSObject",
        "@end",
        "@interface AVSampleWriter : NSObject",
        "- (void)addInput:(id)input API_AVAILABLE(macos(10.10), visionos(1.0), ios(8.0));",
        "- (void)oldMethod:(id)x API_AVAILABLE(ios(4.1));",
        "- (void)notOnDevice:(id)x API_AVAILABLE(ios(9.0));",
        "@property (nonatomic, readonly) int count API_AVAILABLE(ios(8.0));",
        "@end",
        "",
    }, "\n")
    local device = lowered.device_members_in(device_sample, released, {})
    assert(device.classes.AVSampleWriter and device.classes.AVSampleWriter["-addInput:"] and device.classes.AVSampleWriter["-count"]
           and not device.classes.AVSampleWriter["-oldMethod:"] and not device.classes.AVSampleWriter["-notOnDevice:"],
           "the release's members that the SDK annotates later are the device members, and only those:\n" .. tostring(device.classes.AVSampleWriter))
    assert(device.classes.AVSampleLater, "a class the release implements and the SDK annotates later is a device class")
    local device_lowered = lowered.lower_header(device_sample, device)
    assert(count(device_lowered, "AVAILABLE") == 2 and not device_lowered:find("addInput:(id)input API_AVAILABLE", 1, true),
           "a device member loses its later availability, and the members the release lacks keep it:\n" .. device_lowered)
    local protocol_sdk = path.join(out, "protocol-sdk")
    local protocol_src = path.join(out, "protocol-src")
    local protocol_header = path.join(protocol_sdk, "System", "Library", "Frameworks", "Sample.framework", "Headers", "SampleEnvironment.h")
    os.mkdir(path.directory(protocol_header))
    io.writefile(protocol_header, table.concat({
        "@protocol SampleEnvironment <NSObject>",
        "@property (nonatomic, readonly) SampleTraits *traits API_AVAILABLE(ios(8.0));",
        "@property (nonatomic, class, readonly) BOOL shared API_AVAILABLE(ios(8.0));",
        "- (void)traitsDidChange:(SampleTraits *)previous API_AVAILABLE(ios(8.0));",
        "- (void)prepare API_AVAILABLE(ios(8.0));",
        "- (void)reset API_AVAILABLE(ios(8.0));",
        "- (void)track API_AVAILABLE(ios(8.0));",
        "@end",
        "",
    }, "\n"))
    os.mkdir(path.join(protocol_src, "Sample"))
    io.writefile(path.join(protocol_src, "Sample", "SampleView.h"), table.concat({
        "@interface SampleView : NSObject <SampleEnvironment>",
        "@end",
        "",
    }, "\n"))
    io.writefile(path.join(protocol_src, "Sample", "SampleView.m"), table.concat({
        "@implementation SampleView (Environment)",
        "- (SampleTraits *)traits",
        "{",
        "    return nil;",
        "}",
        "+ (BOOL)shared",
        "{",
        "    return YES;",
        "}",
        "- (void)prepare",
        "{",
        "}",
        "@end",
        "",
    }, "\n"))
    os.mkdir(path.join(protocol_src, "Other"))
    io.writefile(path.join(protocol_src, "Other", "SampleOther.h"), table.concat({
        "@interface SampleOther : NSObject <SampleEnvironment>",
        "@end",
        "",
    }, "\n"))
    io.writefile(path.join(protocol_src, "Other", "SampleOther.m"), table.concat({
        "@implementation SampleOther",
        "- (void)reset",
        "{",
        "}",
        "@end",
        "",
    }, "\n"))
    io.writefile(path.join(protocol_src, "Sample", "SampleUnrelated.m"), table.concat({
        "@implementation SampleUnrelated",
        "- (void)traitsDidChange:(SampleTraits *)previous",
        "{",
        "}",
        "@end",
        "",
    }, "\n"))
    io.writefile(path.join(protocol_src, "Sample", "SampleUse.m"), table.concat({
        "@implementation SampleUse",
        "- (void)run:(SampleView *)view",
        "{",
        "    [view track];",
        "}",
        "@end",
        "",
    }, "\n"))
    local status = lowered.protocol_status(protocol_src, protocol_sdk)
    local members = status.members.SampleEnvironment
    assert(members["-traits"] and members["+shared"] and members["-prepare"] and members["-reset"] and not members["-traitsDidChange:"] and not members["-track"],
           "a protocol member is lowered when a class that conforms to the protocol implements it, in any folder, and not otherwise")
    local protocol_lowered = lowered.lower_header(io.readfile(protocol_header), {classes = {}, functions = {}, globals = {}, protocols = {SampleEnvironment = true},
                                                                                protocol_members = {SampleEnvironment = members}})
    assert(count(protocol_lowered, "AVAILABLE") == 2 and protocol_lowered:find("traitsDidChange:(SampleTraits *)previous API_AVAILABLE", 1, true)
           and protocol_lowered:find("track API_AVAILABLE", 1, true) and not protocol_lowered:find("traits API_AVAILABLE", 1, true)
           and not protocol_lowered:find("shared API_AVAILABLE", 1, true) and not protocol_lowered:find("prepare API_AVAILABLE", 1, true)
           and not protocol_lowered:find("reset API_AVAILABLE", 1, true),
           "an implemented protocol member loses its availability, and a member Backports does not implement keeps it:\n" .. protocol_lowered)
end
