#import <Foundation/Foundation.h>
#import <Security/SecProtocolMetadata.h>

NS_ASSUME_NONNULL_BEGIN

@interface RevenantSecProtocolMetadata : NSObject <OS_sec_protocol_metadata>

@property (nonatomic) uint16_t negotiatedVersion;
@property (nonatomic) uint16_t negotiatedCipherSuite;
@property (nonatomic, nullable) NSString *negotiatedProtocol;
@property (nonatomic, nullable) NSData *ocspResponse;

@end

NS_ASSUME_NONNULL_END
