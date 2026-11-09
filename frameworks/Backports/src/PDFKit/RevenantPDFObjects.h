#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RevenantPDFName : NSObject <NSCopying>
@property (nonatomic, readonly, copy) NSString *value;
+ (instancetype)name:(NSString *)value;
@end

@interface RevenantPDFReference : NSObject
@property (nonatomic, readonly) NSUInteger number;
@end

@interface RevenantPDFStream : NSObject
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *dictionary;
@property (nonatomic, readonly, copy) NSData *data;
+ (instancetype)streamWithDictionary:(NSDictionary<NSString *, id> *)dictionary data:(NSData *)data;
+ (instancetype)deflatedStreamWithDictionary:(NSDictionary<NSString *, id> *)dictionary data:(NSData *)data;
@end

@interface RevenantPDFWriter : NSObject
@property (nonatomic, readonly) NSUInteger objectCount;
- (instancetype)init;
- (instancetype)initEncryptedWithOwnerPassword:(nullable NSString *)owner
                                  userPassword:(nullable NSString *)user
                                   permissions:(uint32_t)permissions NS_DESIGNATED_INITIALIZER;
- (RevenantPDFReference *)reserve;
- (RevenantPDFReference *)add:(id)object;
- (void)setObject:(id)object forReference:(RevenantPDFReference *)reference;
- (RevenantPDFReference *)addCatalogWithPages:(RevenantPDFReference *)pages kids:(NSArray<RevenantPDFReference *> *)kids;
- (NSData *)dataWithRoot:(RevenantPDFReference *)root info:(nullable RevenantPDFReference *)info;
@end

NSData *_Nullable RevenantPDFDeflate(NSData *data);
NSString *RevenantPDFDateString(NSDate *date);
NSDate *_Nullable RevenantPDFDateFromString(NSString *string);
uint32_t RevenantPDFPermissionBits(NSUInteger accessPermissions);

NS_ASSUME_NONNULL_END
