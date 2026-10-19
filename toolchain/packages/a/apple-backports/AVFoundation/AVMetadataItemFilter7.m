#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "RevenantAVMetadataConstruction.h"

@implementation AVMetadataItemFilter (RevenantAVMetadataIdentifiers7)

- (instancetype)revenant_initWithIdentifiers:(NSArray<AVMetadataIdentifier> *)identifiers
{
    self = ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("init"));
    if (self && [self respondsToSelector:@selector(revenant_setIdentifiers:)]) {
        ((void (*)(id, SEL, id))objc_msgSend)(self, @selector(revenant_setIdentifiers:), identifiers);
    }
    return self;
}

+ (instancetype)revenant_metadataItemFilterWithIdentifiers:(NSArray<AVMetadataIdentifier> *)identifiers
{
    return [[self alloc] revenant_initWithIdentifiers:identifiers];
}

- (NSArray<AVMetadataIdentifier> *)identifiers
{
    if (![self respondsToSelector:@selector(revenant_storedIdentifiers)]) {
        return @[];
    }
    return ((id (*)(id, SEL))objc_msgSend)(self, @selector(revenant_storedIdentifiers));
}

@end
