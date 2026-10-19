#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>

@interface AVMetadataMachineReadableCodeObject ()
@property (nonatomic, copy) NSString *revenantStringValue;
@property (nonatomic, copy) NSArray<NSDictionary *> *revenantCorners;
@end

@implementation AVMetadataMachineReadableCodeObject

@synthesize revenantStringValue = _revenantStringValue;
@synthesize revenantCorners = _revenantCorners;

- (instancetype)initWithStringValue:(NSString *)stringValue corners:(NSArray<NSDictionary *> *)corners
{
    self = ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("init"));
    if (self) {
        _revenantStringValue = [stringValue copy];
        _revenantCorners = [corners copy] ?: @[];
    }
    return self;
}

- (NSString *)stringValue
{
    return self.revenantStringValue;
}

- (NSArray<NSDictionary *> *)corners
{
    return self.revenantCorners ?: @[];
}

@end
