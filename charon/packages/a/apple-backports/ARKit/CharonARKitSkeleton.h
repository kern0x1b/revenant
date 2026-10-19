#import <Foundation/Foundation.h>

typedef NSString *ARSkeletonJointName;

NS_ASSUME_NONNULL_BEGIN

@interface ARSkeletonDefinition : NSObject

@property (class, nonatomic, readonly) ARSkeletonDefinition *defaultBody2DSkeletonDefinition;

@property (nonatomic, readonly) NSUInteger jointCount;
@property (nonatomic, readonly) NSArray<NSString *> *jointNames;
@property (nonatomic, readonly) NSArray<NSNumber *> *parentIndices;

- (NSUInteger)indexForJointName:(ARSkeletonJointName)jointName;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
