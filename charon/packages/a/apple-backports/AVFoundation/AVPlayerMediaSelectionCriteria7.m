#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "CharonAVFDescriptorConstruction.h"

// AVPlayerMediaSelectionCriteria, iOS 7.
//
// **The class, in an object of its own, under Apple's own name.** The first HELD RUNG that exports
// `_OBJC_CLASS_$_AVPlayerMediaSelectionCriteria` and its metaclass is **7.0** - measured over every
// held cache (4.3, 6.1.3, 7.0, 7.1, 7.1.1, 7.1.2 and 8.0 armv7; 8.1.3, 8.2 and 8.4.1 armv7s; 9.3.6
// armv7; 10.0.1, 11.0 and 12.0 arm64; 16.0 arm64e) with _NSFileSize planted as a control, which
// answers 4.3 on this set. 4.3 and 6.1.3 do not export it, and they are the releases the port's floor
// is, so below 7.0 nothing of that name exists and a category alone would leave
// `check_registry` counting the row unbuilt and stopping the band build.
//
// Measured on the host, the class declares three readonly NSArray properties -
// preferredLanguages, preferredMediaCharacteristics, principalMediaCharacteristics - each
// `T@"NSArray",R,N`, with an instance size of 16 against NSObject's 8, so the port's instance holds
// the three references. The storage is associated, keyed on a string, so the two members that arrived
// AFTER the 7.0 rung can live in the category beside this file and land on the release's own instance
// from 7.0 up.

@implementation AVPlayerMediaSelectionCriteria

// The three values, associated under three string keys. The 12.0 category beside this file reads
// and writes the third of them through the same pair, which is why these are methods and not ivars.
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

// The three the 7.0 rung already has, so they are answered here rather than in the category.
- (NSArray<NSString *> *)preferredLanguages
{
    return self.charon_preferredLanguages ?: @[];
}

- (NSArray<NSString *> *)preferredMediaCharacteristics
{
    return self.charon_preferredMediaCharacteristics ?: @[];
}

// The header declares this INSTANCE initializer on the class, so it is implemented here rather than
// in the category beside this file: declared in one file and implemented in another, the build warns
// "method definition not found", and the warning was the build telling the truth.
- (instancetype)initWithPreferredLanguages:(NSArray<NSString *> *)preferredLanguages
               preferredMediaCharacteristics:(NSArray<NSString *> *)preferredMediaCharacteristics
{
    return [self charon_initWithPreferredLanguages:preferredLanguages
                        preferredMediaCharacteristics:preferredMediaCharacteristics
                    principalMediaCharacteristics:@[]];
}

// The header's two documented factories, which are the two ways a caller builds one without a
// principal characteristic list.
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
