#import <Foundation/Foundation.h>

@interface RevenantPhotosImageCache : NSObject

@property (nonatomic, readonly) NSUInteger capacity;
@property (nonatomic, readonly) NSUInteger totalCost;
@property (nonatomic, readonly) NSUInteger count;

- (instancetype)initWithCapacity:(NSUInteger)capacity;
- (id)objectForKey:(id<NSCopying>)key;
- (void)setObject:(id)object forKey:(id<NSCopying>)key cost:(NSUInteger)cost;
- (void)removeObjectForKey:(id<NSCopying>)key;
- (void)removeAllObjects;

@end
