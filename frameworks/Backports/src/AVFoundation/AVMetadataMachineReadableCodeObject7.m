#import "RevenantAVMetadataConstruction.h"
#import <objc/message.h>

@interface AVMetadataMachineReadableCodeObject ()
@property (nonatomic, copy) NSString *revenantType;
@property (nonatomic, copy) NSString *revenantStringValue;
@property (nonatomic, copy) NSArray<NSDictionary *> *revenantCorners;
@property (nonatomic, assign) CMTime revenantTime;
@end

@implementation AVMetadataMachineReadableCodeObject

@synthesize revenantType = _revenantType;
@synthesize revenantStringValue = _revenantStringValue;
@synthesize revenantCorners = _revenantCorners;
@synthesize revenantTime = _revenantTime;

- (instancetype)revenant_initWithType:(NSString *)type stringValue:(NSString *)stringValue corners:(NSArray<NSDictionary *> *)corners time:(CMTime)time
{
    self = ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("init"));
    if (self) {
        _revenantType = [type copy];
        _revenantStringValue = [stringValue copy];
        _revenantCorners = [corners copy] ?: @[];
        _revenantTime = time;
    }
    return self;
}

- (NSString *)type
{
    return self.revenantType;
}

- (NSString *)stringValue
{
    return self.revenantStringValue;
}

- (NSArray<NSDictionary *> *)corners
{
    return self.revenantCorners ?: @[];
}

- (CGRect)bounds
{
    CGFloat minX = CGFLOAT_MAX, minY = CGFLOAT_MAX, maxX = -CGFLOAT_MAX, maxY = -CGFLOAT_MAX;
    for (NSDictionary *corner in self.revenantCorners) {
        CGPoint point = CGPointZero;
        CGPointMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)corner, &point);
        minX = MIN(minX, point.x);
        minY = MIN(minY, point.y);
        maxX = MAX(maxX, point.x);
        maxY = MAX(maxY, point.y);
    }
    if (minX > maxX)
        return CGRectZero;
    return CGRectMake(minX, minY, maxX - minX, maxY - minY);
}

- (CMTime)time
{
    return self.revenantTime;
}

@end
