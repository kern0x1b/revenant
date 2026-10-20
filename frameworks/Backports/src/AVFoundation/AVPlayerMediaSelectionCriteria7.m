#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "RevenantAVFDescriptorConstruction.h"

@implementation AVPlayerMediaSelectionCriteria

- (NSArray<NSString *> *)revenant_preferredLanguages
{
    return objc_getAssociatedObject(self, "revenant.avf.criteria.preferredLanguages") ?: @[];
}

- (void)revenant_setPreferredLanguages:(NSArray<NSString *> *)preferredLanguages
{
    objc_setAssociatedObject(self, "revenant.avf.criteria.preferredLanguages",
                             preferredLanguages ?: @[], OBJC_ASSOCIATION_COPY);
}

- (NSArray<NSString *> *)revenant_preferredMediaCharacteristics
{
    return objc_getAssociatedObject(self, "revenant.avf.criteria.preferredMediaCharacteristics") ?: @[];
}

- (void)revenant_setPreferredMediaCharacteristics:(NSArray<NSString *> *)characteristics
{
    objc_setAssociatedObject(self, "revenant.avf.criteria.preferredMediaCharacteristics",
                             characteristics ?: @[], OBJC_ASSOCIATION_COPY);
}

- (NSArray<NSString *> *)revenant_principalMediaCharacteristics
{
    return objc_getAssociatedObject(self, "revenant.avf.criteria.principalMediaCharacteristics") ?: @[];
}

- (void)revenant_setPrincipalMediaCharacteristics:(NSArray<NSString *> *)principal
{
    objc_setAssociatedObject(self, "revenant.avf.criteria.principalMediaCharacteristics",
                             principal ?: @[], OBJC_ASSOCIATION_COPY);
}


- (instancetype)revenant_initWithPreferredLanguages:(NSArray<NSString *> *)preferredLanguages
                   preferredMediaCharacteristics:(NSArray<NSString *> *)preferredMediaCharacteristics
                       principalMediaCharacteristics:(NSArray<NSString *> *)principalMediaCharacteristics
{
    self = [super init];
    if (self) {
        [self revenant_setPreferredLanguages:preferredLanguages];
        [self revenant_setPreferredMediaCharacteristics:preferredMediaCharacteristics];
        [self revenant_setPrincipalMediaCharacteristics:principalMediaCharacteristics];
    }
    return self;
}

- (NSArray<NSString *> *)preferredLanguages
{
    return self.revenant_preferredLanguages ?: @[];
}

- (NSArray<NSString *> *)preferredMediaCharacteristics
{
    return self.revenant_preferredMediaCharacteristics ?: @[];
}

- (instancetype)initWithPreferredLanguages:(NSArray<NSString *> *)preferredLanguages
               preferredMediaCharacteristics:(NSArray<NSString *> *)preferredMediaCharacteristics
{
    return [self revenant_initWithPreferredLanguages:preferredLanguages
                        preferredMediaCharacteristics:preferredMediaCharacteristics
                    principalMediaCharacteristics:@[]];
}

+ (instancetype)preferredMediaSelectionCriteriaWithPreferredLanguages:(NSArray<NSString *> *)languages
                                       preferredMediaCharacteristics:(NSArray<NSString *> *)characteristics
{
    return [[self alloc] revenant_initWithPreferredLanguages:languages
                            preferredMediaCharacteristics:characteristics
                        principalMediaCharacteristics:@[]];
}

+ (instancetype)preferredMediaSelectionCriteriaWithPreferredLanguages:(NSArray<NSString *> *)languages
                                       preferredMediaCharacteristics:(NSArray<NSString *> *)characteristics
                           preferredMediaSubTypes:(NSArray<NSString *> *)subTypes
                           precludedMediaSubTypes:(NSArray<NSString *> *)precluded
{
    return [[self alloc] revenant_initWithPreferredLanguages:languages
                            preferredMediaCharacteristics:characteristics
                        principalMediaCharacteristics:@[]];
}

- (NSUInteger)hash
{
    return self.revenant_preferredLanguages.hash ^ self.revenant_preferredMediaCharacteristics.count;
}

- (BOOL)isEqual:(id)other
{
    if (other == self) {
        return YES;
    }
    if (![other isKindOfClass:[AVPlayerMediaSelectionCriteria class]]) {
        return NO;
    }
    AVPlayerMediaSelectionCriteria *that = other;
    return [self.preferredLanguages isEqualToArray:that.preferredLanguages]
        && [self.preferredMediaCharacteristics isEqualToArray:that.preferredMediaCharacteristics];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<AVPlayerMediaSelectionCriteria %p languages=%lu characteristics=%lu>",
            self, (unsigned long)self.preferredLanguages.count,
            (unsigned long)self.preferredMediaCharacteristics.count];
}

@end
