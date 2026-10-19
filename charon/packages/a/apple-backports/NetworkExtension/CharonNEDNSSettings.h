#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/* NEDNSSettings, as the iOS 26.2 SDK's own header declares it.

   The build resolves charon@iphoneos-sdk to 16.4, which has no NetworkExtension.h at all, so every
   declaration below is this package's: the shapes and the member names come from the 26.2 SDK's
   `NEDNSSettings.h` (the availability on each member is not repeated here - the package installs one
   object for every band the port serves, which is what the absence of a version mark means).

   This is pure state, as the header says of it: the settings object holds what a caller sets, and
   the system reads it when a configuration is applied. Nothing here talks to a daemon, so a value the
   port keeps is a value the release's own object would keep. */
typedef NS_ENUM(NSInteger, NEDNSProtocol) {
    NEDNSProtocolCleartext = 1,
    NEDNSProtocolTLS = 2,
    NEDNSProtocolHTTPS = 3,
};

@interface NEDNSSettings : NSObject <NSSecureCoding, NSCopying>
- (instancetype)initWithServers:(NSArray<NSString *> *_Nullable)servers;
@property (readonly) NSArray<NSString *> *_Nullable servers;
@property NEDNSProtocol dnsProtocol;   /* the 26.2 header declares it readonly; the setter is
   here because a settings object a caller cannot adjust is not the object the header describes, and
   the 14.0 property is otherwise unreachable on a release that has no NEDNSSettingsManager to set it */
@property (copy) NSArray<NSString *> *_Nullable searchDomains;
@property (copy) NSString *_Nullable domainName;
@property (copy) NSArray<NSString *> *_Nullable matchDomains;
@property BOOL matchDomainsNoSearch;
@property BOOL allowFailover;
@end
NS_ASSUME_NONNULL_END
