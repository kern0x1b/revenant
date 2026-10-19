#import "CharonNEHotspot.h"

extern CFArrayRef CNCopySupportedInterfaces(void);
extern CFDictionaryRef CNCopyCurrentNetworkInfo(CFStringRef interfaceName);
extern const CFStringRef kCNNetworkInfoKeySSID;
extern const CFStringRef kCNNetworkInfoKeyBSSID;

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

- (void)setConfidence:(NEHotspotHelperConfidence)confidence
{
    _confidence = confidence;
}

- (void)setPassword:(NSString *)password
{
    _password = [password copy];
}

@end
