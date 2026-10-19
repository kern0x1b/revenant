#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "CharonAVFDescriptorConstruction.h"

@implementation AVPlayerMediaSelectionCriteria

- (NSArray<NSString *> *)charon_preferredLanguages
{
    return objc_getAssociatedObject(self, "charon.avf.criteria.preferredLanguages") ?: @[];
}

- (void)charon_setPreferredLanguages:(NSArray<NSString *> *)preferredLanguages
{
    objc_setAssociatedObject(self, "charon.avf.criteria.preferredLanguages",
                             preferredLanguages ?: @[], OBJC_ASSOCIATION_COPY);
}

- (NSArray<NSString *> *)charon_preferredMediaCharacteristics
{
    return objc_getAssociatedObject(self, "charon.avf.criteria.preferredMediaCharacteristics") ?: @[];
}

- (void)charon_setPreferredMediaCharacteristics:(NSArray<NSString *> *)characteristics
{
    objc_setAssociatedObject(self, "charon.avf.criteria.preferredMediaCharacteristics",
                             characteristics ?: @[], OBJC_ASSOCIATION_COPY);
}

- (NSArray<NSString *> *)charon_principalMediaCharacteristics
{
    return objc_getAssociatedObject(self, "charon.avf.criteria.principalMediaCharacteristics") ?: @[];
}

- (void)charon_setPrincipalMediaCharacteristics:(NSArray<NSString *> *)principal
{
    objc_setAssociatedObject(self, "charon.avf.criteria.principalMediaCharacteristics",
                             principal ?: @[], OBJC_ASSOCIATION_COPY);
}


- (instancetype)charon_initWithPreferredLanguages:(NSArray<NSString *> *)preferredLanguages
                   preferredMediaCharacteristics:(NSArray<NSString *> *)preferredMediaCharacteristics
                       principalMediaCharacteristics:(NSArray<NSString *> *)principalMediaCharacteristics
{
    self = [super init];
    if (self) {
        [self charon_setPreferredLanguages:preferredLanguages];
        [self charon_setPreferredMediaCharacteristics:preferredMediaCharacteristics];
        [self charon_setPrincipalMediaCharacteristics:principalMediaCharacteristics];
    }
    return self;
}

- (NSArray<NSString *> *)preferredLanguages
{
    return self.charon_preferredLanguages ?: @[];
}

- (NSArray<NSString *> *)preferredMediaCharacteristics
{
    return self.charon_preferredMediaCharacteristics ?: @[];
}

- (instancetype)initWithPreferredLanguages:(NSArray<NSString *> *)preferredLanguages
               preferredMediaCharacteristics:(NSArray<NSString *> *)preferredMediaCharacteristics
{
    return [self charon_initWithPreferredLanguages:preferredLanguages
                        preferredMediaCharacteristics:preferredMediaCharacteristics
                    principalMediaCharacteristics:@[]];
}

+ (instancetype)preferredMediaSelectionCriteriaWithPreferredLanguages:(NSArray<NSString *> *)languages
                                       preferredMediaCharacteristics:(NSArray<NSString *> *)characteristics
{
    return [[self alloc] charon_initWithPreferredLanguages:languages
                            preferredMediaCharacteristics:characteristics
                        principalMediaCharacteristics:@[]];
}

+ (instancetype)preferredMediaSelectionCriteriaWithPreferredLanguages:(NSArray<NSString *> *)languages
                                       preferredMediaCharacteristics:(NSArray<NSString *> *)characteristics
                           preferredMediaSubTypes:(NSArray<NSString *> *)subTypes
                           precludedMediaSubTypes:(NSArray<NSString *> *)precluded
{
    return [[self alloc] charon_initWithPreferredLanguages:languages
                            preferredMediaCharacteristics:characteristics
                        principalMediaCharacteristics:@[]];
}

- (NSUInteger)hash
{
    return self.charon_preferredLanguages.hash ^ self.charon_preferredMediaCharacteristics.count;
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
