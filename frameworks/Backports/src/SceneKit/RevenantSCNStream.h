#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RevenantSCNStream : NSObject
- (nullable instancetype)initWithURL:(NSURL *)url channels:(unsigned int)channels;
- (void)primeSource:(unsigned int)source loops:(BOOL)loops;
- (void)refillSource:(unsigned int)source loops:(BOOL)loops;
- (BOOL)isExhaustedOnSource:(unsigned int)source;
- (void)dispose;
@end

NS_ASSUME_NONNULL_END
