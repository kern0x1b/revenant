#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NEDNSProtocol) {
    NEDNSProtocolCleartext = 1,
    NEDNSProtocolTLS = 2,
    NEDNSProtocolHTTPS = 3,
};

@interface NEDNSSettings : NSObject <NSSecureCoding, NSCopying>
- (instancetype)initWithServers:(NSArray<NSString *> *_Nullable)servers;
@property (readonly) NSArray<NSString *> *_Nullable servers;
@property NEDNSProtocol dnsProtocol;
@property (copy) NSArray<NSString *> *_Nullable searchDomains;
@property (copy) NSString *_Nullable domainName;
@property (copy) NSArray<NSString *> *_Nullable matchDomains;
@property BOOL matchDomainsNoSearch;
@property BOOL allowFailover;
@end
NS_ASSUME_NONNULL_END
