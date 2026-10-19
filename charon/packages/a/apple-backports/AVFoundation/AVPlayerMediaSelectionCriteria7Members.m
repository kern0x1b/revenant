#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "CharonAVFDescriptorConstruction.h"

// AVPlayerMediaSelectionCriteria's 12.0 members, in a CATEGORY.
//
// `principalMediaCharacteristics` and `+…initWithPrincipalMediaCharacteristics:preferredLanguages:
// preferredMediaCharacteristics:` are annotated ios(12.0) in the 26.2 headers, which is AFTER the 7.0
// rung the class itself is first exported at. A class symbol is dropped from 7.0 up, where the
// release's own class answers, so members that arrived after the rung have to be a category: a
// category defines no symbol and is therefore never dropped, and it lands on whichever instance is in
// the binary - the port's below 7.0, the release's from 7.0 up.
//
// The store is the associated property the class object declares, so the two files read and write one
// value and cannot disagree.

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
