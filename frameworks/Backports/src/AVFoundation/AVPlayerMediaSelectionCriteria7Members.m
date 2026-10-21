#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "RevenantAVFDescriptorConstruction.h"

@implementation AVPlayerMediaSelectionCriteria (RevenantAVFDescriptorMembers12)

- (NSArray<NSString *> *)principalMediaCharacteristics
{
    return self.revenant_principalMediaCharacteristics ?: @[];
}

- (instancetype)initWithPrincipalMediaCharacteristics:(NSArray<NSString *> *)principal
                                 preferredLanguages:(NSArray<NSString *> *)languages
                   preferredMediaCharacteristics:(NSArray<NSString *> *)characteristics
{
    return [self revenant_initWithPreferredLanguages:languages
                        preferredMediaCharacteristics:characteristics
                    principalMediaCharacteristics:principal];
}

@end
