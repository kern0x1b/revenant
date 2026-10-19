#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "RevenantAVMetadataConstruction.h"

@interface AVMetadataItemValueRequest ()
@property (nonatomic, strong) id revenantSpecifier;
@property (nonatomic, weak) AVMetadataItem *revenantMetadataItem;
@property (nonatomic, strong) id revenantResponseValue;
@property (nonatomic, strong) NSError *revenantResponseError;
@end

@implementation AVMetadataItemValueRequest

@synthesize revenantSpecifier = _revenantSpecifier;
@synthesize revenantMetadataItem = _revenantMetadataItem;
@synthesize revenantResponseValue = _revenantResponseValue;
@synthesize revenantResponseError = _revenantResponseError;

- (instancetype)revenant_initWithSpecifier:(id)specifier
{
    self = ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("init"));
    if (self) {
        _revenantSpecifier = specifier;
    }
    return self;
}

- (id)specifier
{
    return self.revenantSpecifier;
}

- (AVMetadataItem *)metadataItem
{
    return self.revenantMetadataItem;
}

- (void)setMetadataItem:(AVMetadataItem *)metadataItem
{
    self.revenantMetadataItem = metadataItem;
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
    self.revenantResponseValue = value ? ((id (*)(id, SEL))objc_msgSend)(value, @selector(copy)) : nil;
    self.revenantResponseError = nil;
}

- (void)respondWithError:(NSError *)error
{
    self.revenantResponseError = error;
    self.revenantResponseValue = nil;
}

- (id)revenant_responseValue
{
    return self.revenantResponseValue;
}

- (NSError *)revenant_responseError
{
    return self.revenantResponseError;
}

@end
