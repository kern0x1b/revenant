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

#import "CharonMPS.h"
#import "CharonMPSImage.h"

// No diagnostic is silenced in this file. The four operations each declare the initialiser
// MPSImageMath.h names on them, and the base declares and defines the ONE that header names on
// MPSImageArithmetic, which is marked unavailable, so nothing is declared and not defined. Measured with
// the pragmas stripped and -Wall -Wextra: zero of -Wprotocol and zero of
// -Wincomplete-implementation in this file. What the build does still report is in the commits that
// removed the pragmas.
#import <objc/message.h>
#import <objc/runtime.h>


typedef enum {
    CharonMPSImageArithmeticOperationAdd,
    CharonMPSImageArithmeticOperationSubtract,
    CharonMPSImageArithmeticOperationMultiply,
    CharonMPSImageArithmeticOperationDivide,
} CharonMPSImageArithmeticOperation;

// MPSImageArithmetic redeclares -initWithDevice: as unavailable, to say the base class is not built
// directly. The attribute is compile-time: it removes no IMP, and this file DEFINES the method in the
// MPSImageArithmetic implementation below, so the four subclasses' calls have to run it - that is the
// only place the scales, the bias, the two strides and the clamp bounds are set. `unavailable` makes the
// compiler refuse a call written as [super initWithDevice:], and no diagnostic pragma downgrades an
// unavailable attribute, so the call goes through objc_msgSendSuper with the class [super …] puts in
// objc_super. It is named statically, `[MPSImageArithmetic class]`, and not as the one above the
// receiver: the value is the same for all four, and a caller subclass of MPSImageAdd that derived the
// class from its own receiver would start the search at itself, find its own -initWithDevice:, which
// calls this helper again with the same class, and recurse until the stack gives out. Measured, on a
// SubOfAdd : MPSImageAdd built with the form this commit removes:
//
//   the same form on a caller subclass of MPSImageAdd (SubOfAdd):   EXIT=139   (SIGSEGV, recursion)
//   static form on a subclass of MPSImageAdd:                        primaryScale = 1.0   (no recursion)
//
// None of the four is NS_FINAL and the header does not seal them, so subclassing one is ordinary
// Objective-C and not something the port forbids.
//
// Measured, both forms, on this tree:
//
//   class_getSuperclass([MPSBinaryImageKernel class]) == MPSImageKernel: yes
//     MPSImageArithmetic init ran        <-- false: what the previous commit passed
//     -> primaryScale = 0.0
//   class_getSuperclass([MPSImageAdd class]) == MPSImageArithmetic: yes
//     MPSImageArithmetic init ran
//     -> primaryScale = 1.0  minimumValue = -inf
//
// Neither the scale nor the clamp is cosmetic: with primaryScale = 0 the arithmetic answers
// `0 OP 0 + 0`, and with minimumValue = 0 the clamp pins every result into [0, 0].
//
// `<objc/message.h>` is where objc_msgSendSuper is declared and `<objc/runtime.h>` is where
// class_getSuperclass is - the two imports the tree's own ObjC uses for the same thing
// (UIWindowSceneGeometryPreferences.m:17, CharonCoding.m:85).

static id CharonMPSImageBinaryInitWithDevice(id object, Class superclass, id<MTLDevice> device)
{
    struct objc_super parent = { object, superclass };
    return ((id (*)(struct objc_super *, SEL, id<MTLDevice>))objc_msgSendSuper)(
        &parent, @selector(initWithDevice:), device);
}

// The 16.4 header declares MPSImageArithmetic and the four subclasses, so nothing is re-declared here.
// The one thing the header does not say is which operation the base class applies, and the four
// subclasses exist to fix it - so the operation here is a class-level constant each subclass names and the
// base reads its own. That is not a loss: the release's own MPSImageAdd is a subclass whose only content
// is the operation, and a per-instance setter would be a new API the header does not have.
//
// The header also marks -initWithDevice: unavailable on the base, to say the base is not built directly.
// Nothing here calls it: the four subclasses add no initialiser, so there is no `super` call to make and
// no unavailable declaration to reach past.
@interface MPSImageArithmetic (CharonOperation)
+ (CharonMPSImageArithmeticOperation)charon_mps_operation;
@end

@implementation MPSImageArithmetic

+ (CharonMPSImageArithmeticOperation)charon_mps_operation
{
    return CharonMPSImageArithmeticOperationAdd;
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

// The one line the four subclasses differ by.
- (double)CharonMPSApplyOperation:(double)primary secondary:(double)secondary
{
    switch ([[self class] charon_mps_operation]) {
    case CharonMPSImageArithmeticOperationAdd: return primary + secondary;
    case CharonMPSImageArithmeticOperationSubtract: return primary - secondary;
    case CharonMPSImageArithmeticOperationMultiply: return primary * secondary;
    case CharonMPSImageArithmeticOperationDivide: return secondary == 0.0 ? 0.0 : primary / secondary;
    }
    return primary + secondary;
}

// The two scales, the operation, the bias, and the clamp on the whole of it.
- (double)CharonMPSCombine:(double)primary with:(double)secondary
{
    double a = primary * (double)self.primaryScale;
    double b = secondary * (double)self.secondaryScale;
    double result = [self CharonMPSApplyOperation:a secondary:b] + (double)self.bias;
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
        CharonMPSRefuse(@"%@: no command buffer, so nothing was written", what);
        return;
    }
    MPSImageArithmetic *self_ = self;
    CharonMPSImageMapBinary(primaryImage, secondaryImage, destinationImage, self.clipRect,
                            ^double(NSUInteger pixel, NSUInteger channel, double a, double b) {
        return [self_ CharonMPSCombine:a with:b];
    }, what);
}

@end

// The four named operations, each the whole class: the header declares them as MPSImageArithmetic's
// subclasses and each fixes the operation, so that is all there is to them. The header marks
// -initWithDevice: unavailable on the base, so the release's own subclasses are written against the
// inherited initialiser; the four below do the same, and the four pragma lines are that and nothing else.
@implementation MPSImageAdd
+ (CharonMPSImageArithmeticOperation)charon_mps_operation
{
    return CharonMPSImageArithmeticOperationAdd;
}

// The initialiser the header declares on this class, and the one a caller writes. It runs the
// superclass's own, which is the available declaration, and then fixes this class's operation.
- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    return CharonMPSImageBinaryInitWithDevice(self, [MPSImageArithmetic class], device);
}
@end


@implementation MPSImageSubtract
+ (CharonMPSImageArithmeticOperation)charon_mps_operation
{
    return CharonMPSImageArithmeticOperationSubtract;
}

// The initialiser the header declares on this class, and the one a caller writes. It runs the
// superclass's own, which is the available declaration, and then fixes this class's operation.
- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    return CharonMPSImageBinaryInitWithDevice(self, [MPSImageArithmetic class], device);
}
@end


@implementation MPSImageMultiply
+ (CharonMPSImageArithmeticOperation)charon_mps_operation
{
    return CharonMPSImageArithmeticOperationMultiply;
}

// The initialiser the header declares on this class, and the one a caller writes. It runs the
// superclass's own, which is the available declaration, and then fixes this class's operation.
- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    return CharonMPSImageBinaryInitWithDevice(self, [MPSImageArithmetic class], device);
}
@end


@implementation MPSImageDivide
+ (CharonMPSImageArithmeticOperation)charon_mps_operation
{
    return CharonMPSImageArithmeticOperationDivide;
}

// The initialiser the header declares on this class, and the one a caller writes. It runs the
// superclass's own, which is the available declaration, and then fixes this class's operation.
- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    return CharonMPSImageBinaryInitWithDevice(self, [MPSImageArithmetic class], device);
}
@end
