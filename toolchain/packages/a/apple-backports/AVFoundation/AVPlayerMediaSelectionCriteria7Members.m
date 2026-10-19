#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "CharonAVFDescriptorConstruction.h"

@implementation AVPlayerMediaSelectionCriteria (CharonAVFDescriptorMembers12)

- (NSArray<NSString *> *)principalMediaCharacteristics
{
    return self.charon_principalMediaCharacteristics ?: @[];
}

- (instancetype)initWithPrincipalMediaCharacteristics:(NSArray<NSString *> *)principal
                                 preferredLanguages:(NSArray<NSString *> *)languages
                   preferredMediaCharacteristics:(NSArray<NSString *> *)characteristics
{
    return [self charon_initWithPreferredLanguages:languages
                        preferredMediaCharacteristics:characteristics
                    principalMediaCharacteristics:principal];
}

@end
