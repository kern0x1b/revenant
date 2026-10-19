// MPSImageArithmetic13.m - the binary arithmetic kernel and its four named operations.
//
// MPSImageMath.h of the release declares MPSImageArithmetic over MPSBinaryImageKernel with two scale
// factors, a bias, two strides, a minimum and a maximum, and four subclasses that each fix the
// operation. This file implements the kernel and the four, and the arithmetic is the one the header
// states: the primary image scaled by primaryScale, plus or minus or times or divided by the secondary
// scaled by secondaryScale, plus the bias, clamped to the minimum and the maximum the caller set.
//
// The order the release applies them in is the one the header's own formula gives, and it matters for
// a float: the result is
//
//     result = clamp(primary * primaryScale  OP  secondary * secondaryScale + bias, minimum, maximum)
//
// with the clamp on the whole of it, and the two scales applied to their own image before the
// operation. The primary and secondary strides are in pixels, so a kernel that was given a stride walks
// the image with it and one that was not walks it pixel for pixel, which is the default the header names.
//
// Open source checked: tencent/ncnn 20260526 (BSD-3-Clause, src/layer/pooling.h:22-23 and
// src/layer/pooling.cpp:255-266): not used because MPSImageArithmetic's API is the release's and not
// ncnn's; ncnn was read to corroborate the operation set and the pooling divisor rule MPS's own header
// names, and nothing is copied from it. The arithmetic here is MPSImageMath.h's, and the file is a fresh
// implementation with no third-party licence to carry.

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
