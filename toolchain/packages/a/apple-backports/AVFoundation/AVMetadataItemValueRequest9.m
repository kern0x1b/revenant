#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "CharonAVMetadataConstruction.h"

@interface AVMetadataItemValueRequest ()
@property (nonatomic, strong) id charonSpecifier;
@property (nonatomic, weak) AVMetadataItem *charonMetadataItem;
@property (nonatomic, strong) id charonResponseValue;
@property (nonatomic, strong) NSError *charonResponseError;
@end

@implementation AVMetadataItemValueRequest

@synthesize charonSpecifier = _charonSpecifier;
@synthesize charonMetadataItem = _charonMetadataItem;
@synthesize charonResponseValue = _charonResponseValue;
@synthesize charonResponseError = _charonResponseError;

- (instancetype)charon_initWithSpecifier:(id)specifier
{
    self = ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("init"));
    if (self) {
        _charonSpecifier = specifier;
    }
    return self;
}

- (id)specifier
{
    return self.charonSpecifier;
}

- (AVMetadataItem *)metadataItem
{
    return self.charonMetadataItem;
}

- (void)setMetadataItem:(AVMetadataItem *)metadataItem
{
    self.charonMetadataItem = metadataItem;
}

- (void)loadValuesAsynchronouslyForKeys:(NSArray<NSString *> *)keys
                      completionHandler:(nullable void (^)(void))handler
{
    if (handler) {
        handler();
    }
}

- (void)respondWithValue:(id<NSCopying>)value
{
    self.charonResponseValue = value ? ((id (*)(id, SEL))objc_msgSend)(value, @selector(copy)) : nil;
    self.charonResponseError = nil;
}

- (void)respondWithError:(NSError *)error
{
    self.charonResponseError = error;
    self.charonResponseValue = nil;
}

- (id)charon_responseValue
{
    return self.charonResponseValue;
}

- (NSError *)charon_responseError
{
    return self.charonResponseError;
}

@end
