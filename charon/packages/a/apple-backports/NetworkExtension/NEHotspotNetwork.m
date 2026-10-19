#import "CharonNEHotspot.h"

/* The CaptiveNetwork functions the release has, declared here rather than imported from
   SystemConfiguration/CaptiveNetwork.h: the SDK marks them deprecated from iOS 9.0, in favour of
   NEHotspotHelper, and this release is where they are the answer. Their symbols are the release's own;
   the library links SystemConfiguration for them. */
extern CFArrayRef CNCopySupportedInterfaces(void);
extern CFDictionaryRef CNCopyCurrentNetworkInfo(CFStringRef interfaceName);
extern const CFStringRef kCNNetworkInfoKeySSID;
extern const CFStringRef kCNNetworkInfoKeyBSSID;

/* The network object: state the system fills in, which the port fills from CaptiveNetwork where the
   release gives it, and otherwise leaves at the values the host answers for a network it did not
   measure (facts/NetworkExtension/Hotspot.md). */
@implementation NEHotspotNetwork {
    NSString *_SSID;
    NSString *_BSSID;
    NEHotspotNetworkSecurityType _securityType;
    double _signalStrength;
    BOOL _secure;
    BOOL _autoJoined;
    BOOL _justJoined;
    BOOL _chosenHelper;
    NEHotspotHelperConfidence _confidence;
    NSString *_password;
}

+ (void)fetchCurrentWithCompletionHandler:(void (^)(NEHotspotNetwork * __nullable currentNetwork))completionHandler
{
    /* The host calls back once, on the main thread, after the call has returned. */
    NEHotspotNetwork *current = nil;
    CFArrayRef interfaces = CNCopySupportedInterfaces();
    if (interfaces) {
        for (CFIndex i = 0; i < CFArrayGetCount(interfaces) && !current; i++) {
            CFStringRef name = CFArrayGetValueAtIndex(interfaces, i);
            CFDictionaryRef info = CNCopyCurrentNetworkInfo(name);
            if (info) {
                NSString *ssid = (__bridge NSString *)CFDictionaryGetValue(info, kCNNetworkInfoKeySSID);
                NSString *bssid = (__bridge NSString *)CFDictionaryGetValue(info, kCNNetworkInfoKeyBSSID);
                if (ssid) {
                    current = [[NEHotspotNetwork alloc] init];
                    current->_SSID = [ssid copy];
                    current->_BSSID = [bssid copy];
                }
                CFRelease(info);
            }
        }
        CFRelease(interfaces);
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        completionHandler(current);
    });
}

- (NSString *)SSID
{
    return _SSID;
}

- (NSString *)BSSID
{
    return _BSSID;
}

- (NEHotspotNetworkSecurityType)securityType
{
    return _securityType;
}

- (double)signalStrength
{
    return _signalStrength;
}

- (BOOL)isSecure
{
    return _secure;
}

- (BOOL)didAutoJoin
{
    return _autoJoined;
}

- (BOOL)didJustJoin
{
    return _justJoined;
}

- (BOOL)isChosenHelper
{
    return _chosenHelper;
}

/* The header has no getter for these two: the helper's confidence and password are what a helper hands
   back to the system, so the object keeps them and answers nothing. */
- (void)setConfidence:(NEHotspotHelperConfidence)confidence
{
    _confidence = confidence;
}

- (void)setPassword:(NSString *)password
{
    _password = [password copy];
}

@end
