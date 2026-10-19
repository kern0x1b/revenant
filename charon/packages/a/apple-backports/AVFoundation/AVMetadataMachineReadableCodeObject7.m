#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>

@interface AVMetadataMachineReadableCodeObject ()
@property (nonatomic, copy) NSString *charonStringValue;
@property (nonatomic, copy) NSArray<NSDictionary *> *charonCorners;
@end

@implementation AVMetadataMachineReadableCodeObject

@synthesize charonStringValue = _charonStringValue;
@synthesize charonCorners = _charonCorners;

- (instancetype)initWithStringValue:(NSString *)stringValue corners:(NSArray<NSDictionary *> *)corners
{
    self = ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("init"));
    if (self) {
        _charonStringValue = [stringValue copy];
        _charonCorners = [corners copy] ?: @[];
    }
    return self;
}

- (NSString *)stringValue
{
    return self.charonStringValue;
}

- (NSArray<NSDictionary *> *)corners
{
    return self.charonCorners ?: @[];
}

@end
