#import "RevenantMPS.h"
#import "RevenantMPSImage.h"

#import <objc/message.h>
#import <objc/runtime.h>


typedef enum {
    RevenantMPSImageArithmeticOperationAdd,
    RevenantMPSImageArithmeticOperationSubtract,
    RevenantMPSImageArithmeticOperationMultiply,
    RevenantMPSImageArithmeticOperationDivide,
} RevenantMPSImageArithmeticOperation;

static id RevenantMPSImageBinaryInitWithDevice(id object, Class superclass, id<MTLDevice> device)
{
    struct objc_super parent = { object, superclass };
    return ((id (*)(struct objc_super *, SEL, id<MTLDevice>))objc_msgSendSuper)(
        &parent, @selector(initWithDevice:), device);
}

@interface MPSImageArithmetic (RevenantOperation)
+ (RevenantMPSImageArithmeticOperation)revenant_mps_operation;
@end

@implementation MPSImageArithmetic

+ (RevenantMPSImageArithmeticOperation)revenant_mps_operation
{
    return RevenantMPSImageArithmeticOperationAdd;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [super initWithDevice:device])) {
        _primaryScale = 1.0f;
        _secondaryScale = 1.0f;
        _bias = 0.0f;
        _minimumValue = -INFINITY;
        _maximumValue = INFINITY;
        _primaryStrideInPixels = MTLSizeMake(1, 1, 1);
        _secondaryStrideInPixels = MTLSizeMake(1, 1, 1);
    }
    return self;
}

- (double)RevenantMPSApplyOperation:(double)primary secondary:(double)secondary
{
    switch ([[self class] revenant_mps_operation]) {
    case RevenantMPSImageArithmeticOperationAdd: return primary + secondary;
    case RevenantMPSImageArithmeticOperationSubtract: return primary - secondary;
    case RevenantMPSImageArithmeticOperationMultiply: return primary * secondary;
    case RevenantMPSImageArithmeticOperationDivide: return secondary == 0.0 ? 0.0 : primary / secondary;
    }
    return primary + secondary;
}

- (double)RevenantMPSCombine:(double)primary with:(double)secondary
{
    double a = primary * (double)self.primaryScale;
    double b = secondary * (double)self.secondaryScale;
    double result = [self RevenantMPSApplyOperation:a secondary:b] + (double)self.bias;
    if (result < (double)self.minimumValue)
        result = (double)self.minimumValue;
    if (result > (double)self.maximumValue)
        result = (double)self.maximumValue;
    return result;
}

- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
               primaryImage:(MPSImage *)primaryImage
             secondaryImage:(MPSImage *)secondaryImage
              destinationImage:(MPSImage *)destinationImage
{
    NSString *what = NSStringFromClass([self class]);
    if (!commandBuffer) {
        RevenantMPSRefuse(@"%@: no command buffer, so nothing was written", what);
        return;
    }
    MPSImageArithmetic *self_ = self;
    RevenantMPSImageMapBinary(primaryImage, secondaryImage, destinationImage, self.clipRect,
                            ^double(NSUInteger pixel, NSUInteger channel, double a, double b) {
        return [self_ RevenantMPSCombine:a with:b];
    }, what);
}

@end

@implementation MPSImageAdd
+ (RevenantMPSImageArithmeticOperation)revenant_mps_operation
{
    return RevenantMPSImageArithmeticOperationAdd;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    return RevenantMPSImageBinaryInitWithDevice(self, [MPSImageArithmetic class], device);
}
@end


@implementation MPSImageSubtract
+ (RevenantMPSImageArithmeticOperation)revenant_mps_operation
{
    return RevenantMPSImageArithmeticOperationSubtract;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    return RevenantMPSImageBinaryInitWithDevice(self, [MPSImageArithmetic class], device);
}
@end


@implementation MPSImageMultiply
+ (RevenantMPSImageArithmeticOperation)revenant_mps_operation
{
    return RevenantMPSImageArithmeticOperationMultiply;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    return RevenantMPSImageBinaryInitWithDevice(self, [MPSImageArithmetic class], device);
}
@end


@implementation MPSImageDivide
+ (RevenantMPSImageArithmeticOperation)revenant_mps_operation
{
    return RevenantMPSImageArithmeticOperationDivide;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    return RevenantMPSImageBinaryInitWithDevice(self, [MPSImageArithmetic class], device);
}
@end
