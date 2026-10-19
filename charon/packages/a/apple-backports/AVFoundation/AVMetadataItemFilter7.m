#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "CharonAVMetadataConstruction.h"

// AVMetadataItemFilter's 7.0 members, and nothing else: three selectors, all in a CATEGORY, so this
// object defines no symbol at all and `nm -gU` finds no `_OBJC_CLASS_$_` in it.
//
// That is the point of it being separate from AVMetadataItemFilter.m. The class object there defines
// the class, because 4.3 and 6.1.3 have no AVMetadataItemFilter and the 6.1.3 band needs the name to
// exist. A class symbol is dropped from 7.0 up, where the release's own class answers; a category's
// symbols are not symbols, so it is never dropped, and these three members ride along on whichever
// class is in the binary.
//
// The 7.0 spellings are absent from the SDK the port compiles against, so they are declared in
// CharonAVMetadataConstruction.h: an application written for 7.0 calls -identifiers, and the SDK's own
// header is all a caller has otherwise, and it does not have it.

@implementation AVMetadataItemFilter (CharonAVMetadataIdentifiers7)

- (instancetype)charon_initWithIdentifiers:(NSArray<AVMetadataIdentifier> *)identifiers
{
    self = ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("init"));
    if (self && [self respondsToSelector:@selector(charon_setIdentifiers:)]) {
        ((void (*)(id, SEL, id))objc_msgSend)(self, @selector(charon_setIdentifiers:), identifiers);
    }
    return self;
}

+ (instancetype)charon_metadataItemFilterWithIdentifiers:(NSArray<AVMetadataIdentifier> *)identifiers
{
    return [[self alloc] charon_initWithIdentifiers:identifiers];
}

- (NSArray<AVMetadataIdentifier> *)identifiers
{
    if (![self respondsToSelector:@selector(charon_storedIdentifiers)]) {
        return @[];
    }
    return ((id (*)(id, SEL))objc_msgSend)(self, @selector(charon_storedIdentifiers));
}

@end
