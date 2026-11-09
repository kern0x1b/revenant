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
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>

void revenantVisitChanges(CNContactStore *store, CNChangeHistoryFetchRequest *request, id<CNChangeHistoryEventVisitor> visitor);

void revenantAcceptance(NSString *text, NSFileManager *files, CLLocationManager *manager)
{
    WKWebView *web = [[WKWebView alloc] initWithFrame:CGRectZero];
    web.navigationDelegate = nil;
    id<WKNavigationDelegate> navigation = web.navigationDelegate;
    (void)navigation;
    [web createWebArchiveDataWithCompletionHandler:^(NSData *archive, NSError *archiveError) {}];
    [web callAsyncJavaScript:@"return 1" arguments:@{@"x": @1} inFrame:nil inContentWorld:[WKContentWorld defaultClientWorld] completionHandler:^(id result, NSError *scriptError) {}];
    [web evaluateJavaScript:@"1" inFrame:nil inContentWorld:[WKContentWorld pageWorld] completionHandler:nil];
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    (void)[device newCommandQueue];
    (void)[device newBufferWithLength:16 options:0];
    (void)[device minimumLinearTextureAlignmentForPixelFormat:MTLPixelFormatBGRA8Unorm];
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
    (void)[manager authorizationStatus];
    (void)[manager accuracyAuthorization];
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
    NSUnderlineStyle underline = NSUnderlineStylePatternDot;
    (void)underline;
    CAFrameRateRange frameRates = CAFrameRateRangeMake(30.0f, 120.0f, 120.0f);
    (void)frameRates;
    (void)[UIPointerShape shapeWithRoundedRect:CGRectZero cornerRadius:8.0];
    AVCaptureDevice *camera = nil;
    (void)(camera.exposureTargetBias + camera.minExposureTargetBias + camera.maxExposureTargetBias);
    AVCaptureDeviceInput *cameraInput = nil;
    cameraInput.videoMinFrameDurationOverride = kCMTimeInvalid;
    AVCaptureVideoDataOutput *videoOutput = nil;
    (void)[videoOutput recommendedVideoSettingsForVideoCodecType:AVVideoCodecTypeH264 assetWriterOutputFileType:AVFileTypeMPEG4];
    (void)@[AVVideoColorPropertiesKey, AVVideoColorPrimariesKey, AVVideoColorPrimaries_ITU_R_709_2, AVVideoTransferFunctionKey,
            AVVideoTransferFunction_ITU_R_709_2, AVVideoYCbCrMatrixKey, AVVideoYCbCrMatrix_ITU_R_709_2];
    AVCapturePhotoSettings *photoSettings = [AVCapturePhotoSettings photoSettings];
    (void)photoSettings.availablePreviewPhotoPixelFormatTypes;
    (void)[AVCapturePhotoOutput class];
    CGMutablePathRef rounded = CGPathCreateMutable();
    CGPathAddRoundedRect(rounded, NULL, CGRectMake(0, 0, 10, 10), 2, 2);
    CGPathRef created = CGPathCreateWithRoundedRect(CGRectMake(0, 0, 10, 10), 2, 2, NULL);
    CGPathRelease(created);
    CGPathRelease(rounded);
    CNChangeHistoryEvent *changeEvent = nil;
    id<CNChangeHistoryEventVisitor> changeVisitor = nil;
    [changeEvent acceptEventVisitor:changeVisitor];
    CIImage *image = nil;
    (void)[image imageByApplyingOrientation:1];
    (void)[image imageTransformForOrientation:1];
    (void)[image imageByApplyingCGOrientation:kCGImagePropertyOrientationUp];
    (void)[image imageTransformForCGOrientation:kCGImagePropertyOrientationUp];
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

    local fixture_members = lowered.members_of(path.join(os.scriptdir(), "data", "src"), sdk)
    local synthesized = fixture_members.classes.FXProperties or {}
    assert(synthesized["-fx_first"] and synthesized["-fx_second"] and synthesized["-fx_third"],
           "every property of a synthesize list is an implemented member, not only the first")
    for _, class in ipairs({"FXMacroOne", "FXMacroTwo"}) do
        assert((fixture_members.classes[class] or {})["-fx_wrapped"], "a macro that wraps an implementation of its parameter implements that member in each class it is invoked for: " .. class)
    end
    assert(not fixture_members.classes.CLASS and not fixture_members.functions.FX_WRAPPED, "the macro definition is not an implementation of a class named after its parameter")
    local fixture = lowered.overlay(sdk, path.join(out, "fixture-overlay"), fixture_members)
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
    local calendar = table.concat({
        "public struct Calendar {",
        "    @available(iOS 8.0, *)",
        "    public func dateComponents(in timeZone: TimeZone, from date: Date) -> DateComponents {",
        "    }",
        "    @available(iOS 8.0, *)",
        "    public func nextDate(after date: Date, matching components: DateComponents, matchingPolicy: MatchingPolicy) -> Date? {",
        "    }",
        "    @available(iOS 8.0, *)",
        "    public func compare(_ date1: Date, to date2: Date, toGranularity component: Component) -> ComparisonResult {",
        "    }",
        "    @available(iOS 8.0, *)",
        "    public func enumerateDates(startingAfter start: Date, matching components: DateComponents) {",
        "    }",
        "    @available(iOS 8.0, *)",
        "    public func unrelated(after date: Date) -> Date? {",
        "    }",
        "    @available(iOS 8.0, *)",
        "    public func dateIntervalOfWeekend(containing date: Date, start: inout Date, interval: inout TimeInterval) -> Bool {",
        "    }",
        "    @available(macOS 10.12, iOS 10.0, *)",
        "    public func dateIntervalOfWeekend(containing date: Date) -> DateInterval? {",
        "    }",
        "    @available(macOS 10.12, iOS 10.0, *)",
        "    public func nextWeekend(startingAfter date: Date, direction: SearchDirection = .forward) -> DateInterval? {",
        "    }",
        "}",
        "public struct DateComponents {",
        "    @available(macOS 10.9, iOS 8.0, *)",
        "    public mutating func setValue(_ value: Int?, for component: Calendar.Component) {",
        "    }",
        "    @available(macOS 10.9, iOS 8.0, *)",
        "    public mutating func unrelated(_ value: Int?) {",
        "    }",
        "}",
        "",
    }, "\n")
    local calendar_names = lowered.swift_names({classes = {
        NSCalendar = {["-componentsInTimeZone:fromDate:"] = true, ["-nextDateAfterDate:matchingComponents:options:"] = true,
                      ["-compareDate:toDate:toUnitGranularity:"] = true,
                      ["-enumerateDatesStartingAfterDate:matchingComponents:options:usingBlock:"] = true,
                      ["-rangeOfWeekendStartDate:interval:containingDate:"] = true, ["-nextWeekendStartDate:interval:options:afterDate:"] = true},
        NSDateComponents = {["-setValue:forComponent:"] = true}}, functions = {}})
    local calendar_lowered = lowered.lower_swift_text(calendar, calendar_names)
    assert(count(calendar_lowered, "@available") == 4 and calendar_lowered:find("@available(iOS 8.0, *)\n    public func unrelated", 1, true) and
           calendar_lowered:find("@available(macOS 10.12, iOS 10.0, *)\n    public func dateIntervalOfWeekend", 1, true) and
           calendar_lowered:find("@available(macOS 10.12, iOS 10.0, *)\n    public func nextWeekend", 1, true) and
           calendar_lowered:find("@available(macOS 10.9, iOS 8.0, *)\n    public mutating func unrelated", 1, true),
           "the Calendar methods that the overlay names differently from the selectors they call, and the mutating method of DateComponents, must lose the iOS 8 gate when Backports implement the selector, and the others keep it, among them the overloads that return a DateInterval, an iOS 10 type:\n" .. calendar_lowered)
    local calendar_kept = lowered.lower_swift_text(calendar, lowered.swift_names({classes = {NSCalendar = {}, NSDateComponents = {}}, functions = {}}))
    assert(count(calendar_kept, "@available") == 10, "a selector that Backports does not implement must keep the gate of the Swift method that calls it:\n" .. calendar_kept)
    local lowering = lowered.lower_header(sample, members)
    assert(count(lowering, "AVAILABLE") == 1, "only the member that Backports does not implement may keep its availability:\n" .. lowering)
    assert(not lowering:find("MTLCreateSystemDefaultDevice(void) API_AVAILABLE", 1, true), "the implemented C function kept its availability:\n" .. lowering)
    local documented = table.concat({
        "/*!",
        " @protocol MTLSample",
        " @abstract A protocol that a doc comment names before its declaration",
        " */",
        "API_AVAILABLE(macos(10.11), ios(8.0)) NS_SWIFT_SENDABLE",
        "@protocol MTLSample <NSObject>",
        "- (void)run;",
        "@end",
        "API_AVAILABLE(macos(10.11), ios(8.0))",
        "@protocol MTLSkipped <NSObject>",
        "@end",
        "#if TARGET_OS_SIMULATOR",
        "API_AVAILABLE(macos(10.11), ios(13.0))",
        "#else",
        "API_AVAILABLE(macos(10.11), ios(8.0))",
        "#endif",
        "@interface MTLConditional : NSObject",
        "@end",
        "",
    }, "\n")
    local documented_lowering = lowered.lower_header(documented, {classes = {MTLConditional = {}}, functions = {}, globals = {}, protocols = {MTLSample = true}})
    assert(count(documented_lowering, "AVAILABLE") == 1 and documented_lowering:find("NS_SWIFT_SENDABLE\n@protocol MTLSample <NSObject>", 1, true)
           and documented_lowering:find("API_AVAILABLE(macos(10.11), ios(8.0))\n@protocol MTLSkipped", 1, true)
           and documented_lowering:find("#endif\n@interface MTLConditional : NSObject", 1, true),
           "a protocol named in a doc comment before its declaration kept its availability:\n" .. documented_lowering)
    local opened = table.concat({
        "// a line comment that opens /* and never closes it",
        "API_AVAILABLE(macos(10.11), ios(8.0))",
        "@protocol MTLAfterOpen <NSObject>",
        "@end",
        "/* closes the comment that the line comment above opened */",
        "",
    }, "\n")
    local opened_lowering = lowered.lower_header(opened, {classes = {}, functions = {}, globals = {}, protocols = {MTLAfterOpen = true}})
    assert(count(opened_lowering, "AVAILABLE") == 0 and opened_lowering:find("@protocol MTLAfterOpen <NSObject>", 1, true),
           "a declaration after a line comment that opens a block comment was taken for commented text:\n" .. opened_lowering)
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
    local measurement = table.concat({
        "@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)",
        "public struct Measurement<UnitType : Unit> : Comparable {",
        "}",
        "@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)",
        "extension MeasurementFormatter {",
        "    public func string<UnitType>(from measurement: Measurement<UnitType>) -> String {",
        "    }",
        "}",
        "@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)",
        "extension MeasurementFormatter {",
        "    public func string<UnitType>(from measurement: Measurement<UnitType>) -> String {",
        "    }",
        "    public var unlisted: Int {",
        "    }",
        "}",
        "",
    }, "\n")
    local measurement_names = lowered.swift_names({classes = {NSMeasurement = {}, NSMeasurementFormatter = {["-stringFromMeasurement:"] = true}},
                                                   functions = {}, globals = {}})
    local measurement_lowered = lowered.lower_swift_text(measurement, measurement_names)
    assert(count(measurement_lowered, "@available") == 1 and measurement_lowered:find("@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)\nextension MeasurementFormatter {\n    public func string<UnitType>(from measurement: Measurement<UnitType>) -> String {\n    }\n    public var unlisted", 1, true),
           "the Measurement struct and a MeasurementFormatter extension whose members are all implemented lower, and an extension with an unimplemented member keeps its availability:\n" .. measurement_lowered)
    local released ={AVSampleWriter = {instance = {"addInput:", "count", "oldMethod:"}, ["class"] = {}},
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
    local gated_sample = table.concat({
        "@interface SampleGated : NSObject",
        "@property (nonatomic) BOOL waits",
        "#if SAMPLE_ISOLATED",
        "SAMPLE_NONISOLATED",
        "#endif",
        "API_AVAILABLE(macos(10.12), ios(10.0));",
        "@property (nonatomic) float other API_AVAILABLE(ios(10.0));",
        "@end",
        "",
    }, "\n")
    local gated_lowered = lowered.lower_header(gated_sample, {classes = {SampleGated = {["-waits"] = true, ["-setWaits:"] = true}}})
    assert(count(gated_lowered, "API_AVAILABLE") == 1 and gated_lowered:find("#if SAMPLE_ISOLATED\nSAMPLE_NONISOLATED\n#endif\n;", 1, true)
           and gated_lowered:find("float other API_AVAILABLE(ios(10.0))", 1, true),
           "a property whose availability macro follows a preprocessor conditional is named after its own identifier, so a backported one loses the availability and its neighbour keeps it:\n" .. gated_lowered)
    local branched_sample = table.concat({
        "@interface SampleBranched : NSObject",
        "@property (nonatomic, readonly) double span",
        "#if __swift__",
        " API_UNAVAILABLE(visionos);",
        "#else",
        "API_AVAILABLE(macos(10.10), ios(7.0), visionos(1.0));",
        "#endif",
        "@property (nonatomic, readonly) double kept API_AVAILABLE(ios(7.0));",
        "- (void)stretch",
        "#if __swift__",
        " API_UNAVAILABLE(visionos);",
        "#else",
        "API_AVAILABLE(ios(7.0));",
        "#endif",
        "- (void)untouched API_AVAILABLE(ios(7.0));",
        "@end",
        "",
    }, "\n")
    local branched_lowered = lowered.lower_header(branched_sample, {classes = {SampleBranched = {["-span"] = true, ["-stretch"] = true}}})
    assert(count(branched_lowered, "API_AVAILABLE") == 2 and branched_lowered:find("double kept API_AVAILABLE(ios(7.0))", 1, true)
           and branched_lowered:find("untouched API_AVAILABLE(ios(7.0))", 1, true)
           and branched_lowered:find("#else\n;\n#endif\n@property", 1, true) and branched_lowered:find("#else\n;\n#endif\n- (void)untouched", 1, true),
           "a declaration whose availability is in the #else branch of a conditional loses it there, and the declarations around it keep theirs:\n" .. branched_lowered)
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
        "- (void)rewind API_AVAILABLE(ios(8.0));",
        "- (void)pause API_AVAILABLE(ios(8.0));",
        "@end",
        "",
    }, "\n"))
    os.mkdir(path.join(protocol_src, "Sample"))
    io.writefile(path.join(protocol_src, "Sample", "SampleView.h"), table.concat({
        "@interface SampleView : SampleBase <SampleEnvironment>",
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
    io.writefile(path.join(protocol_src, "Sample", "SampleBase.m"), table.concat({
        "@implementation SampleBase",
        "- (void)rewind",
        "{",
        "}",
        "@end",
        "",
    }, "\n"))
    io.writefile(path.join(protocol_sdk, "System", "Library", "Frameworks", "Sample.framework", "Headers", "SampleGenericKit.h"), table.concat({
        "@interface SampleGeneric<ItemType> : NSObject<SampleEnvironment>",
        "@end",
        "",
    }, "\n"))
    io.writefile(path.join(protocol_src, "Sample", "SampleGeneric.m"), table.concat({
        "@implementation SampleGeneric",
        "- (void)pause",
        "{",
        "}",
        "@end",
        "",
    }, "\n"))
    local status = lowered.protocol_status(protocol_src, protocol_sdk)
    local members = status.members.SampleEnvironment
    assert(members["-traits"] and members["+shared"] and members["-prepare"] and members["-reset"] and members["-rewind"] and members["-pause"]
           and not members["-traitsDidChange:"] and not members["-track"],
           "a protocol member is lowered when a class that conforms to the protocol implements it, directly, through a superclass, or in any folder, and not otherwise")
    local protocol_lowered = lowered.lower_header(io.readfile(protocol_header), {classes = {}, functions = {}, globals = {}, protocols = {SampleEnvironment = true},
                                                                                protocol_members = {SampleEnvironment = members}})
    assert(count(protocol_lowered, "AVAILABLE") == 2 and protocol_lowered:find("traitsDidChange:(SampleTraits *)previous API_AVAILABLE", 1, true)
           and protocol_lowered:find("track API_AVAILABLE", 1, true) and not protocol_lowered:find("traits API_AVAILABLE", 1, true)
           and not protocol_lowered:find("shared API_AVAILABLE", 1, true) and not protocol_lowered:find("prepare API_AVAILABLE", 1, true)
           and not protocol_lowered:find("reset API_AVAILABLE", 1, true) and not protocol_lowered:find("rewind API_AVAILABLE", 1, true)
           and not protocol_lowered:find("pause API_AVAILABLE", 1, true),
           "an implemented protocol member loses its availability, and a member Backports does not implement keeps it:\n" .. protocol_lowered)

    local visitor_header = table.concat({
        "API_AVAILABLE(ios(13.0))",
        "@protocol VisitVisitor <NSObject>",
        "- (void)visit:(VisitEvent *)event;",
        "@end",
        "",
        "API_AVAILABLE(ios(13.0))",
        "@protocol VisitUnnamed <NSObject>",
        "@end",
        "",
        "@protocol VisitPlain <NSObject>",
        "@end",
        "",
        "API_AVAILABLE_BEGIN(ios(13.0))",
        "@protocol VisitRegional <NSObject>",
        "@end",
        "API_AVAILABLE_END",
        "",
        "API_AVAILABLE(ios(13.0))",
        "@interface VisitEvent : NSObject",
        "- (void)accept:(id<VisitVisitor>)visitor API_AVAILABLE(ios(13.0));",
        "- (void)acceptPlain:(id<VisitPlain>)plain API_AVAILABLE(ios(13.0));",
        "- (void)acceptRegional:(id<VisitRegional>)regional API_AVAILABLE(ios(13.0));",
        "- (void)acceptNothing:(NSString *)text API_AVAILABLE(ios(13.0));",
        "@end",
        "",
    }, "\n")
    local visitor_set = {classes = {VisitEvent = {["-accept:"] = true, ["-acceptPlain:"] = true, ["-acceptRegional:"] = true}}, functions = {},
                         globals = {}, protocols = {}, protocol_members = {}, types = {}, enum_types = {}}
    local _, _, signature = lowered.signature_types({visitor_header}, visitor_set)
    assert(signature.VisitVisitor and signature.VisitRegional and not signature.VisitUnnamed and not signature.VisitPlain,
           "a protocol that an implemented member names in its signature and that carries availability, alone or through its region, is lowered with the member; one that no implemented member names, or that carries no availability, is not")
    visitor_set.protocols = signature
    local visitor_lowered = lowered.lower_header(visitor_header, visitor_set)
    assert(not visitor_lowered:find("API_AVAILABLE(ios(13.0))\n@protocol VisitVisitor", 1, true)
           and visitor_lowered:find("API_AVAILABLE(ios(13.0))\n@protocol VisitUnnamed", 1, true)
           and not visitor_lowered:find("API_AVAILABLE_BEGIN(ios(13.0))\n@protocol VisitRegional", 1, true),
           "the protocol in an implemented member's signature loses its availability and the protocol no signature names keeps it:\n" .. visitor_lowered)

    local photos_source = path.join(sdk, "System", "Library", "Frameworks", "Photos.framework", "Headers", "PhotosTypes.h")
    local photos_lowered = lowered.lower_header(io.readfile(photos_source), {markers = lowered.region_markers(sdk), classes = {}, functions = {},
                                                                              globals = {PHImageContentModeAspectFill = true}, protocols = {}})
    local photos_enum = photos_lowered:match("typedef NS_ENUM%(NSInteger, PHImageContentMode%) %b{}")
    assert(photos_enum and not photos_enum:find("API_AVAILABLE_BEGIN", 1, true) and not photos_enum:find("API_AVAILABLE_END", 1, true),
           "an availability marker sits inside the enum whose constant is lowered:\n" .. photos_lowered)
    assert(photos_enum:find("PHImageContentModeAspectFit API_AVAILABLE(", 1, true) and not photos_enum:find("PHImageContentModeAspectFill API_AVAILABLE", 1, true)
           and photos_enum:find("PHImageContentModeDefault API_AVAILABLE(", 1, true),
           "the constant Backports do not define keeps the region's availability, and the lowered constants lose it:\n" .. photos_enum)
    local aliased = lowered.lower_header(io.readfile(photos_source), {markers = lowered.region_markers(sdk), classes = {}, functions = {},
                                                                       globals = {PHImageContentModeAspectFit = true}, protocols = {}})
    local aliased_enum = aliased:match("typedef NS_ENUM%(NSInteger, PHImageContentMode%) %b{}")
    assert(aliased_enum and not aliased_enum:find("PHImageContentModeAspectFit API_AVAILABLE", 1, true)
           and not aliased_enum:find("PHImageContentModeDefault API_AVAILABLE", 1, true)
           and aliased_enum:find("PHImageContentModeAspectFill API_AVAILABLE(", 1, true),
           "a constant that only names a lowered constant is lowered with it, and a constant that names nothing lowered keeps its availability:\n" .. aliased_enum)
    local photos_probe = path.join(probes, "photos.m")
    io.writefile(photos_probe, table.concat({
        "#import <Photos/PhotosTypes.h>",
        "",
        "NSInteger revenantPhotosProbe(void)",
        "{",
        "    return PHImageContentModeAspectFill + PHImageContentModeAspectFit + PHImageContentModeDefault;",
        "}",
        "",
    }, "\n"))
    local photos_ok, photos_compiling = compiles(sdk, vfs, photos_probe, path.join(probes, "photos.log"))
    assert(photos_ok, "the lowered PhotosTypes.h does not compile at iOS 6.0:\n" .. photos_compiling)
    local photos_overlay = io.readfile(path.join(out, "overlay", "System", "Library", "Frameworks", "Photos.framework", "Headers", "PhotosTypes.h"))
    assert(not photos_overlay:find("PHImageContentModeDefault API_AVAILABLE", 1, true),
           "PHImageContentModeDefault names PHImageContentModeAspectFit, which Backports implement, so the overlay lowers it too")

    local webview_probe = path.join(probes, "webview.m")
    io.writefile(webview_probe, table.concat({
        "#import <UIKit/UIKit.h>",
        "",
        "void revenantWebViewProbe(UIWebView *web, id<UIWebViewDelegate> delegate, NSURLRequest *request)",
        "{",
        "    UIWebViewNavigationType type = UIWebViewNavigationTypeLinkClicked;",
        "    (void)type;",
        "    (void)[delegate webView:web shouldStartLoadWithRequest:request navigationType:UIWebViewNavigationTypeOther];",
        "}",
        "",
    }, "\n"))
    local webview_ok, webview_compiling = compiles(sdk, vfs, webview_probe, path.join(probes, "webview.log"))
    assert(webview_ok, "the lowered UIKit headers do not declare UIWebViewNavigationType for iOS 6.0:\n" .. webview_compiling)

    local sync_source = path.join(sdk, "System", "Library", "Frameworks", "CoreMedia.framework", "Headers", "CMSync.h")
    local sync_lowered = lowered.lower_header(io.readfile(sync_source), {classes = {}, functions = {CMTimebaseCopySource = true}, globals = {}, protocols = {}})
    local sync_flat = sync_lowered:gsub("%s+", " ")
    assert(count(sync_flat, "CMTimebaseCopySource%( CMTimebaseRef CM_NONNULL timebase %) ;") == 2 and not sync_flat:find("CMTimebaseCopySource( CMTimebaseRef CM_NONNULL timebase ) API_AVAILABLE", 1, true),
           "CMTimebaseCopySource is a static inline wrapper with its availability in the #else branch the iOS 6.0 build takes; the backport exports it, so both branches must declare it without availability:\n" .. sync_flat)
    local clock_probe = path.join(probes, "timebase.m")
    io.writefile(clock_probe, table.concat({
        "#import <CoreMedia/CoreMedia.h>",
        "",
        "CMClockOrTimebaseRef revenantTimebaseProbe(CMTimebaseRef timebase)",
        "{",
        "    return CMTimebaseCopySource(timebase);",
        "}",
        "",
    }, "\n"))
    local clock_ok, clock_compiling = compiles(sdk, vfs, clock_probe, path.join(probes, "timebase.log"))
    assert(clock_ok, "the lowered CoreMedia headers do not declare CMTimebaseCopySource for iOS 6.0:\n" .. clock_compiling)

    local marked_probe = path.join(probes, "marked.m")
    io.writefile(marked_probe, table.concat({
        "#import <CoreMedia/CoreMedia.h>",
        "#import <VideoToolbox/VideoToolbox.h>",
        "#import <AVFoundation/AVFoundation.h>",
        "#import <GameController/GameController.h>",
        "#import <SceneKit/SceneKit.h>",
        "#import <SensorKit/SensorKit.h>",
        "#import <Vision/Vision.h>",
        "",
        "OSStatus revenantMarkedFunctions(CMClockRef clock, CMTimebaseRef *timebase, CMTimeRange range, VTMultiPassStorageRef *storage)",
        "{",
        "    OSStatus status = CMTimebaseCreateWithSourceClock(kCFAllocatorDefault, clock, timebase);",
        "    (void)CMTimebaseCopySource(*timebase);",
        "    (void)VTMultiPassStorageGetTypeID();",
        "    status |= VTMultiPassStorageCreate(kCFAllocatorDefault, NULL, range, NULL, storage);",
        "    return status | VTMultiPassStorageClose(*storage);",
        "}",
        "",
        "void revenantMarkedGlobals(void)",
        "{",
        "    (void)kVTHDRPerFrameMetadataGenerationHDRFormatType_DolbyVision;",
        "    (void)AVCaptureReactionTypeHeart;",
        "    (void)GCInputDirectionPad;",
        "    (void)SCNMatrix4Identity;",
        "    (void)SRErrorDomain;",
        "    (void)VNVisionVersionNumber;",
        "}",
        "",
    }, "\n"))
    local marked_ok, marked_compiling = compiles(sdk, vfs, marked_probe, path.join(probes, "marked.log"))
    assert(marked_ok, "a function or global that Backports implement as BACKPORT_IMPL keeps its SDK availability in the lowered headers, whatever shape its definition has (an attribute before the return type, a typed global without const, a multi-line initialiser, a definition inside an implementation):\n" .. marked_compiling)
end
