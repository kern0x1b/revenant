#import <Foundation/Foundation.h>

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
