#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "CharonAVMetadataConstruction.h"

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
