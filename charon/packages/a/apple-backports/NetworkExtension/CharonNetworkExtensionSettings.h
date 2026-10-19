#import <Foundation/Foundation.h>

/* NEProxyServer, NEProxySettings, NEIPv4Route, NEIPv4Settings, NEIPv6Route and NEIPv6Settings, as the
   iOS 26.2 SDK's own headers
   declare them. The build resolves charon@iphoneos-sdk to 16.4, which has no NetworkExtension.h at
   all, so these declarations are this package's; the member names, the ownership and the availability
   come from `NEProxySettings.h` and `NEIPv4Settings.h` at that tag.

   All six are pure state, as the headers say of them: the system reads a settings object when a
   configuration is applied, so what a port object holds is what a release's own object would hold.
   The two IPv6 class methods the 26.2 header marks API_UNAVAILABLE on every platform are declared here
   anyway, because the header's own text declares them and a caller that reads them compiles against
   this header; tests/backports/host/netext-proxy/ checks the names against the header rather than
   against the host, since Apple's own class does not carry them.
   Two names are capitalised in the SDK and in the ledger alike - **HTTPEnabled**, **HTTPSEnabled** and
   **HTTPSServer** - and are spelled that way here.

   The names are checked against the 26.2 headers by tests/backports/host/netext-settings/, and the
   ones the host also carries are compared with the host's own answers, in two binaries, with dladdr
   naming which implementation answered. */
NS_ASSUME_NONNULL_BEGIN

@interface NEProxyServer : NSObject <NSSecureCoding, NSCopying>
- (instancetype)initWithAddress:(NSString *)address port:(NSInteger)port;
@property (readonly) NSString *address;
@property (readonly) NSInteger port;
@property BOOL authenticationRequired;
@property (copy, nullable) NSString *username;
@property (copy, nullable) NSString *password;
@end

@interface NEProxySettings : NSObject <NSSecureCoding, NSCopying>
@property BOOL autoProxyConfigurationEnabled;
@property (copy, nullable) NSURL *proxyAutoConfigurationURL;
@property (copy, nullable) NSString *proxyAutoConfigurationJavaScript;
@property BOOL HTTPEnabled;
@property (copy, nullable) NEProxyServer *HTTPServer;
@property BOOL HTTPSEnabled;
@property (copy, nullable) NEProxyServer *HTTPSServer;
@property BOOL excludeSimpleHostnames;
@property (copy, nullable) NSArray<NSString *> *exceptionList;
@property (copy, nullable) NSArray<NSString *> *matchDomains;
@end

@interface NEIPv4Route : NSObject <NSSecureCoding, NSCopying>
- (instancetype)initWithDestinationAddress:(NSString *)address subnetMask:(NSString *)subnetMask;
@property (readonly) NSString *destinationAddress;
@property (readonly) NSString *destinationSubnetMask;
@property (copy, nullable) NSString *gatewayAddress;
@property (class, readonly) NEIPv4Route *defaultRoute;
@end

@interface NEIPv4Settings : NSObject <NSSecureCoding, NSCopying>
- (instancetype)initWithAddresses:(NSArray<NSString *> *)addresses subnetMasks:(NSArray<NSString *> *)subnetMasks;
@property (class, readonly) NEIPv4Settings *settingsWithAutomaticAddressing;
@property (readonly) NSArray<NSString *> *addresses;
@property (readonly) NSArray<NSString *> *subnetMasks;
@property (copy, nullable) NSString *router;
@property (copy, nullable) NSArray<NEIPv4Route *> *includedRoutes;
@property (copy, nullable) NSArray<NEIPv4Route *> *excludedRoutes;
@end

@class NEIPv6Route;

@interface NEIPv6Route : NSObject <NSSecureCoding, NSCopying>
- (instancetype)initWithDestinationAddress:(NSString *)address networkPrefixLength:(NSNumber *)networkPrefixLength;
@property (readonly) NSString *destinationAddress;
@property (readonly) NSNumber *destinationNetworkPrefixLength;
@property (copy, nullable) NSString *gatewayAddress;
@property (class, readonly) NEIPv6Route *defaultRoute;
@end

@interface NEIPv6Settings : NSObject <NSSecureCoding, NSCopying>
- (instancetype)initWithAddresses:(NSArray<NSString *> *)addresses networkPrefixLengths:(NSArray<NSNumber *> *)networkPrefixLengths;
@property (class, readonly) NEIPv6Settings *settingsWithAutomaticAddressing;
@property (class, readonly) NEIPv6Settings *settingsWithLinkLocalAddressing;
@property (readonly) NSArray<NSString *> *addresses;
@property (readonly) NSArray<NSNumber *> *networkPrefixLengths;
@property (copy, nullable) NSArray<NEIPv6Route *> *includedRoutes;
@property (copy, nullable) NSArray<NEIPv6Route *> *excludedRoutes;
@end

NS_ASSUME_NONNULL_END
