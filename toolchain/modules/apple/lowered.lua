local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})
local json = import("core.base.json")
local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..")})
local runtime_guards = import("runtime_guards", {rootdir = os.scriptdir(), anonymous = true})
local flat_classes = import("flat_classes", {rootdir = os.scriptdir(), anonymous = true})

local TRAIT_REGISTRATION = {
    {"- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<UITrait> *)traits withHandler:(UITraitChangeHandler)handler", "registerForTraitChanges(_:handler:)"},
    {"- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<UITrait> *)traits withTarget:(id)target action:(SEL)action", "registerForTraitChanges(_:target:action:)"},
    {"- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<UITrait> *)traits withAction:(SEL)action", "registerForTraitChanges(_:action:)"},
    {"- (void)unregisterForTraitChanges:(id<UITraitChangeRegistration>)registration", "unregisterForTraitChanges(_:)"},
}

local function trait_declaration(entry)
    return entry[1] .. " NS_SWIFT_NAME(" .. entry[2] .. ");"
end

local function trait_registration(owner, interface)
    local declarations = {}
    for _, entry in ipairs(TRAIT_REGISTRATION) do
        table.insert(declarations, trait_declaration(entry))
    end
    return {
        member = owner,
        header = {
            name = "UIKit",
            directory = {"System", "Library", "Frameworks", "UIKit.framework", "Headers"},
            file = owner .. ".h",
            find = interface,
            replace = interface .. "\n" .. table.concat(declarations, "\n"),
        },
    }
end

local function trait_protocol_name(entry)
    return {
        member = "UITraitChangeObservable",
        header = {
            name = "UIKit",
            directory = {"System", "Library", "Frameworks", "UIKit.framework", "Headers"},
            file = "UITraitCollection.h",
            find = entry[1] .. ";",
            replace = trait_declaration(entry),
        },
    }
end

local MEMBERS = {
    trait_registration("UIView", "@interface UIView () <UITraitChangeObservable>"),
    trait_registration("UIViewController", "@interface UIViewController () <UITraitChangeObservable>"),
    trait_registration("UIWindowScene", "@interface UIWindowScene () <UITraitEnvironment, UITraitChangeObservable>"),
    trait_registration("UIPresentationController", "@interface UIPresentationController () <UITraitChangeObservable>"),
    trait_protocol_name(TRAIT_REGISTRATION[1]),
    trait_protocol_name(TRAIT_REGISTRATION[2]),
    trait_protocol_name(TRAIT_REGISTRATION[3]),
    trait_protocol_name(TRAIT_REGISTRATION[4]),
    {
        member = "UIPointerStyle",
        header = {
            name = "UIKit",
            directory = {"System", "Library", "Frameworks", "UIKit.framework", "Headers"},
            file = "UIPointerStyle.h",
            find = "+ (instancetype)systemPointerStyle API_AVAILABLE(ios(15.0));",
            replace = "+ (instancetype)systemPointerStyle;",
        },
    },
    {
        member = "kCGColorSpaceSRGB",
        header = {
            name = "CoreGraphics",
            directory = {"System", "Library", "Frameworks", "CoreGraphics.framework", "Headers"},
            file = "CGColorSpace.h",
            find = "CG_EXTERN const CFStringRef kCGColorSpaceSRGB\n  API_AVAILABLE(macos(10.5), ios(9.0));",
            replace = "CG_EXTERN const CFStringRef kCGColorSpaceSRGB\n  API_AVAILABLE(macos(10.5), ios(6.0)) __attribute__((weak_import));",
        },
    },
    {
        member = "UIKeyboardAppearanceDark",
        header = {
            name = "UIKit",
            directory = {"System", "Library", "Frameworks", "UIKit.framework", "Headers"},
            file = "UITextInputTraits.h",
            find = "UIKeyboardAppearanceDark API_AVAILABLE(ios(7.0)),",
            replace = "UIKeyboardAppearanceDark API_AVAILABLE(ios(6.0)),",
        },
    },
    {
        member = "UIKeyboardTypeWebSearch",
        header = {
            name = "UIKit",
            directory = {"System", "Library", "Frameworks", "UIKit.framework", "Headers"},
            file = "UITextInputTraits.h",
            find = "UIKeyboardTypeWebSearch API_AVAILABLE(ios(7.0)),",
            replace = "UIKeyboardTypeWebSearch API_AVAILABLE(ios(6.0)),",
        },
    },
    {
        member = "UIKeyboardTypeASCIICapableNumberPad",
        header = {
            name = "UIKit",
            directory = {"System", "Library", "Frameworks", "UIKit.framework", "Headers"},
            file = "UITextInputTraits.h",
            find = "UIKeyboardTypeASCIICapableNumberPad API_AVAILABLE(ios(10.0)) API_UNAVAILABLE(watchos),",
            replace = "UIKeyboardTypeASCIICapableNumberPad API_AVAILABLE(ios(6.0)) API_UNAVAILABLE(watchos),",
        },
    },
    {
        member = "UIBackgroundFetchResult",
        header = {
            name = "UIKit",
            directory = {"System", "Library", "Frameworks", "UIKit.framework", "Headers"},
            file = "UIApplication.h",
            find = "    UIBackgroundFetchResultFailed\n} API_AVAILABLE(ios(7.0)) API_UNAVAILABLE(watchos);",
            replace = "    UIBackgroundFetchResultFailed\n} API_AVAILABLE(ios(6.0)) API_UNAVAILABLE(watchos);",
        },
    },
    {
        member = "UIApplicationDelegate application:continue:restorationHandler:",
        header = {
            name = "UIKit",
            directory = {"System", "Library", "Frameworks", "UIKit.framework", "Headers"},
            file = "UIApplication.h",
            find = "- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void(^)(NSArray<id<UIUserActivityRestoring>> * __nullable restorableObjects))restorationHandler API_DEPRECATED(\"Use UIScene lifecycle and scene(_:continue:) from UISceneDelegate instead.\", ios(8.0, 26.0), tvos(9.0, 26.0), visionos(1.0, 26.0)) API_UNAVAILABLE(watchos);",
            replace = "- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void(^)(NSArray<id<UIUserActivityRestoring>> * __nullable restorableObjects))restorationHandler API_DEPRECATED(\"Use UIScene lifecycle and scene(_:continue:) from UISceneDelegate instead.\", ios(6.0, 26.0), tvos(9.0, 26.0), visionos(1.0, 26.0)) API_UNAVAILABLE(watchos);",
        },
    },
    {
        member = "UIApplicationDelegate application:didFailToContinueUserActivityWithType:error:",
        header = {
            name = "UIKit",
            directory = {"System", "Library", "Frameworks", "UIKit.framework", "Headers"},
            file = "UIApplication.h",
            find = "- (void)application:(UIApplication *)application didFailToContinueUserActivityWithType:(NSString *)userActivityType error:(NSError *)error API_DEPRECATED(\"Use UIScene lifecycle and scene(_:didFailToContinueUserActivityWithType:error:) from UISceneDelegate instead.\", ios(8.0, 26.0), tvos(9.0, 26.0), visionos(1.0, 26.0)) API_UNAVAILABLE(watchos);",
            replace = "- (void)application:(UIApplication *)application didFailToContinueUserActivityWithType:(NSString *)userActivityType error:(NSError *)error API_DEPRECATED(\"Use UIScene lifecycle and scene(_:didFailToContinueUserActivityWithType:error:) from UISceneDelegate instead.\", ios(6.0, 26.0), tvos(9.0, 26.0), visionos(1.0, 26.0)) API_UNAVAILABLE(watchos);",
        },
    },
    {
        member = "UIApplicationDelegate application:didUpdateUserActivity:",
        header = {
            name = "UIKit",
            directory = {"System", "Library", "Frameworks", "UIKit.framework", "Headers"},
            file = "UIApplication.h",
            find = "- (void)application:(UIApplication *)application didUpdateUserActivity:(NSUserActivity *)userActivity API_DEPRECATED(\"Use UIScene lifecycle and scene(_:didUpdate) from UISceneDelegate instead.\", ios(8.0, 26.0), tvos(9.0, 26.0), visionos(1.0, 26.0)) API_UNAVAILABLE(watchos);",
            replace = "- (void)application:(UIApplication *)application didUpdateUserActivity:(NSUserActivity *)userActivity API_DEPRECATED(\"Use UIScene lifecycle and scene(_:didUpdate) from UISceneDelegate instead.\", ios(6.0, 26.0), tvos(9.0, 26.0), visionos(1.0, 26.0)) API_UNAVAILABLE(watchos);",
        },
    },
    {
        member = "UIApplicationDelegate application:willContinueUserActivityWithType:",
        header = {
            name = "UIKit",
            directory = {"System", "Library", "Frameworks", "UIKit.framework", "Headers"},
            file = "UIApplication.h",
            find = "- (BOOL)application:(UIApplication *)application willContinueUserActivityWithType:(NSString *)userActivityType API_DEPRECATED(\"Use UIScene lifecycle and scene(_:willContinueUserActivityWithType:) from UISceneDelegate instead.\", ios(8.0, 26.0), tvos(9.0, 26.0), visionos(1.0, 26.0)) API_UNAVAILABLE(watchos);",
            replace = "- (BOOL)application:(UIApplication *)application willContinueUserActivityWithType:(NSString *)userActivityType API_DEPRECATED(\"Use UIScene lifecycle and scene(_:willContinueUserActivityWithType:) from UISceneDelegate instead.\", ios(6.0, 26.0), tvos(9.0, 26.0), visionos(1.0, 26.0)) API_UNAVAILABLE(watchos);",
        },
    },
    {
        member = "UIApplicationDelegate application:didReceiveRemoteNotification:fetchCompletionHandler:",
        header = {
            name = "UIKit",
            directory = {"System", "Library", "Frameworks", "UIKit.framework", "Headers"},
            file = "UIApplication.h",
            find = "- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler API_AVAILABLE(ios(7.0));",
            replace = "- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler API_AVAILABLE(ios(6.0));",
        },
    },
    {
        member = "UIApplicationDelegate application:handleEventsForBackgroundURLSession:completionHandler:",
        header = {
            name = "UIKit",
            directory = {"System", "Library", "Frameworks", "UIKit.framework", "Headers"},
            file = "UIApplication.h",
            find = "- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)(void))completionHandler API_AVAILABLE(ios(7.0));",
            replace = "- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)(void))completionHandler API_AVAILABLE(ios(6.0));",
        },
    },
    {
        member = "UIApplicationDelegate application:performFetchWithCompletionHandler:",
        header = {
            name = "UIKit",
            directory = {"System", "Library", "Frameworks", "UIKit.framework", "Headers"},
            file = "UIApplication.h",
            find = "- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler NS_SWIFT_DISABLE_ASYNC API_DEPRECATED(\"Use a BGAppRefreshTask in the BackgroundTasks framework instead\", ios(7.0, 13.0), tvos(11.0, 13.0)) API_UNAVAILABLE(visionos, watchos);",
            replace = "- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler NS_SWIFT_DISABLE_ASYNC API_DEPRECATED(\"Use a BGAppRefreshTask in the BackgroundTasks framework instead\", ios(6.0, 13.0), tvos(11.0, 13.0)) API_UNAVAILABLE(visionos, watchos);",
        },
    },
    {
        member = "UIApplicationDelegate application:openURL:options:",
        header = {
            name = "UIKit",
            directory = {"System", "Library", "Frameworks", "UIKit.framework", "Headers"},
            file = "UIApplication.h",
            find = "- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options API_DEPRECATED(\"Use UIScene lifecycle and scene(_:openURLContexts:) from UISceneDelegate instead.\", ios(9.0, 26.0), tvos(9.0, 26.0), visionos(1.0, 26.0)) API_UNAVAILABLE(watchos);",
            replace = "- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options API_DEPRECATED(\"Use UIScene lifecycle and scene(_:openURLContexts:) from UISceneDelegate instead.\", ios(6.0, 26.0), tvos(9.0, 26.0), visionos(1.0, 26.0)) API_UNAVAILABLE(watchos);",
        },
    },
    {
        member = "UIApplicationDelegate application:performActionForShortcutItem:completionHandler:",
        header = {
            name = "UIKit",
            directory = {"System", "Library", "Frameworks", "UIKit.framework", "Headers"},
            file = "UIApplication.h",
            find = "- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void(^)(BOOL succeeded))completionHandler API_DEPRECATED(\"Use UIScene lifecycle and windowScene(_:performActionFor:completionHandler:) from UIWindowSceneDelegate instead.\", ios(9.0, 26.0), visionos(1.0, 26.0)) API_UNAVAILABLE(tvos, watchos);",
            replace = "- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void(^)(BOOL succeeded))completionHandler API_DEPRECATED(\"Use UIScene lifecycle and windowScene(_:performActionFor:completionHandler:) from UIWindowSceneDelegate instead.\", ios(6.0, 26.0), visionos(1.0, 26.0)) API_UNAVAILABLE(tvos, watchos);",
        },
    },
    {
        member = "UIEditMenuConfiguration",
        header = {
            name = "UIKit",
            directory = {"System", "Library", "Frameworks", "UIKit.framework", "Headers"},
            file = "UIEditMenuInteraction.h",
            find = "+ (instancetype)configurationWithIdentifier:(nullable id<NSCopying>)identifier sourcePoint:(CGPoint)sourcePoint;",
            replace = "+ (instancetype)configurationWithIdentifier:(nullable id<NSCopying>)identifier sourcePoint:(CGPoint)sourcePoint NS_SWIFT_NAME(init(identifier:sourcePoint:));",
        },
    },
    {
        member = "UIPointerStyle",
        header = {
            name = "UIKit",
            directory = {"System", "Library", "Frameworks", "UIKit.framework", "Headers"},
            file = "UIPointerStyle.h",
            find = "+ (instancetype)styleWithShape:(UIPointerShape *)shape constrainedAxes:(UIAxis)axes NS_REFINED_FOR_SWIFT;",
            replace = "+ (instancetype)styleWithShape:(UIPointerShape *)shape constrainedAxes:(UIAxis)axes NS_SWIFT_NAME(init(revenantShape:constrainedAxes:));",
        },
    },
    {
        member = "UIPointerEffect",
        header = {
            name = "UIKit",
            directory = {"System", "Library", "Frameworks", "UIKit.framework", "Headers"},
            file = "UIPointerStyle.h",
            find = "+ (instancetype)effectWithPreview:(UITargetedPreview *)preview;",
            replace = table.concat({
                "+ (instancetype)automaticEffectWithPreview:(UITargetedPreview *)preview NS_SWIFT_NAME(automatic(_:));",
                "+ (instancetype)highlightEffectWithPreview:(UITargetedPreview *)preview NS_SWIFT_NAME(highlight(_:));",
                "+ (instancetype)liftEffectWithPreview:(UITargetedPreview *)preview NS_SWIFT_NAME(lift(_:));",
                "+ (instancetype)effectWithPreview:(UITargetedPreview *)preview;",
            }, "\n"),
        },
    },
    {
        member = "UIPointerEffect",
        header = {
            name = "UIKit",
            directory = {"System", "Library", "Frameworks", "UIKit.framework", "Headers"},
            file = "UIPointerStyle.h",
            find = "} API_AVAILABLE(ios(13.4)) API_UNAVAILABLE(watchos, tvos) NS_REFINED_FOR_SWIFT;",
            replace = table.concat({
                "} API_UNAVAILABLE(watchos, tvos) NS_REFINED_FOR_SWIFT;",
                "",
                "@interface UIPointerEffect (RevenantHover)",
                "+ (instancetype)hoverEffectWithPreview:(UITargetedPreview *)preview preferredTintMode:(UIPointerEffectTintMode)mode prefersShadow:(BOOL)shadow prefersScaledContent:(BOOL)scaled NS_SWIFT_NAME(hover(_:preferredTintMode:prefersShadow:prefersScaledContent:));",
                "@end",
            }, "\n"),
        },
    },
    {
        member = "CGPathCreateWithRoundedRect",
        header = {
            name = "CoreGraphics",
            directory = {"System", "Library", "Frameworks", "CoreGraphics.framework", "Headers"},
            file = "CGPath.h",
            find = "CGFloat cornerWidth, CGFloat cornerHeight,\n    const CGAffineTransform * __nullable transform)\n    API_AVAILABLE(macos(10.9), ios(7.0));",
            replace = "CGFloat cornerWidth, CGFloat cornerHeight,\n    const CGAffineTransform * __nullable transform);",
        },
    },
    {
        member = "NSBaselineOffsetAttributeName",
        header = {
            name = "UIKit",
            directory = {"System", "Library", "Frameworks", "UIKit.framework", "Headers"},
            file = "NSAttributedString.h",
            find = "UIKIT_EXTERN NSAttributedStringKey const NSBaselineOffsetAttributeName API_AVAILABLE(macos(10.0), ios(7.0), tvos(9.0), watchos(2.0), visionos(1.0));",
            replace = "UIKIT_EXTERN NSAttributedStringKey const NSBaselineOffsetAttributeName;",
        },
    },
    {
        member = "NSUnderlineStylePatternDot",
        header = {
            name = "UIKit",
            directory = {"System", "Library", "Frameworks", "UIKit.framework", "Headers"},
            file = "NSAttributedString.h",
            find = "NSUnderlineStylePatternDot API_AVAILABLE(macos(10.0), ios(7.0), tvos(9.0), watchos(2.0), visionos(1.0))",
            replace = "NSUnderlineStylePatternDot API_AVAILABLE(macos(10.0), tvos(9.0), watchos(2.0), visionos(1.0))",
        },
    },
    {
        member = "LABiometryType",
        header = {
            name = "LocalAuthentication",
            directory = {"System", "Library", "Frameworks", "LocalAuthentication.framework", "Headers"},
            file = "LABiometryType.h",
            find = "LABiometryTypeNone API_AVAILABLE(macos(10.13.2), ios(11.2)) = kLABiometryTypeNone,",
            replace = "LABiometryTypeNone = kLABiometryTypeNone,",
        },
    },
    {
        member = "LABiometryType",
        header = {
            name = "LocalAuthentication",
            directory = {"System", "Library", "Frameworks", "LocalAuthentication.framework", "Headers"},
            file = "LABiometryType.h",
            find = "LABiometryNone API_DEPRECATED_WITH_REPLACEMENT(\"LABiometryTypeNone\", macos(10.13, 10.13.2), ios(11.0, 11.2)) = LABiometryTypeNone,",
            replace = "",
        },
    },
    {
        member = "LABiometryType",
        header = {
            name = "LocalAuthentication",
            directory = {"System", "Library", "Frameworks", "LocalAuthentication.framework", "Headers"},
            file = "LABiometryType.h",
            find = "LABiometryTypeFaceID API_AVAILABLE(macos(10.15)) = kLABiometryTypeFaceID,",
            replace = "LABiometryTypeFaceID = kLABiometryTypeFaceID,",
        },
    },
    {
        member = "LABiometryType",
        header = {
            name = "LocalAuthentication",
            directory = {"System", "Library", "Frameworks", "LocalAuthentication.framework", "Headers"},
            file = "LABiometryType.h",
            find = "LABiometryTypeOpticID API_AVAILABLE(visionos(1.0), ios(17.0), macos(14.0)) = kLABiometryTypeOpticID,",
            replace = "LABiometryTypeOpticID = kLABiometryTypeOpticID,",
        },
    },
    {
        member = "LABiometryType",
        header = {
            name = "LocalAuthentication",
            directory = {"System", "Library", "Frameworks", "LocalAuthentication.framework", "Headers"},
            file = "LABiometryType.h",
            find = "} API_AVAILABLE(macos(10.13.2), ios(11.0), watchos(11.0), tvos(18.0), visionos(1.0));",
            replace = "};",
        },
    },
    {
        member = "LAContext biometryType",
        header = {
            name = "LocalAuthentication",
            directory = {"System", "Library", "Frameworks", "LocalAuthentication.framework", "Headers"},
            file = "LAContext.h",
            find = "@property (nonatomic, readonly) LABiometryType biometryType API_AVAILABLE(macos(10.13.2), ios(11.0), watchos(11.0), tvos(18.0), visionos(1.0));",
            replace = "@property (nonatomic, readonly) LABiometryType biometryType;",
        },
    },
    {
        member = "os_unfair_lock",
        header = {
            name = "os",
            directory = {"usr", "include", "os"},
            file = "lock.h",
            find = "#define OS_UNFAIR_LOCK_AVAILABILITY \\\n\t\t__API_AVAILABLE(macos(10.12), ios(10.0), tvos(10.0), watchos(3.0))",
            replace = "#define OS_UNFAIR_LOCK_AVAILABILITY",
        },
    },
    {
        member = "os_unfair_lock",
        header = {
            name = "os",
            directory = {"usr", "include", "os"},
            file = "lock.h",
            find = "OS_OPTIONS(os_unfair_lock_flags, uint32_t,",
            replace = table.concat({
                "#if defined(__OBJC__) || defined(__cplusplus)",
                "#define REVENANT_OS_OPTIONS(_name, _type, ...) typedef enum __OS_ENUM_ATTR __OS_OPTIONS_ATTR : _type { __VA_ARGS__ } _name##_t",
                "#else",
                "#define REVENANT_OS_OPTIONS(_name, _type, ...) typedef _type _name##_t; enum _name { __VA_ARGS__ } __OS_ENUM_ATTR __OS_OPTIONS_ATTR",
                "#endif",
                "REVENANT_OS_OPTIONS(os_unfair_lock_flags, uint32_t,",
            }, "\n"),
        },
    },
    {
        member = "CLOCK_UPTIME_RAW",
        header = {
            name = "Darwin",
            directory = {"usr", "include"},
            file = "_time.h",
            find = "_CLOCK_UPTIME_RAW __CLOCK_AVAILABILITY = 8,",
            replace = "_CLOCK_UPTIME_RAW = 8,",
        },
    },
    {
        member = "clock_gettime_nsec_np",
        header = {
            name = "Darwin",
            directory = {"usr", "include"},
            file = "_time.h",
            find = "__CLOCK_AVAILABILITY\n__uint64_t clock_gettime_nsec_np(clockid_t __clock_id);",
            replace = "__uint64_t clock_gettime_nsec_np(clockid_t __clock_id) __asm(\"_revenant_clock_gettime_nsec_np\");",
        },
    },
    {
        member = "CAFrameRateRange",
        header = {
            name = "QuartzCore",
            directory = {"System", "Library", "Frameworks", "QuartzCore.framework", "Headers"},
            file = "CAFrameRateRange.h",
            find = "float preferred CF_REFINED_FOR_SWIFT;",
            replace = "float preferred;",
        },
    },
    {
        member = "CAFrameRateRange",
        header = {
            name = "QuartzCore",
            directory = {"System", "Library", "Frameworks", "QuartzCore.framework", "Headers"},
            file = "CAFrameRateRange.h",
            find = "API_AVAILABLE(macos(12.0), ios(15.0), tvos(15.0)) API_UNAVAILABLE(watchos)",
            replace = "",
        },
    },
    {
        member = "CAFrameRateRange",
        header = {
            name = "QuartzCore",
            directory = {"System", "Library", "Frameworks", "QuartzCore.framework", "Headers"},
            file = "CAFrameRateRange.h",
            find = "API_AVAILABLE(macos(12.0), ios(15.0), tvos(15.0)) API_UNAVAILABLE(watchos)",
            replace = "",
        },
    },
    {
        member = "CAFrameRateRange",
        header = {
            name = "QuartzCore",
            directory = {"System", "Library", "Frameworks", "QuartzCore.framework", "Headers"},
            file = "CAFrameRateRange.h",
            find = "API_AVAILABLE(macos(12.0), ios(15.0), tvos(15.0)) API_UNAVAILABLE(watchos)",
            replace = "",
        },
    },
    {
        member = "CAFrameRateRange",
        header = {
            name = "QuartzCore",
            directory = {"System", "Library", "Frameworks", "QuartzCore.framework", "Headers"},
            file = "CAFrameRateRange.h",
            find = "API_AVAILABLE(macos(12.0), ios(15.0), tvos(15.0)) API_UNAVAILABLE(watchos)",
            replace = "",
        },
    },
    {
        member = "CAFrameRateRange",
        header = {
            name = "QuartzCore",
            directory = {"System", "Library", "Frameworks", "QuartzCore.framework", "Headers"},
            file = "CAFrameRateRange.h",
            find = "API_AVAILABLE(macos(12.0), ios(15.0), tvos(15.0)) API_UNAVAILABLE(watchos)",
            replace = "",
        },
    },
    {
        member = "CTTelephonyNetworkInfo serviceCurrentRadioAccessTechnology",
        header = {
            name = "CoreTelephony",
            directory = {"System", "Library", "Frameworks", "CoreTelephony.framework", "Headers"},
            file = "CTTelephonyNetworkInfo.h",
            find = "serviceCurrentRadioAccessTechnology API_AVAILABLE(ios(12.0), watchos(5.0)) API_UNAVAILABLE(macos, tvos);",
            replace = "serviceCurrentRadioAccessTechnology API_UNAVAILABLE(macos, tvos);",
        },
    },
    {
        member = "Scanner",
        overlay = {
            file = {"stdlib", "public", "Darwin", "Foundation", "Scanner.swift"},
            find = "@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)\nextension Scanner {",
            replace = "extension Scanner {",
        },
    },
    {
        member = "NSJSONWritingSortedKeys",
        header = {
            name = "Foundation",
            directory = {"System", "Library", "Frameworks", "Foundation.framework", "Headers"},
            file = "NSJSONSerialization.h",
            find = "NSJSONWritingSortedKeys API_AVAILABLE(macos(10.13), ios(11.0), watchos(4.0), tvos(11.0)) = (1UL << 1),",
            replace = "NSJSONWritingSortedKeys = (1UL << 1),",
        },
        overlay = {
            file = {"stdlib", "public", "Darwin", "Foundation", "JSONEncoder.swift"},
            find = "        @available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *)\n        public static let sortedKeys    = OutputFormatting(rawValue: 1 << 1)",
            replace = "        public static let sortedKeys    = OutputFormatting(rawValue: 1 << 1)",
        },
    },
    {
        member = "kSecAccessControlPrivateKeyUsage",
        header = {
            name = "Security",
            directory = {"System", "Library", "Frameworks", "Security.framework", "Headers"},
            file = "SecAccessControl.h",
            find = "kSecAccessControlPrivateKeyUsage        API_AVAILABLE(macos(10.12.1), ios(9.0)) = 1u << 30,",
            replace = "kSecAccessControlPrivateKeyUsage        = 1u << 30,",
        },
    },
    {
        member = "WKNavigationActionPolicy",
        header = {
            name = "WebKit",
            directory = {"System", "Library", "Frameworks", "WebKit.framework", "Headers"},
            file = "WKNavigationDelegate.h",
            find = "    WKNavigationActionPolicyDownload API_AVAILABLE(macos(11.3), ios(14.5)),\n} API_AVAILABLE(macos(10.10), ios(8.0));",
            replace = "    WKNavigationActionPolicyDownload API_AVAILABLE(macos(11.3), ios(14.5)),\n};",
        },
    },
    {
        member = "WKNavigationResponsePolicy",
        header = {
            name = "WebKit",
            directory = {"System", "Library", "Frameworks", "WebKit.framework", "Headers"},
            file = "WKNavigationDelegate.h",
            find = "    WKNavigationResponsePolicyDownload API_AVAILABLE(macos(11.3), ios(14.5)),\n} API_AVAILABLE(macos(10.10), ios(8.0));",
            replace = "    WKNavigationResponsePolicyDownload API_AVAILABLE(macos(11.3), ios(14.5)),\n};",
        },
    },
    {
        member = "WKPermissionDecision",
        header = {
            name = "WebKit",
            directory = {"System", "Library", "Frameworks", "WebKit.framework", "Headers"},
            file = "WKUIDelegate.h",
            find = "    WKPermissionDecisionDeny,\n} API_AVAILABLE(macos(12.0), ios(15.0));",
            replace = "    WKPermissionDecisionDeny,\n};",
        },
    },
    {
        member = "WKMediaCaptureType",
        header = {
            name = "WebKit",
            directory = {"System", "Library", "Frameworks", "WebKit.framework", "Headers"},
            file = "WKUIDelegate.h",
            find = "    WKMediaCaptureTypeCameraAndMicrophone,\n} API_AVAILABLE(macos(12.0), ios(15.0));",
            replace = "    WKMediaCaptureTypeCameraAndMicrophone,\n};",
        },
    },
}

local MODULE_DIR = os.scriptdir()

local BOUNDARIES = {";", "*/", "}", "@end"}
local WINDOW = 8192

local function directory_of(sdk, header)
    local parts = {sdk}
    table.join2(parts, header.directory)
    return path.join(table.unpack(parts))
end

local function replaced(text, lowering, where, member)
    local start, stop = text:find(lowering.find, 1, true)
    if not start then
        raise("%s declares %s without the availability the backports lower", where, member)
    end
    return text:sub(1, start - 1) .. lowering.replace .. text:sub(stop + 1)
end

local function write_if_changed(file, text)
    if os.isfile(file) and io.readfile(file) == text then
        return
    end
    io.writefile(file, text)
end

local function selector_of(declaration)
    local text = declaration:gsub("%b()", "")
    local parts = {}
    for word in text:gmatch("([%w_]+):") do
        table.insert(parts, word .. ":")
    end
    if #parts > 0 then
        return table.concat(parts)
    end
    return text:match("^%s*[%-%+]%s*([%a_][%w_]*)")
end

function global_of(line)
    if line:match("^[%a_]") and not line:match("^static") and line:match("const[^=;(]-[%a_][%w_]*%s*=") then
        return line:match("const[^=;(]-([%a_][%w_]*)%s*=")
    end
    return nil
end

local function scan_source(file, found)
    local container, pending = nil, nil
    for line in io.readfile(file):gmatch("[^\n]*") do
        local class = line:match("^@implementation%s+REVENANT_ALIAS_CLASS%(([%w_]+)%)") or line:match("^@implementation%s+([%w_]+)")
        if class then
            container = class
            found.classes[class] = found.classes[class] or {}
        elseif line:match("^@end") then
            container = nil
        elseif container and not pending and line:match("^[%-%+]%s*%(") then
            pending = line
        elseif container and not pending and line:match("^%s*@synthesize%s+[%a_]") then
            found.classes[container]["-" .. line:match("^%s*@synthesize%s+([%a_][%w_]*)")] = true
        elseif pending then
            pending = pending .. " " .. line
        elseif not container and line:match("^[%a_]") and not line:match("^static") and not line:match("^typedef") and not line:match(";%s*$") and not line:match("^[%a_][%w_]*%s*%(") then
            local name = line:match("^[%a_][^=;(]-([%a_][%w_]*)%s*%(")
            if name then
                found.functions[name] = true
            end
        elseif not container and global_of(line) then
            found.globals[global_of(line)] = true
        end
        if pending and (pending:find("{", 1, true) or pending:find(";", 1, true)) then
            local selector = selector_of(pending)
            if container and selector then
                found.classes[container][pending:match("^%s*([%-%+])") .. selector] = true
            end
            pending = nil
        end
    end
end

local function scan_adoption(file, found)
    for line in io.readfile(file):gmatch("[^\n]*") do
        local list = line:match("^@interface%s+[%w_]+[^<]*<([^>]+)>")
        if list then
            for name in list:gmatch("[%w_]+") do
                found.protocols[name] = true
            end
        end
    end
end

local function implemented_in(src)
    local folders = {}
    for _, folder in ipairs(os.dirs(path.join(src, "*"))) do
        local found = {classes = {}, functions = {}, globals = {}, protocols = {}}
        for _, pattern in ipairs({"**.m", "**.mm", "**.c"}) do
            for _, file in ipairs(os.files(path.join(folder, pattern))) do
                scan_source(file, found)
            end
        end
        for _, pattern in ipairs({"**.m", "**.mm", "**.h"}) do
            for _, file in ipairs(os.files(path.join(folder, pattern))) do
                scan_adoption(file, found)
            end
        end
        folders[path.filename(folder)] = found
    end
    return folders
end

local function introduced_after_six(text)
    local major, minor = text:match("%f[%w_]ios%(%s*(%d+)%.?(%d*)")
    if not major then
        return false
    end
    major, minor = tonumber(major), tonumber(minor)
    return major > 6 or (major == 6 and minor ~= nil and minor > 0)
end

local function availability(text)
    local found, position = {}, 1
    while true do
        local start, stop, name = text:find("([%u_][%u%d_]*)%s*%(", position)
        if not start then
            return found
        end
        local open, close = text:find("%b()", stop)
        local available = name:find("AVAILABLE", 1, true) and not name:find("UNAVAILABLE", 1, true)
        local since = name:find("DEPRECATED", 1, true) and close and introduced_after_six(text:sub(stop, close))
        if (available or since) and open == stop then
            table.insert(found, {start = start, stop = close})
            position = close + 1
        else
            position = stop + 1
        end
    end
end

local function without_availability(text)
    local pieces, position = {}, 1
    for _, macro in ipairs(availability(text)) do
        table.insert(pieces, text:sub(position, macro.start - 1))
        position = macro.stop + 1
    end
    table.insert(pieces, text:sub(position))
    return table.concat(pieces)
end

local function directive_end(text, at)
    local stop = text:find("\n", at, true) or #text
    while stop < #text and text:sub(stop - 1, stop - 1) == "\\" do
        stop = text:find("\n", stop + 1, true) or #text
    end
    return stop
end

local function statement_start(text, at, quiet, past_directives)
    local low = math.max(1, at - WINDOW)
    local window = text:sub(low, at - 1)
    local best = nil
    for _, boundary in ipairs(BOUNDARIES) do
        local i = 1
        while true do
            local _, stop = window:find(boundary, i, true)
            if not stop then
                break
            end
            best = math.max(best or 0, low + stop)
            i = stop + 1
        end
    end
    local directive, i = nil, 1
    while true do
        local found = window:find("\n#", i, true)
        if not found then
            break
        end
        directive = found
        i = found + 1
    end
    if directive and not past_directives then
        best = math.max(best or 0, directive_end(text, low + directive) + 1)
    end
    if best then
        return best
    end
    if low > 1 then
        if quiet then
            return nil
        end
        raise("no statement boundary within %d bytes before offset %d of a header", WINDOW, at)
    end
    return 1
end

local function in_directive(text, at)
    local low = math.max(1, at - WINDOW)
    local window = text:sub(low, at - 1)
    local line = window:match(".*\n()")
    local start = line and window:sub(line) or window
    return start:match("^%s*#") ~= nil
end

local function pieces_of(text, start, stop)
    local pieces, from, at = {}, start, start
    while true do
        local mark = text:find("\n%s*#", at)
        if not mark or mark >= stop then
            break
        end
        table.insert(pieces, {from, mark - 1})
        from = directive_end(text, mark + 1) + 1
        at = from
    end
    table.insert(pieces, {from, stop})
    return pieces
end

local function statement_end(text, at)
    local _, stop = text:find(";", at, true)
    return stop or text:find("\n", at, true) or #text
end

local function trimmed_of_markers(text, start, stop, markers)
    markers = markers or {begin = {API_AVAILABLE_BEGIN = false}, ends = {API_AVAILABLE_END = true}}
    local moved = start
    for name, body in pairs(markers.begin) do
        local at = start
        while true do
            local marker_start, marker_stop = text:find("%f[%w_]" .. name .. "%f[^%w_]", at)
            if not marker_start or marker_start > stop then
                break
            end
            local last = marker_stop
            if body == false then
                local _, paren_stop = text:find("^%s*%b()", marker_stop + 1)
                last = paren_stop or marker_stop
            end
            moved = math.max(moved, last + 1)
            at = marker_stop + 1
        end
    end
    for name in pairs(markers.ends) do
        local at = start
        while true do
            local marker_start, marker_stop = text:find("%f[%w_]" .. name .. "%f[^%w_]", at)
            if not marker_start or marker_start > stop then
                break
            end
            moved = math.max(moved, marker_stop + 1)
            at = marker_stop + 1
        end
    end
    return moved, stop
end

local LITERAL_MARKERS = {begin = {API_AVAILABLE_BEGIN = false}, ends = {API_AVAILABLE_END = true}}

local function present_names(text, names)
    local words = {}
    for word in text:gmatch("[%w_]*AVAILABLE[%w_]*") do
        words[word] = true
    end
    local present = {}
    for name, body in pairs(names) do
        if words[name] then
            present[name] = body
        end
    end
    return present
end

local function earliest_marker(text, names, position, begins)
    local best = nil
    for name, body in pairs(names) do
        local at = position
        while true do
            local start, stop = text:find("%f[%w_]" .. name .. "%f[^%w_]", at)
            if not start or (best and start >= best.start) then
                break
            end
            local found = nil
            if not in_directive(text, start) then
                if not begins then
                    found = {start = start, stop = stop, text = text:sub(start, stop)}
                elseif body == false then
                    local _, paren = text:find("^%s*%b()", stop + 1)
                    if paren then
                        found = {start = start, stop = paren, text = text:sub(start, paren)}
                    end
                else
                    found = {start = start, stop = stop, text = body}
                end
            end
            if found then
                best = found
                break
            end
            at = stop + 1
        end
    end
    return best
end

local function regions_of(text, markers)
    markers = markers or LITERAL_MARKERS
    local begins, ends = present_names(text, markers.begin), present_names(text, markers.ends)
    local regions, position = {}, 1
    while true do
        local begin = earliest_marker(text, begins, position, true)
        if not begin then
            return regions
        end
        local ending = earliest_marker(text, ends, begin.stop + 1, false)
        if not ending then
            return regions
        end
        table.insert(regions, {start = begin.start, stop = begin.stop, ends_start = ending.start, ends_stop = ending.stop,
            text = begin.text, begin_text = text:sub(begin.start, begin.stop), end_text = text:sub(ending.start, ending.stop)})
        position = ending.stop + 1
    end
end

local function merged_ranges(ranges)
    table.sort(ranges, function (a, b)
        if a.start ~= b.start then
            return a.start < b.start
        end
        return a.stop < b.stop
    end)
    local merged = {}
    for _, range in ipairs(ranges) do
        local last = merged[#merged]
        if last and range.start <= last.stop and not range.remove and not last.remove then
            last.stop = math.max(last.stop, range.stop)
        else
            table.insert(merged, {start = range.start, stop = range.stop, remove = range.remove, before = range.before, after = range.after})
        end
    end
    return merged
end

local function property_getter(declaration)
    return declaration:match("getter%s*=%s*([%a_][%w_]*)")
end

local function property_sign(declaration)
    local attributes = declaration:match("%(([^)]*)%)")
    return attributes and attributes:find("%f[%w_]class%f[^%w_]") and "+" or "-"
end

local function property_name(declaration)
    local text = declaration:gsub("%b()", "")
    local name = nil
    for word in text:gmatch("[%a_][%w_]*") do
        if word ~= "property" and not word:match("^[%u%d_]+$") then
            name = word
        end
    end
    return name
end

local function statement_close(text, at)
    local depth = 0
    for position = at, #text do
        local char = text:sub(position, position)
        if char == "{" then
            depth = depth + 1
        elseif char == "}" then
            depth = depth - 1
        elseif char == ";" and depth == 0 then
            return position
        end
    end
    return #text
end

local function declared_name(declaration)
    local macro = declaration:match("^%s*typedef%s+[%u_][%w_]*%s*(%b())")
    if macro then
        local last = macro:sub(2, -2):match("([^,]*)$")
        return last:match("^%s*([%a_][%w_]*)%s*$")
    end
    local bare = (declaration:gsub("%f[%w_][%u_][%w_]*%s*%b()", " "))
    bare = (bare:gsub("%f[%w_][%u%d]+_[%u%d_]*%f[^%w_]", " "))
    return bare:match("([%a_][%w_]*)%s*;%s*$")
end

local NOT_TYPE_NAMES = {typedef = true, void = true, id = true, int = true, char = true, long = true, short = true,
    float = true, double = true, unsigned = true, signed = true, const = true, struct = true, enum = true, union = true,
    bool = true, endif = true, int8_t = true, int16_t = true, int32_t = true, int64_t = true, uint8_t = true,
    uint16_t = true, uint32_t = true, uint64_t = true}

local function typedef_declarations(text)
    local found, position = {}, 1
    while true do
        local start = text:find("%f[%w_]typedef%f[^%w_]", position)
        if not start then
            return found
        end
        local stop = statement_close(text, start)
        local statement = (text:sub(start, stop):gsub("\n%s*#[^\n]*", "\n"))
        local body = (statement:gsub("%b{}", ""))
        local name = body:match("%(%^%s*([%a_][%w_]*)%s*%)") or declared_name(without_availability(body))
        if name and (NOT_TYPE_NAMES[name] or name:find("^__")) then
            name = nil
        end
        local lead = statement_start(text, start, true) or start
        local words = {}
        for word in statement:gmatch("%f[%w_]([%a_][%w_]*)") do
            words["$" .. word] = true
        end
        table.insert(found, {start = lead, stop = stop, name = name, annotated = #availability(text:sub(lead, stop)) > 0, words = words})
        position = stop + 1
    end
end

local function apply_ranges(text, merged)
    local edits = {}
    for _, range in ipairs(merged) do
        local segment = text:sub(range.start, range.stop)
        local excerpt = (segment:sub(1, 160):gsub("\n", " "))
        if segment:find("\n%s*#") then
            raise("a backported declaration spans a preprocessor line: %s", excerpt)
        end
        local lowered
        if range.remove then
            lowered = ""
        else
            if segment:find("API_AVAILABLE_BEGIN", 1, true) then
                raise("a backported declaration spans the start of an availability region: %s", excerpt)
            end
            lowered = without_availability(segment)
            if #availability(lowered) > 0 then
                raise("an availability macro of a backported declaration cannot be lowered: %s", excerpt)
            end
            lowered = (range.before or "") .. lowered .. (range.after or "")
        end
        if lowered ~= segment then
            table.insert(edits, {start = range.start, stop = range.stop, text = lowered})
        end
    end
    for index = #edits, 1, -1 do
        local edit = edits[index]
        text = text:sub(1, edit.start - 1) .. edit.text .. text:sub(edit.stop + 1)
    end
    return text
end

local function constant_end(text, at)
    local depth = 0
    for position = at, #text do
        local char = text:sub(position, position)
        if char == "(" then
            depth = depth + 1
        elseif char == ")" then
            depth = depth - 1
        elseif depth == 0 and (char == "," or char == ";" or char == "}") then
            return position - 1
        end
    end
    return #text
end

local function class_spans(text)
    local spans = {}
    for position in text:gmatch("()@interface%f[^%w_]") do
        table.insert(spans, {start = position, stop = text:find("@end", position, true) or #text})
    end
    for position in text:gmatch("()@protocol%f[^%w_]") do
        if not text:match("^[^;\n]*;", position) then
            table.insert(spans, {start = position, stop = text:find("@end", position, true) or #text})
        end
    end
    return spans
end

local function overlaps_any(range, spans)
    for _, span in ipairs(spans) do
        if range.start <= span.stop and range.stop >= span.start then
            return true
        end
    end
    return false
end

local function matching_brace(text, open)
    local depth = 0
    for position = open, #text do
        local char = text:sub(position, position)
        if char == "{" then
            depth = depth + 1
        elseif char == "}" then
            depth = depth - 1
            if depth == 0 then
                return position
            end
        end
    end
    return #text
end

local function blank(text)
    return (text:gsub("[^\n]", " "))
end

local function enum_body_at(text, at)
    local start, position = nil, 1
    while true do
        local keyword = text:find("%f[%w_]typedef%f[^%w_]", position)
        if not keyword or keyword > at then
            break
        end
        start = keyword
        position = keyword + 1
    end
    if not start then
        return nil
    end
    local stop = statement_close(text, start)
    local open = text:find("{", start, true)
    if not open or open > stop or at < open then
        return nil
    end
    local close = matching_brace(text, open)
    if at > close then
        return nil
    end
    local head = text:sub(start, open - 1):gsub("%s+", " ")
    if not (head:find("NS_[%u_]*ENUM") or head:find("NS_OPTIONS") or head:find("%f[%w_]enum%f[^%w_]")) then
        raise("a backported declaration sits in the body of %s, which an availability region spans: the region cannot be split inside it", head)
    end
    return {start = start, stop = stop, open = open, close = close}
end

local function covered_by_lowered(ranges, body)
    for _, range in ipairs(ranges) do
        if not range.remove and range.start <= body.start and range.stop >= body.stop then
            return true
        end
    end
    return false
end

local function enumerators_in(text, body)
    local masked = text:sub(body.open + 1, body.close - 1)
    masked = masked:gsub("//[^\n]*", blank):gsub("/%*.-%*/", blank):gsub("\n%s*#[^\n]*", blank)
    local found = {}
    for at, name in masked:gmatch("()([%a_][%w_]*)") do
        local before = masked:sub(1, at - 1)
        local previous = before:match("(%S)%s*$")
        local _, opened = before:gsub("{", "")
        local _, closed = before:gsub("}", "")
        local _, open_parens = before:gsub("%(", "")
        local _, close_parens = before:gsub("%)", "")
        if opened == closed and open_parens == close_parens and (previous == nil or previous == ",") then
            table.insert(found, {name = name, start = body.open + at})
        end
    end
    return found
end

local function adopts_lowered_protocol(text, stop, implemented)
    local line = text:sub(stop + 1, text:find("\n", stop, true) or #text)
    for word in line:gmatch("[%a_][%w_]*") do
        for _ in pairs((implemented.protocol_members or {})[word] or {}) do
            return true
        end
    end
    return false
end

local function comment_spans(text)
    local spans, at = {}, 1
    while true do
        local start = text:find("/[/*]", at)
        if not start then
            return spans
        end
        local stop
        if text:sub(start + 1, start + 1) == "/" then
            stop = (text:find("\n", start, true) or #text + 1) - 1
        else
            local _, close = text:find("*/", start + 2, true)
            stop = close or #text
        end
        table.insert(spans, {start, stop})
        at = stop + 1
    end
end

local function in_comment(spans, at)
    for _, span in ipairs(spans) do
        if at >= span[1] and at <= span[2] then
            return true
        end
    end
    return false
end

local function find_outside_comments(text, pattern, position, spans)
    while true do
        local start, stop = text:find(pattern, position)
        if not start or not in_comment(spans, start) then
            return start, stop
        end
        position = start + 1
    end
end

local function lowering_of(text, implemented, declarations)
    local words, hits = {}, {}
    local spans = comment_spans(text)
    local globals, functions = implemented.globals or {}, implemented.functions or {}
    for position, word in text:gmatch("()([%a_][%w_]*)") do
        words[word] = true
        if globals[word] then
            table.insert(hits, {position = position, word = word, kind = "global"})
        end
        if functions[word] then
            table.insert(hits, {position = position, word = word, kind = "function"})
        end
    end
    local ranges = {}
    local markers = implemented.markers
    local function lower(start, stop, remove)
        if not remove then
            start, stop = trimmed_of_markers(text, start, stop, markers)
        end
        if stop >= start then
            table.insert(ranges, {start = start, stop = stop, remove = remove})
        end
    end
    for position, class in text:gmatch("()@interface%s+([%w_]+)") do
        local members = implemented.classes[class]
        if members and not in_comment(spans, position) then
            local _, stop = text:find("@interface%s+" .. class .. "%f[^%w_]", position)
            local first = statement_start(text, position, true, true)
            local category = text:match("^%s*%(", stop + 1) ~= nil
            if first and (not category or adopts_lowered_protocol(text, stop, implemented)) and not (implemented.weak_classes and implemented.weak_classes[class]) then
                for _, piece in ipairs(pieces_of(text, first, text:find("\n", stop, true) or #text)) do
                    lower(piece[1], piece[2])
                end
            end
            local block_end = text:find("@end", stop, true) or #text
            local at = stop
            while true do
                local mark = text:find("\n[%-%+]%s*%(", at)
                if not mark or mark > block_end then
                    break
                end
                local declared_end = statement_end(text, mark + 1)
                local declaration = text:sub(mark + 1, declared_end)
                local selector = selector_of(declaration)
                if selector and members[declaration:match("^([%-%+])") .. selector] then
                    for _, piece in ipairs(pieces_of(text, mark + 1, declared_end)) do
                        lower(piece[1], piece[2])
                    end
                end
                at = mark + 1
            end
        end
    end
    for position, class in text:gmatch("()@interface%s+([%w_]+)") do
        local members = implemented.classes[class]
        if members and not in_comment(spans, position) then
            local _, stop = text:find("@interface%s+" .. class .. "%f[^%w_]", position)
            local block_end = text:find("@end", stop, true) or #text
            local at = stop
            while true do
                local mark = text:find("\n@property", at, true)
                if not mark or mark > block_end then
                    break
                end
                local declared_end = statement_end(text, mark + 1)
                local declaration = text:sub(mark + 1, declared_end)
                local name = property_name(declaration)
                local getter = property_getter(declaration) or name
                local sign = property_sign(declaration)
                if name and (members[sign .. getter] or members[sign .. name] or members["-set" .. name:sub(1, 1):upper() .. name:sub(2) .. ":"]) then
                    for _, piece in ipairs(pieces_of(text, mark + 1, declared_end)) do
                        lower(piece[1], piece[2])
                    end
                end
                at = mark + 1
            end
        end
    end
    for name in pairs(implemented.protocols or {}) do
        local position = words[name] and 1 or #text + 1
        while true do
            local start, stop = find_outside_comments(text, "@protocol%s+" .. name .. "[%s<]", position, spans)
            if not start then
                break
            end
            local block_end = text:find("@end", stop, true) or #text
            local first = statement_start(text, start, true, true)
            if first then
                for _, piece in ipairs(pieces_of(text, first, text:find("\n", stop, true) or #text)) do
                    lower(piece[1], piece[2])
                end
            end
            local members = (implemented.protocol_members or {})[name] or {}
            local at = stop
            while true do
                local mark = text:find("\n[%-%+]%s*%(", at)
                if not mark or mark > block_end then
                    break
                end
                local declared_end = statement_end(text, mark + 1)
                local declaration = text:sub(mark + 1, declared_end)
                local selector = selector_of(declaration)
                if selector and members[declaration:match("^([%-%+])") .. selector] then
                    for _, piece in ipairs(pieces_of(text, mark + 1, declared_end)) do
                        lower(piece[1], piece[2])
                    end
                end
                at = mark + 1
            end
            at = stop
            while true do
                local mark = text:find("\n@property", at, true)
                if not mark or mark > block_end then
                    break
                end
                local declared_end = statement_end(text, mark + 1)
                local declaration = text:sub(mark + 1, declared_end)
                local property = property_name(declaration)
                local getter = property_getter(declaration) or property
                local sign = property_sign(declaration)
                if property and (members[sign .. getter] or members[sign .. property]) then
                    for _, piece in ipairs(pieces_of(text, mark + 1, declared_end)) do
                        lower(piece[1], piece[2])
                    end
                end
                at = mark + 1
            end
            position = block_end + 1
        end
    end
    for _, hit in ipairs(hits) do
        if hit.kind == "global" then
            local start, stop = hit.position, hit.position + #hit.word - 1
            local first = statement_start(text, start, true)
            if first then
                first = trimmed_of_markers(text, first, start, markers)
            end
            local last = first and statement_end(text, stop)
            local segment = first and text:sub(first, last) or ""
            if first and not segment:find("\n%s*#") and not segment:find("{", 1, true) and not segment:find("API_AVAILABLE_BEGIN", 1, true) then
                lower(first, last)
            elseif text:match("^%s*API_AVAILABLE%(", stop + 1) or text:match("^%s*=", stop + 1) then
                local ending = constant_end(text, start)
                if not text:sub(start, ending):find("\n%s*#") then
                    lower(start, ending)
                end
            end
        elseif text:find("^%s*%(", hit.position + #hit.word) and not in_directive(text, hit.position) then
            local start = statement_start(text, hit.position, true)
            local stop = statement_end(text, hit.position)
            local segment = start and text:sub(start, stop) or ""
            if start and not segment:find("\n%s*#") and not segment:find("{", 1, true) then
                lower(start, stop)
            end
        end
    end
    if implemented.types then
        for _, declaration in ipairs(declarations or typedef_declarations(text)) do
            if declaration.annotated and declaration.name and implemented.types[declaration.name] then
                for _, piece in ipairs(pieces_of(text, declaration.start, declaration.stop)) do
                    lower(piece[1], piece[2])
                end
            end
        end
    end
    local spans, splits = nil, {}
    for _, region in ipairs(regions_of(text, implemented.markers)) do
        if ios_later(region.text) then
            spans = spans or class_spans(text)
            local inside, whole = {}, false
            for _, range in ipairs(ranges) do
                if not range.remove and range.start > region.stop and range.stop < region.ends_start then
                    if overlaps_any(range, spans) then
                        whole = true
                    end
                    table.insert(inside, range)
                end
            end
            if whole then
                lower(region.start, region.stop, true)
                lower(region.ends_start, region.ends_stop, true)
            else
                local bodies = {}
                for _, range in ipairs(inside) do
                    local body = enum_body_at(text, range.start)
                    if body then
                        if not covered_by_lowered(ranges, body) then
                            bodies[body.start] = body
                        end
                    else
                        range.before = "\n" .. region.end_text .. "\n"
                        range.after = "\n" .. region.begin_text .. "\n"
                    end
                end
                for _, body in pairs(bodies) do
                    if body.start <= region.stop or body.stop >= region.ends_start then
                        raise("an availability region starts or ends inside the enum body at offset %d: the region cannot be split there", body.start)
                    end
                    local gate = region.text:match("%b()")
                    if not gate then
                        raise("the availability region %s has no arguments", region.text)
                    end
                    table.insert(splits, {start = body.start, stop = body.start - 1, before = "\n" .. region.end_text .. "\n"})
                    table.insert(splits, {start = body.stop + 1, stop = body.stop, after = "\n" .. region.begin_text .. "\n"})
                    for _, enumerator in ipairs(enumerators_in(text, body)) do
                        local backported = false
                        for _, range in ipairs(inside) do
                            if enumerator.start >= range.start and enumerator.start <= range.stop then
                                backported = true
                            end
                        end
                        if not backported and #availability(text:sub(enumerator.start, constant_end(text, enumerator.start))) == 0 then
                            local at = enumerator.start + #enumerator.name
                            table.insert(splits, {start = at, stop = at - 1, before = " API_AVAILABLE" .. gate})
                        end
                    end
                end
            end
        end
    end
    for _, split in ipairs(splits) do
        table.insert(ranges, split)
    end
    local merged = merged_ranges(ranges)
    local uses = {}
    for _, range in ipairs(merged) do
        for word in text:sub(range.start, range.stop):gmatch("%f[%w_]([%a_][%w_]*)") do
            uses["$" .. word] = true
        end
    end
    return apply_ranges(text, merged), uses
end

function lower_header(text, implemented)
    return (lowering_of(text, implemented))
end

local function union_of(folders)
    local union = {classes = {}, functions = {}, globals = {}, protocols = {}}
    for _, found in pairs(folders) do
        for name in pairs(found.protocols) do
            union.protocols[name] = true
        end
        for class, members in pairs(found.classes) do
            union.classes[class] = union.classes[class] or {}
            for member in pairs(members) do
                union.classes[class][member] = true
            end
        end
        for name in pairs(found.functions) do
            union.functions[name] = true
        end
        for name in pairs(found.globals) do
            union.globals[name] = true
        end
    end
    return union
end

local corpora = {}

local function corpus_of(src)
    if not corpora[src] then
        local parts = {}
        for _, folder in ipairs(os.dirs(path.join(src, "*"))) do
            for _, pattern in ipairs({"**.m", "**.mm", "**.h", "**.c"}) do
                for _, file in ipairs(os.files(path.join(folder, pattern))) do
                    table.insert(parts, io.readfile(file))
                end
            end
        end
        corpora[src] = table.concat(parts, "\n")
    end
    return corpora[src]
end

local function method_keys(block)
    local keys, at = {}, 1
    while true do
        local mark = block:find("\n[%-%+]%s*%(", at)
        if not mark then
            break
        end
        local _, stop = block:find(";", mark + 1, true)
        local declaration = block:sub(mark + 1, stop or #block)
        local selector = selector_of(declaration)
        if selector then
            table.insert(keys, {key = declaration:match("^([%-%+])") .. selector, selector = selector})
        end
        at = mark + 1
    end
    at = 1
    while true do
        local mark = block:find("\n@property", at, true)
        if not mark then
            return keys
        end
        local declaration = block:sub(mark + 1, statement_end(block, mark + 1))
        local name = property_name(declaration)
        if name then
            local getter = property_getter(declaration) or name
            table.insert(keys, {key = property_sign(declaration) .. getter, selector = getter})
        end
        at = mark + 1
    end
end

local function protocol_blocks(sdk, names)
    local blocks = {}
    for _, framework in ipairs(os.dirs(path.join(sdk, "System", "Library", "Frameworks", "*.framework"))) do
        for _, file in ipairs(os.files(path.join(framework, "Headers", "*.h"))) do
            local text = io.readfile(file)
            local position = text:find("@protocol", 1, true)
            while position do
                local name = text:match("^@protocol%s+([%w_]+)[%s<]", position)
                if name and names[name] and not blocks[name] then
                    blocks[name] = text:sub(position, text:find("@end", position, true) or #text)
                end
                position = text:find("@protocol", position + 1, true)
            end
        end
    end
    return blocks
end

local function add_to(map, key, value)
    map[key] = map[key] or {}
    map[key][value] = true
end

local function protocol_names(text, at)
    local window = text:sub(at, at + 800)
    local open = window:find("<", 1, true)
    if not open or window:sub(1, open - 1):find("[{;@]") then
        return {}
    end
    local names = {}
    for name in window:sub(open + 1, (window:find(">", open, true) or #window + 1) - 1):gmatch("[%w_]+") do
        table.insert(names, name)
    end
    return names
end

local function declarations_in(text, conformance)
    for at in text:gmatch("()@interface%s") do
        local window = text:sub(at, at + 300)
        local class, after = window:match("^@interface%s+([%w_]+)%s*%(%s*[%w_]*%s*%)()")
        if class then
            for _, name in ipairs(protocol_names(text, at + after - 1)) do
                add_to(conformance.direct, class, name)
            end
        else
            local head, super
            head, super, after = window:match("^@interface%s+([%w_]+)%s*<?[^:{;@]*:%s*([%w_]+)()")
            if head then
                conformance.supers[head] = super
                for _, name in ipairs(protocol_names(text, at + after - 1)) do
                    add_to(conformance.direct, head, name)
                end
            end
        end
    end
    for at in text:gmatch("()@protocol%s") do
        local name, after = text:match("^@protocol%s+([%w_]+)()", at)
        if name then
            for _, parent in ipairs(protocol_names(text, after)) do
                add_to(conformance.parents, name, parent)
            end
        end
    end
end

local function conformance_of(sdk, src)
    local conformance = {supers = {}, direct = {}, parents = {}}
    for _, framework in ipairs(os.dirs(path.join(sdk, "System", "Library", "Frameworks", "*.framework"))) do
        for _, file in ipairs(os.files(path.join(framework, "Headers", "*.h"))) do
            declarations_in(io.readfile(file), conformance)
        end
    end
    for _, folder in ipairs(os.dirs(path.join(src, "*"))) do
        for _, pattern in ipairs({"**.h", "**.m", "**.mm"}) do
            for _, file in ipairs(os.files(path.join(folder, pattern))) do
                declarations_in(io.readfile(file), conformance)
            end
        end
    end
    return conformance
end

local function protocols_of(conformance, class)
    local names, found, seen = {}, {}, {}
    local current = class
    while current and not seen[current] do
        seen[current] = true
        for name in pairs(conformance.direct[current] or {}) do
            table.insert(names, name)
        end
        current = conformance.supers[current]
    end
    while #names > 0 do
        local name = table.remove(names)
        if not found[name] then
            found[name] = true
            for parent in pairs(conformance.parents[name] or {}) do
                table.insert(names, parent)
            end
        end
    end
    return found
end

local function covered_of(conformance)
    local covered, classes = {}, {}
    for class in pairs(conformance.direct) do
        classes[class] = true
    end
    for class in pairs(conformance.supers) do
        classes[class] = true
    end
    for class in pairs(classes) do
        local ancestors, current = {}, class
        while current and not ancestors[current] do
            ancestors[current] = true
            current = conformance.supers[current]
        end
        for name in pairs(protocols_of(conformance, class)) do
            covered[name] = covered[name] or {}
            for ancestor in pairs(ancestors) do
                covered[name][ancestor] = true
            end
        end
    end
    return covered
end

function protocol_status(src, sdk, folders)
    folders = folders or implemented_in(src)
    local adopted = {}
    for _, found in pairs(folders) do
        for name in pairs(found.protocols) do
            adopted[name] = true
        end
    end
    local corpus = corpus_of(src)
    local typed = {}
    for name in corpus:gmatch("id%s*<%s*([%w_]+)%s*>") do
        typed[name] = true
    end
    local defined = {}
    for name in corpus:gmatch("\n@protocol%s+([%w_]+)[%s<]") do
        defined[name] = true
    end
    local candidates = {}
    for name in pairs(adopted) do
        candidates[name] = true
    end
    for name in pairs(typed) do
        candidates[name] = true
    end
    for name in pairs(defined) do
        candidates[name] = true
    end
    local blocks = protocol_blocks(sdk, candidates)
    local methods = {}
    for name in pairs(candidates) do
        methods[name] = blocks[name] and method_keys(blocks[name]) or {}
    end
    local implementers = {}
    for _, found in pairs(folders) do
        for class, class_members in pairs(found.classes) do
            for key in pairs(class_members) do
                add_to(implementers, key, class)
            end
        end
    end
    local covered = covered_of(conformance_of(sdk, src))
    local status = {backed = {}, uncalled = {}, members = {}}
    for name in pairs(candidates) do
        local members, implements = {}, false
        for _, method in ipairs(methods[name]) do
            for class in pairs(implementers[method.key] or {}) do
                if covered[name] and covered[name][class] then
                    members[method.key] = true
                    implements = true
                    break
                end
            end
        end
        status.members[name] = members
        if adopted[name] or defined[name] or implements then
            status.backed[name] = true
        elseif typed[name] and blocks[name] then
            status.uncalled[name] = true
        end
    end
    return status
end

local built = {}

function members_file()
    return path.absolute(path.join(MODULE_DIR, "..", "..", "..", "frameworks", "Backports", "tools", "lowered-members.txt"))
end

local MEMBERS_HEADER = table.concat({
    "# The lowered API set of frameworks/Backports/src: the members, protocols and signature types the lowering reads.",
    "# Generated by frameworks/Backports/tools/lowered_members.lua; do not edit. The test",
    "# frameworks/Backports/tests/lowered_members_test.lua fails when this file no longer matches the sources.",
}, "\n") .. "\n"

function serialize(set, header)
    local lines = {}
    for class, members in pairs(set.classes) do
        table.insert(lines, "class " .. class)
        for key in pairs(members) do
            table.insert(lines, "member " .. class .. " " .. key)
        end
    end
    for name in pairs(set.functions) do
        table.insert(lines, "function " .. name)
    end
    for name in pairs(set.globals) do
        table.insert(lines, ((set.enums or {})[name] and "enum " or "global ") .. name)
    end
    for name in pairs(set.protocols) do
        table.insert(lines, "protocol " .. name)
        for key in pairs((set.protocol_members or {})[name] or {}) do
            table.insert(lines, "protocol_member " .. name .. " " .. key)
        end
    end
    for name in pairs(set.types or {}) do
        table.insert(lines, "type " .. name)
    end
    byteorder.sort(lines)
    return (header or MEMBERS_HEADER) .. table.concat(lines, "\n") .. "\n"
end

function parse(text)
    local set = {classes = {}, functions = {}, globals = {}, enums = {}, protocols = {}, protocol_members = {}, types = {}}
    for line in text:gmatch("[^\n]+") do
        if not line:find("^#") then
            local kind, first, second = line:match("^(%S+) (%S+) ?(%S*)$")
            if kind == "class" then
                set.classes[first] = set.classes[first] or {}
            elseif kind == "member" then
                set.classes[first] = set.classes[first] or {}
                set.classes[first][second] = true
            elseif kind == "function" then
                set.functions[first] = true
            elseif kind == "global" then
                set.globals[first] = true
            elseif kind == "enum" then
                set.globals[first] = true
                set.enums[first] = true
            elseif kind == "protocol" then
                set.protocols[first] = true
                set.protocol_members[first] = set.protocol_members[first] or {}
            elseif kind == "protocol_member" then
                set.protocol_members[first] = set.protocol_members[first] or {}
                set.protocol_members[first][second] = true
            elseif kind == "type" then
                set.types[first] = true
            else
                raise("the lowered member list has an unknown line: %s", line)
            end
        end
    end
    return set
end

function read_members(file)
    return parse(io.readfile(file or members_file()))
end

local function frameworks_in(folder, found)
    for _, framework in ipairs(os.dirs(path.join(folder, "*.framework"))) do
        table.insert(found, framework)
        frameworks_in(path.join(framework, "Frameworks"), found)
    end
    return found
end

local function framework_headers(sdk)
    local files = {}
    local frameworks = frameworks_in(path.join(sdk, "System", "Library", "Frameworks"), {})
    frameworks_in(path.join(sdk, "System", "Library", "SubFrameworks"), frameworks)
    for _, framework in ipairs(frameworks) do
        for _, file in ipairs(os.files(path.join(framework, "Headers", "*.h"))) do
            table.insert(files, file)
        end
    end
    return files
end

local markers_cache = {}

function region_markers(sdk)
    if markers_cache[sdk] then
        return markers_cache[sdk]
    end
    local markers = {begin = {API_AVAILABLE_BEGIN = false}, ends = {API_AVAILABLE_END = true}}
    for _, file in ipairs(framework_headers(sdk)) do
        local text = io.readfile(file)
        if text:find("API_AVAILABLE_", 1, true) then
            for name, body in text:gmatch("#%s*define%s+([%w_]+)%s+(API_AVAILABLE_BEGIN%b())") do
                markers.begin[name] = body
            end
            for name in text:gmatch("#%s*define%s+([%w_]+)%s+API_AVAILABLE_END%f[^%w_]") do
                markers.ends[name] = true
            end
        end
    end
    markers_cache[sdk] = markers
    return markers
end

local function member_headers(sdk)
    local changed = {}
    for _, entry in ipairs(MEMBERS) do
        local header = entry.header
        if header then
            local file = path.join(directory_of(sdk, header), header.file)
            changed[file] = replaced(changed[file] or io.readfile(file), header, "the iPhoneOS SDK at " .. sdk .. " in " .. header.file, entry.member)
        end
    end
    return changed
end

local function names_of(set)
    local names = {classes = set.classes or {}, protocols = set.protocols or {}, words = {}}
    for _, field in ipairs({"globals", "functions", "types"}) do
        for name in pairs(set[field] or {}) do
            names.words[name] = true
        end
    end
    return names
end

local function mentions(text, names)
    for class in text:gmatch("@interface%s+([%w_]+)") do
        if names.classes[class] then
            return true
        end
    end
    for protocol in text:gmatch("@protocol%s+([%w_]+)") do
        if names.protocols[protocol] then
            return true
        end
    end
    for word in text:gmatch("[%a_][%w_]*") do
        if names.words[word] then
            return true
        end
    end
    return false
end

local function lowered_types(sdk, set)
    local changed = member_headers(sdk)
    local declared, queue, queued = {}, {}, {}
    local function enqueue(name)
        if not queued["$" .. name] then
            queued["$" .. name] = true
            table.insert(queue, name)
        end
    end
    local names = names_of(set)
    for _, file in ipairs(framework_headers(sdk)) do
        local text = changed[file] or io.readfile(file)
        local declarations = typedef_declarations(text)
        if mentions(text, names) then
            local _, used = lowering_of(text, set, declarations)
            for key in pairs(used) do
                enqueue(key:sub(2))
            end
        end
        for _, declaration in ipairs(declarations) do
            if declaration.name then
                declared[declaration.name] = declared[declaration.name] or {}
                table.insert(declared[declaration.name], declaration)
            end
        end
    end
    local types, visited = {}, {}
    while #queue > 0 do
        local name = table.remove(queue)
        if declared[name] and not visited[name] then
            visited[name] = true
            for _, declaration in ipairs(declared[name]) do
                if declaration.annotated then
                    types[name] = true
                end
                for key in pairs(declaration.words) do
                    enqueue(key:sub(2))
                end
            end
        end
    end
    return types
end

local function identifiers_in(src)
    local used = {}
    for _, folder in ipairs(os.dirs(path.join(src, "*"))) do
        for _, pattern in ipairs({"**.m", "**.mm", "**.c", "**.h"}) do
            for _, file in ipairs(os.files(path.join(folder, pattern))) do
                for word in io.readfile(file):gmatch("[%a_][%w_]*") do
                    used[word] = true
                end
            end
        end
    end
    return used
end

function members_of(src, sdk, intros)
    local folders = implemented_in(src)
    local set = union_of(folders)
    local used = identifiers_in(src)
    local defined = constants_defined_in(src)
    set.enums = {}
    for name, found in pairs(intros or {}) do
        local later = found.intro ~= nil and found.intro > 6000
        if later and found.kind == "enum" and used[name] then
            set.globals[name] = true
            set.enums[name] = true
        elseif later and found.kind == "extern" and defined[name] then
            set.globals[name] = true
        end
    end
    local status = protocol_status(src, sdk, folders)
    set.protocols = status.backed
    set.protocol_members = {}
    for name in pairs(status.backed) do
        set.protocol_members[name] = status.members[name]
    end
    set.types = lowered_types(sdk, merge_sets(set, read_device_members()))
    return set
end

local DEVICE_RELEASE = "6.0"

local DEVICE_HEADER = table.concat({
    "# The members the iOS 6.0 release implements and the SDK annotates later, from that release's dyld cache inventory.",
    "# Generated by frameworks/Backports/tools/device_members.lua; do not edit. The test",
    "# frameworks/Backports/tests/device_members_test.lua checks this file against the inventory where the inventory is present.",
}, "\n") .. "\n"

function inventory_file()
    return path.join(workspace.home(), "dyld", DEVICE_RELEASE, "classes_armv7.json")
end

function device_members_file()
    return path.absolute(path.join(MODULE_DIR, "..", "..", "..", "frameworks", "Backports", "tools", "device-members.txt"))
end

function device_text(set)
    return serialize(set, DEVICE_HEADER)
end

function read_device_members(file)
    return parse(io.readfile(file or device_members_file()))
end

function merge_sets(a, b)
    local out = {classes = {}, functions = {}, globals = {}, protocols = {}, protocol_members = {}, types = {}}
    for _, set in ipairs({a, b}) do
        for class, members in pairs(set.classes or {}) do
            out.classes[class] = out.classes[class] or {}
            for key in pairs(members) do
                out.classes[class][key] = true
            end
        end
        for name in pairs(set.functions or {}) do
            out.functions[name] = true
        end
        for name in pairs(set.globals or {}) do
            out.globals[name] = true
        end
        for name in pairs(set.protocols or {}) do
            out.protocols[name] = true
        end
        for name, members in pairs(set.protocol_members or {}) do
            out.protocol_members[name] = out.protocol_members[name] or {}
            for key in pairs(members) do
                out.protocol_members[name][key] = true
            end
        end
        for name in pairs(set.types or {}) do
            out.types[name] = true
        end
    end
    return out
end

function read_all_members()
    local set = merge_sets(read_members(), read_device_members())
    set.weak_classes = {}
    for _, name in ipairs(flat_classes.weak_class_names()) do
        set.weak_classes[name] = true
    end
    for _, rows in pairs(runtime_guards.guards()) do
        for symbol in pairs(rows) do
            local class = symbol:match("^_OBJC_CLASS_%$_(.+)$")
            if class then
                if not flat_classes.is_exported(class) then
                    set.weak_classes[class] = true
                end
            elseif not symbol:find("^_OBJC_") then
                set.globals[symbol:sub(2)] = nil
                set.functions[symbol:sub(2)] = nil
            end
        end
    end
    return set
end

function ios_later(text)
    local major, minor = nil, nil
    for found_major, found_minor in text:gmatch("%f[%w_]ios%(%s*(%d+)%.?(%d*)") do
        major, minor = tonumber(found_major), tonumber(found_minor) or 0
    end
    for found_major, found_minor in text:gmatch("__IPHONE_(%d+)_(%d+)") do
        major, minor = tonumber(found_major), tonumber(found_minor)
    end
    return major ~= nil and (major > 6 or (major == 6 and minor > 0))
end

local function digest_of(base, files)
    local parts = {}
    for _, file in ipairs(files) do
        table.insert(parts, path.relative(file, base) .. "=" .. hash.sha256(file))
    end
    return hash.strhash128(table.concat(parts, "\n"))
end

local function generator_files()
    return {path.join(MODULE_DIR, "lowered.lua"), path.join(MODULE_DIR, "runtime_guards.lua"), path.join(MODULE_DIR, "flat_classes.lua")}
end

local function members_key(src, sdk)
    local sdk_files = table.join(framework_headers(sdk))
    for _, entry in ipairs(MEMBERS) do
        if entry.header then
            table.insert(sdk_files, path.join(directory_of(sdk, entry.header), entry.header.file))
        end
    end
    byteorder.sort(sdk_files)
    local src_files = os.files(path.join(src, "**"))
    byteorder.sort(src_files)
    local shared = {path.join(MODULE_DIR, "..", "byteorder.lua"), path.join(MODULE_DIR, "..", "workspace.lua")}
    local tools = {path.join(src, "..", "tools", "facts.lua"), path.join(src, "..", "tools", "ast.lua"), path.join(src, "..", "tools", "sdk.lua")}
    return hash.strhash128(table.concat({
        "generator=" .. digest_of(MODULE_DIR, generator_files()),
        "shared=" .. digest_of(path.join(MODULE_DIR, ".."), shared),
        "tools=" .. digest_of(path.join(src, ".."), tools),
        "device=" .. hash.sha256(device_members_file()),
        "src=" .. digest_of(src, src_files),
        "sdk=" .. digest_of(sdk, sdk_files),
    }, "\n"))
end

function members_text(src, sdk, intros)
    local folder = path.join(workspace.scratch(), "lowered-members")
    local final = path.join(folder, members_key(src, sdk) .. ".txt")
    local cached = os.isfile(final) and try {function () return io.readfile(final) end}
    if cached then
        return cached
    end
    local text = serialize(members_of(src, sdk, intros))
    os.mkdir(folder)
    for _, stale in ipairs(os.files(path.join(folder, "*.txt"))) do
        os.tryrm(stale)
    end
    local partial = final .. "." .. tostring(os.time()) .. ".partial"
    io.writefile(partial, text)
    os.mv(partial, final)
    return text
end

function constants_defined_in(src)
    local defined = {}
    for _, folder in ipairs(os.dirs(path.join(src, "*"))) do
        for _, pattern in ipairs({"**.m", "**.mm", "**.c", "**.h"}) do
            for _, file in ipairs(os.files(path.join(folder, pattern))) do
                for line in io.readfile(file):gmatch("[^\n]*") do
                    local name = line:match("const%s+[%w_%*]+%s+([%a_][%w_]*)%s*=") or line:match("const%s+([%a_][%w_]*)%s*=")
                        or line:match("const%s+[%w_]+%s*%*%s*([%a_][%w_]*)%s*=")
                        or line:match("^[%a_][%w_]*%s*%*%s*([%a_][%w_]*)%s*[;=]")
                    if name then
                        defined[name] = true
                    end
                end
            end
        end
    end
    return defined
end

local function released_keys(released, class, cache)
    if cache[class] == nil then
        local info = released[class]
        if info then
            local keys = {}
            for _, selector in ipairs(info.instance or {}) do
                keys["-" .. selector] = true
            end
            for _, selector in ipairs(info["class"] or {}) do
                keys["+" .. selector] = true
            end
            cache[class] = keys
        else
            cache[class] = false
        end
    end
    return cache[class]
end

function device_members_in(text, released, cache)
    local set = {classes = {}, functions = {}, globals = {}, protocols = {}, protocol_members = {}, types = {}}
    for position, class in text:gmatch("()@interface%s+([%w_]+)[%s:<]") do
        local keys = released_keys(released, class, cache)
        if keys then
            local _, stop = text:find("@interface%s+" .. class .. "%f[^%w_]", position)
            local block_end = text:find("@end", stop, true) or #text
            local lead = statement_start(text, position, true) or position
            if ios_later(text:sub(lead, text:find("\n", stop, true) or #text)) then
                set.classes[class] = set.classes[class] or {}
            end
            local at = stop
            while true do
                local mark = text:find("\n[%-%+]%s*%(", at)
                if not mark or mark > block_end then
                    break
                end
                local declared_end = statement_end(text, mark + 1)
                local declaration = text:sub(mark + 1, declared_end)
                local selector = selector_of(declaration)
                if selector and ios_later(declaration) then
                    local key = declaration:match("^([%-%+])") .. selector
                    if keys[key] then
                        set.classes[class] = set.classes[class] or {}
                        set.classes[class][key] = true
                    end
                end
                at = mark + 1
            end
            at = stop
            while true do
                local mark = text:find("\n@property", at, true)
                if not mark or mark > block_end then
                    break
                end
                local declared_end = statement_end(text, mark + 1)
                local declaration = text:sub(mark + 1, declared_end)
                local name = property_name(declaration)
                if name and ios_later(declaration) then
                    local setter = "-set" .. name:sub(1, 1):upper() .. name:sub(2) .. ":"
                    local getter = property_getter(declaration) or name
                    for _, key in ipairs({"-" .. getter, "-" .. name, setter}) do
                        if keys[key] then
                            set.classes[class] = set.classes[class] or {}
                            set.classes[class][key] = true
                        end
                    end
                end
                at = mark + 1
            end
        end
    end
    return set
end

function device_members_of(sdk, inventory)
    local released = json.decode(io.readfile(inventory)).classes
    local cache = {}
    local merged = {classes = {}, functions = {}, globals = {}, protocols = {}, protocol_members = {}, types = {}}
    for _, file in ipairs(framework_headers(sdk)) do
        local found = device_members_in(io.readfile(file), released, cache)
        for class, members in pairs(found.classes) do
            merged.classes[class] = merged.classes[class] or {}
            for key in pairs(members) do
                merged.classes[class][key] = true
            end
        end
    end
    return merged
end

local function input_digest(sdk, text)
    return hash.strhash128(table.concat({sdk, digest_of(MODULE_DIR, generator_files()), text}, "\0"))
end

THIRD_PARTY_MODULES = {
    AsyncDisplayKit = {["ASDisplayNode.h"] = {"ASGestureRecognizerDelegate", "ASScrollViewDelegate"}},
}

local function consulted_selectors()
    local found = {}
    local src = path.absolute(path.join(path.directory(members_file()), "..", "src"))
    for selector in corpus_of(src):gmatch("@selector%(%s*([%w_:]+)%s*%)") do
        found[selector] = true
    end
    return found
end

local function module_headers(modules)
    local headers = {}
    for _, name in ipairs(table.orderkeys(modules)) do
        local entries = THIRD_PARTY_MODULES[name]
        if not entries then
            raise("%s is not a lowered third-party module: name it in THIRD_PARTY_MODULES", name)
        end
        local directory = path.absolute(modules[name])
        for _, file in ipairs(table.orderkeys(entries)) do
            local header = path.join(directory, file)
            if not os.isfile(header) then
                raise("module %s has no header %s", name, header)
            end
            table.insert(headers, {name = name, file = file, directory = directory, header = header, protocols = entries[file]})
        end
    end
    return headers
end

local function module_digest(modules)
    local headers = module_headers(modules)
    if #headers == 0 then
        return ""
    end
    local parts = {}
    for _, entry in ipairs(headers) do
        table.insert(parts, entry.name .. "=" .. entry.header .. "=" .. hash.sha256(entry.header) .. "=" .. table.concat(entry.protocols, ","))
    end
    table.insert(parts, table.concat(table.orderkeys(consulted_selectors()), ","))
    return table.concat(parts, "\n")
end

local function third_party_lowering(entry, consulted, markers)
    local text = io.readfile(entry.header)
    local protocols, members = {}, {}
    for _, protocol in ipairs(entry.protocols) do
        if not text:find("@protocol%s+" .. protocol .. "[%s<]") then
            raise("%s does not declare protocol %s, which THIRD_PARTY_MODULES names for it", entry.header, protocol)
        end
        protocols[protocol] = true
        members[protocol] = {}
        for selector in pairs(consulted) do
            members[protocol]["-" .. selector] = true
            members[protocol]["+" .. selector] = true
        end
    end
    return (lowering_of(text, {classes = {}, functions = {}, globals = {}, protocols = protocols, protocol_members = members, markers = markers}))
end

function third_party_modules(text)
    local modules = {}
    for entry in (text or ""):gmatch("[^;]+") do
        if entry:match("%S") then
            local name, directory = entry:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
            if not name or directory == "" then
                raise("apple_lowered_modules entry '%s' is not name=directory", entry)
            end
            modules[name] = directory
        end
    end
    return modules
end

function overlay(sdk, out, set, subtrees, modules)
    local text = set and serialize(set) or (io.readfile(members_file()) .. io.readfile(device_members_file()))
    local mapped = subtrees or VFS_SUBTREES
    local placed = module_digest(modules or {})
    local key = table.concat({sdk, out, hash.strhash128(text), table.concat(table.orderkeys(mapped), ","), placed}, "|")
    if built[key] then
        return built[key]
    end
    os.mkdir(out)
    local stamp = path.join(out, "input.digest")
    local digest = input_digest(sdk, text .. table.concat(table.orderkeys(mapped), ",") .. placed)
    local vfs = path.join(out, "vfs.yaml")
    if not (os.isfile(vfs) and os.isfile(stamp) and io.readfile(stamp) == digest) then
        vfs = build_overlay(sdk, out, set or read_all_members(), mapped, modules or {})
        io.writefile(stamp, digest)
    end
    built[key] = vfs
    return vfs
end

local function system_include_relative(file, sdk)
    local folder = path.join(sdk, "usr", "include")
    if file:sub(1, #folder + 1) == folder .. "/" then
        return file:sub(#folder + 2)
    end
end

VFS_SUBTREES = {}

VFS_FILES = {["os/lock.h"] = true, ["compression.h"] = true, ["_time.h"] = true, ["os.apinotes"] = true, ["simd/math.h"] = true}

LOWERED_FILES = {["compression.h"] = true, ["os/lock.h"] = true}

local function lowered_apinotes(text, set)
    local functions = set.functions or {}
    local current = nil
    local lines = {}
    for line in text:gmatch("[^\n]+") do
        local name = line:match("^%- Name: (%S+)")
        if name then
            current = name
        end
        if current and functions[current] and line:match("^  SwiftName:") then
            line = line:gsub("__(%w+):", "%1:")
        end
        table.insert(lines, line)
    end
    return table.concat(lines, "\n") .. "\n"
end

local function trait_name(name)
    return name:lower():find("trait", 1, true) ~= nil
end

local function lowered_trait_apinotes(text, set)
    local classes, protocols, types = set.classes or {}, set.protocols or {}, set.types or {}
    local protocol_members = set.protocol_members or {}
    local function backed(owner, key)
        for _, sign in ipairs({"-", "+"}) do
            if (classes[owner] or {})[sign .. key] or (protocol_members[owner] or {})[sign .. key] then
                return true
            end
        end
        return false
    end
    local owner, entry, member = nil, false, false
    local lines = {}
    for line in text:gmatch("[^\n]+") do
        local name = line:match("^%- Name: (%S+)")
        local sub = line:match("^  %- %a+: ['\"]?([^'\"]+)['\"]?$")
        if name then
            owner = name
            entry = trait_name(name) and (classes[name] ~= nil or protocols[name] ~= nil or types[name] == true)
            member = false
        elseif sub then
            member = trait_name(sub) and owner ~= nil and backed(owner, sub)
        end
        local private = (entry and line == "  SwiftPrivate: true") or (member and line == "    SwiftPrivate: true")
        if not private then
            table.insert(lines, line)
        end
    end
    return table.concat(lines, "\n") .. "\n"
end

local function vfs_subtree(relative, subtrees)
    local head = relative and relative:match("^([^/]+)")
    return head ~= nil and (subtrees or VFS_SUBTREES)[head] == true
end

function include_directory(out)
    return path.join(out, "include")
end

local function photos_armv7_interface(text)
    local lines, pending, skipping = {}, {}, false
    for line in text:gmatch("([^\n]*)\n") do
        if skipping then
            skipping = line ~= "}"
        elseif line:match("^@available") then
            table.insert(pending, line)
        elseif line == "public import ExtensionFoundation" then
            pending = {}
        elseif line:match("^public protocol PHBackgroundResourceUploadExtension") or line:match("^extension Photos%.PHBackgroundResourceUploadExtension") then
            pending = {}
            skipping = true
        else
            for _, attribute in ipairs(pending) do
                if line == "extension Photos.PHChange {" and attribute:find("iOS 8.0", 1, true) then
                    attribute = "@available(iOS 6.0, *)"
                end
                table.insert(lines, attribute)
            end
            pending = {}
            if line:match("^// swift%-module%-flags: ") then
                line = line:gsub("arm64e%-apple%-ios26%.2", "armv7-apple-ios6.0"):gsub(" %-enable%-library%-evolution", ""):gsub(" %-library%-level api", "")
            end
            table.insert(lines, line)
        end
    end
    return table.concat(lines, "\n") .. "\n"
end

local function armv7_overlays(sdk, out, roots)
    for _, overlay in ipairs({{"Photos", photos_armv7_interface}}) do
        local name, lower = overlay[1], overlay[2]
        local dir = path.join(sdk, "System", "Library", "Frameworks", name .. ".framework", "Modules", name .. ".swiftmodule")
        local source = path.join(dir, "arm64e-apple-ios.swiftinterface")
        if os.isfile(source) then
            local copy = path.join(out, path.relative(dir, sdk), "armv7-apple-ios.swiftinterface")
            os.mkdir(path.directory(copy))
            write_if_changed(copy, lower(io.readfile(source)))
            roots[dir] = roots[dir] or {}
            roots[dir]["armv7-apple-ios.swiftinterface"] = copy
        end
    end
end

local function nested_in(dir, roots)
    for root in pairs(roots) do
        if dir:sub(1, #root + 1) == root .. "/" then
            return true
        end
    end
    return false
end

local function listing_of(dir, roots)
    local copies = roots[dir] or {}
    local entries, named = {}, {}
    for _, file in ipairs(os.files(path.join(dir, "*"))) do
        local name = path.filename(file)
        named[name] = true
        table.insert(entries, string.format([[{"name": "%s", "type": "file", "external-contents": "%s"}]], name, copies[name] or file))
    end
    for name, copy in pairs(copies) do
        if not named[name] then
            table.insert(entries, string.format([[{"name": "%s", "type": "file", "external-contents": "%s"}]], name, copy))
        end
    end
    for _, folder in ipairs(os.dirs(path.join(dir, "*"))) do
        table.insert(entries, string.format([[{"name": "%s", "type": "directory", "contents": [%s]}]], path.filename(folder), table.concat(listing_of(folder, roots), ", ")))
    end
    byteorder.sort(entries)
    return entries
end

function directory_roots(roots)
    local dirs = {}
    for dir in pairs(roots) do
        if not nested_in(dir, roots) then
            table.insert(dirs, dir)
        end
    end
    byteorder.sort(dirs)
    local entries = {}
    for _, dir in ipairs(dirs) do
        table.insert(entries, string.format([[    {"name": "%s", "type": "directory", "contents": [%s]}]], dir, table.concat(listing_of(dir, roots), ", ")))
    end
    return entries
end

function build_overlay(sdk, out, set, subtrees, modules)
    set.markers = set.markers or region_markers(sdk)
    local changed = member_headers(sdk)
    local simd = path.join(sdk, "usr", "include", "simd", "math.h")
    changed[simd] = table.concat({
        "#if defined(__ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__) && __ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__ < 70000",
        "#ifdef __cplusplus",
        "extern \"C\" {",
        "#endif",
        "void __sincospif(float, float *, float *);",
        "void __sincospi(double, double *, double *);",
        "#ifdef __cplusplus",
        "}",
        "#endif",
        "#endif",
        "",
    }, "\n") .. io.readfile(simd)
    for _, file in ipairs(framework_headers(sdk)) do
        local text = changed[file] or io.readfile(file)
        local lowered = lowering_of(text, set)
        if lowered ~= text then
            changed[file] = lowered
        end
    end
    for _, name in ipairs(table.orderkeys(subtrees or VFS_SUBTREES)) do
        for _, file in ipairs(os.files(path.join(sdk, "usr", "include", name, "**.h"))) do
            local text = changed[file] or io.readfile(file)
            local lowered = lowering_of(text, set)
            if lowered ~= text then
                changed[file] = lowered
            end
        end
    end
    for name in pairs(LOWERED_FILES) do
        local file = path.join(sdk, "usr", "include", name)
        if name:match("%.h$") and os.isfile(file) then
            local text = changed[file] or io.readfile(file)
            local lowered = lowering_of(text, set)
            if lowered ~= text then
                changed[file] = lowered
            end
        end
    end
    local notes = path.join(sdk, "usr", "include", "os.apinotes")
    if os.isfile(notes) then
        changed[notes] = lowered_apinotes(io.readfile(notes), set)
    end
    local uikit_notes = path.join(sdk, "System", "Library", "Frameworks", "UIKit.framework", "Headers", "UIKit.apinotes")
    if os.isfile(uikit_notes) then
        changed[uikit_notes] = lowered_trait_apinotes(io.readfile(uikit_notes), set)
    end
    local roots = {}
    local file_roots = {}
    for file, text in pairs(changed) do
        local relative = system_include_relative(file, sdk)
        if relative then
            local copy = path.join(include_directory(out), relative)
            os.mkdir(path.directory(copy))
            write_if_changed(copy, text)
        end
        if not relative or vfs_subtree(relative, subtrees) or VFS_FILES[relative] then
            local copy = path.join(out, path.relative(file, sdk))
            os.mkdir(path.directory(copy))
            write_if_changed(copy, text)
            if VFS_FILES[relative] then
                table.insert(file_roots, string.format([[{"name": "%s", "type": "file", "external-contents": "%s"}]], file, copy))
            else
                local dir = path.directory(file)
                roots[dir] = roots[dir] or {}
                roots[dir][path.filename(file)] = copy
            end
        end
    end
    local headers = module_headers(modules or {})
    local consulted = #headers > 0 and consulted_selectors() or {}
    for _, entry in ipairs(headers) do
        local copy = path.join(out, "modules", entry.name, entry.file)
        os.mkdir(path.directory(copy))
        write_if_changed(copy, third_party_lowering(entry, consulted, set.markers))
        roots[entry.directory] = roots[entry.directory] or {}
        roots[entry.directory][entry.file] = copy
    end
    armv7_overlays(sdk, out, roots)
    for dir in pairs(roots) do
        local relative = system_include_relative(dir, sdk)
        if (relative and not vfs_subtree(relative, subtrees)) or dir == path.join(sdk, "usr", "include") then
            raise("the lowering would remap %s into the overlay; system headers reach the compile through the include directory", dir)
        end
    end
    local entries = directory_roots(roots)
    byteorder.sort(file_roots)
    for _, root in ipairs(file_roots) do
        table.insert(entries, "    " .. root)
    end
    local vfs = path.join(out, "vfs.yaml")
    write_if_changed(vfs, string.format([[
{
  "version": 0,
  "case-sensitive": false,
  "roots": [
%s
  ]
}
]], table.concat(entries, ",\n")))
    return vfs
end

local function swift_base(selector)
    local head = selector:match("^([%a_][%w_]*)")
    if not head then
        return nil
    end
    head = head:gsub("^stringBy(%u)", "%1")
    head = head:gsub("With%u.*$", "")
    head = head:gsub("For%u.*$", "")
    if head == "" then
        return nil
    end
    return head:sub(1, 1):lower() .. head:sub(2)
end

local function swift_init(key)
    local keyword = key:sub(2):match("^initWith([%w_]+):")
    if not keyword then
        return nil
    end
    local label, kind = keyword:match("^(.-)(String)$")
    if not label then
        label, kind = keyword:match("^(.-)(Data)$")
    end
    if not label or label == "" then
        return nil
    end
    return "init " .. label:sub(1, 1):lower() .. label:sub(2) .. ":" .. kind
end

function swift_names(set)
    local names = {}
    for class, members in pairs(set.classes) do
        local weak = set.weak_classes and set.weak_classes[class]
        local scope = class:startswith("NS") and class:sub(3) or class
        names["scoped " .. scope] = true
        for key in pairs(weak and {} or members) do
            local base = not key:sub(2):find("^init") and swift_base(key:sub(2))
            if base then
                names[base] = true
                names["scope " .. scope .. " " .. base] = true
            end
            local init = swift_init(key)
            if init then
                names[init] = true
                names["scope " .. scope .. " " .. init] = true
            end
        end
        if class:startswith("NS") and not weak then
            names["type " .. class] = true
            names["type " .. class:sub(3)] = true
        end
    end
    return names
end

local function type_opened(line)
    return line:match("^public%s+struct%s+([%a_][%w_]*)") or line:match("^public%s+class%s+([%a_][%w_]*)") or
           line:match("^public%s+enum%s+([%a_][%w_]*)") or line:match("^extension%s+([%a_][%w_]*)") or
           line:match("^struct%s+([%a_][%w_]*)") or line:match("^class%s+([%a_][%w_]*)") or
           line:match("^enum%s+([%a_][%w_]*)")
end

local function implemented_scope(scope, names)
    return scope ~= nil and names["type " .. scope] == true
end

local function lowered_by(line, names, types, scope)
    local name = line:match("public%s+var%s+([%a_][%w_]*)") or line:match("public%s+func%s+([%a_][%w_]*)")
    if name then
        if scope and names["scoped " .. scope] then
            return names["scope " .. scope .. " " .. name] or false
        end
        return names[name]
    end
    local label, rest = line:match("public%s+init%??%(%s*([%a_][%w_]*)%s+[%a_][%w_]*%s*:%s*(.*)$")
    if label then
        local kind = rest:match("^__shared%s+([%a_][%w_]*)") or rest:match("^([%a_][%w_]*)") or ""
        return names["init " .. label .. ":" .. kind]
    end
    local target = line:match("public%s+typealias%s+[%a_][%w_]*%s*=%s*([%a_][%w_%.]*)")
    if target then
        return types[(target:gsub("%.", ""))]
    end
    local declared = line:match("^%s*public%s+struct%s+([%a_][%w_]*)") or line:match("^%s*public%s+class%s+([%a_][%w_]*)") or
                     line:match("^%s*public%s+enum%s+([%a_][%w_]*)")
    if declared then
        return names["type " .. declared] or false
    end
    if line:match("^%s*public%s+static%s+func%s+[=<>!+%-*/&|^%%~]") then
        return implemented_scope(scope, names)
    end
    if not line:find("public", 1, true) and (line:match("^%s+[%a ]*func%s+[%a_]") or line:match("^%s+[%a ]*var%s+[%a_]")) then
        return implemented_scope(scope, names)
    end
    if line:match("^private%s+[%a ]*func%s") or line:match("^fileprivate%s+[%a ]*func%s") or line:match("^internal%s+[%a ]*func%s") then
        return true
    end
    return false
end

local function operator_extension(lines, at, names)
    local name = lines[at]:match("^extension%s+([%a_][%w_]*)%s*{")
    if not name or not names["type " .. name] then
        return false
    end
    for index = at + 1, #lines do
        if lines[index]:match("^}") then
            return false
        end
        if lines[index]:match("^%s*public%s+static%s+func%s+[=<>!+%-*/&|^%%~]") then
            return true
        end
    end
    return false
end

local function guarded_lines(file)
    local lines = {}
    local name = path.filename(file)
    for _, rows in pairs(runtime_guards.guards()) do
        for _, citation in pairs(rows) do
            local start = citation:find("Foundation/" .. name .. ":", 1, true)
            if start then
                for line in citation:sub(start):gmatch(":(%d+)") do
                    lines[tonumber(line)] = true
                end
            end
        end
    end
    return lines
end

function lower_swift_text(text, names, types, keep)
    local lines = {}
    for line in text:gmatch("([^\n]*)\n") do
        table.insert(lines, line)
    end
    types = types or {}
    keep = keep or {}
    local kept, pending, scope = {}, nil, nil
    for index, line in ipairs(lines) do
        local major = line:match("^%s*@available%(.*iOS%s+(%d+)")
        if major and tonumber(major) >= 7 and not keep[index] then
            pending = #kept + 1
        elseif pending and (lowered_by(line, names, types, scope) or operator_extension(lines, index, names)) then
            kept[pending] = false
            pending = nil
        elseif not (line:match("^%s*@available%(") or line:match("^%s*///") or line:match("^%s*//") or line:match("^%s*@[%w_]+") or line:match("^%s*$")) then
            pending = nil
        end
        table.insert(kept, line)
        if line:match("^}") then
            scope = nil
        end
        scope = type_opened(line) or scope
    end
    local buffer = {}
    for _, line in ipairs(kept) do
        if line then
            table.insert(buffer, line .. "\n")
        end
    end
    table.insert(buffer, text:match("([^\n]*)$"))
    return table.concat(buffer)
end

function swift_overlays(root, set)
    for _, entry in ipairs(MEMBERS) do
        local lowering = entry.overlay
        if lowering then
            local file = path.join(root, table.unpack(lowering.file))
            io.writefile(file, replaced(io.readfile(file), lowering, "the Swift overlay " .. file, entry.member))
        end
    end
    set = set or read_all_members()
    local names, types = swift_names(set), set.types or {}
    for _, file in ipairs(os.files(path.join(root, "stdlib", "public", "Darwin", "Foundation", "*.swift"))) do
        local text = io.readfile(file)
        local lowered = lower_swift_text(text, names, types, guarded_lines(file))
        if lowered ~= text then
            io.writefile(file, lowered)
        end
    end
end
