#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "CharonAVFDescriptorConstruction.h"

// AVAssetResourceRenewalRequest, iOS 8.
//
// The first HELD RUNG that exports this class and its metaclass is **8.0**; 4.3, 6.1.3 and 7.0 do not,
// so the port defines it - and only it: its superclass, AVAssetResourceLoadingRequest, is the
// RELEASE's from 7.0, so this file adds a subclass and nothing else.
//
// **The host declares no own method and no own property on it**, and its instance size is 16, the same
// as its superclass's: it is a marker that says "this loading request wants renewing", and the
// behaviour is entirely its superclass's. So the port defines the class - which is what makes the name
// resolve and a `isKindOfClass:` or a cast a real answer - and the members it has are its
// superclass's, which the release answers from 7.0 up. Carrying a subclass with no members is not the
// silent shape: the class exists, `isKindOfClass:` answers, and the request it is asked to be behaves
// as its superclass says, which is what the header describes.

@implementation AVAssetResourceRenewalRequest
@end
