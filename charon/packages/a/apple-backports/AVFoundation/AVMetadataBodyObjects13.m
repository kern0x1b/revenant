#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "CharonAVMetadataConstruction.h"

// The body-object classes, iOS 13.
//
// A body object is one detection's measurements: which body, which object inside it, which face, and
// the two angles. There are five classes - the abstract-ish base, a cat, a dog, a human, and a salient
// object, which is the base's measurements without a body.
//
// **Nothing here produces one in the field.** A detector writes these, and a detector is a capture
// pipeline: AVCaptureMetadataOutput is not carried by this port and is a separate row. So the class is
// carried so that the name resolves and a `isKindOfClass:` or a cast is a real answer, its members are
// carried so they are callable, and the port's own initializer is how its code and its tests make one
// and hold the values to the answers. That is the carried-class shape and not the silent one: an empty
// class of this name would answer `isKindOfClass:` yes and then answer nothing, whereas this one
// answers the header's members, and answers them with the values a detection would have put there.
//
// The defaults after a plain -init are the numbers below, and they are the answer for a detection that
// did not happen: no body, no object, no face, and the two angles absent. `hasRollAngle` and
// `hasYawAngle` are what say "absent", so the angles themselves are zero and the flags are NO -
// which is the only way a caller can tell an absent angle from a measured zero, and getting that wrong
// would report a level detector as level.
//
// The angles are CGFloat, and `-confidence` in the protocol these classes answer is a float. Both are
// read through a correctly typed call in the differential: read through a function pointer typed for an
// object, a float return comes back as a garbage pointer, which is what the first version of the host
// probe printed on the human body's confidence row.

// The measurements every one of these classes holds, in one place, so the five classes cannot disagree
// about what a member means. NSInteger and CGFloat, and no ivar for either angle's presence: the
// flags say whether the angle is there, exactly as the header's hasRollAngle/hasYawAngle do.
@interface AVMetadataBodyObject ()
@property (nonatomic) NSInteger charonBodyID;
@property (nonatomic) NSInteger charonObjectID;
@property (nonatomic) NSInteger charonFaceID;
@property (nonatomic) BOOL charonHasRollAngle;
@property (nonatomic) CGFloat charonRollAngle;
@property (nonatomic) BOOL charonHasYawAngle;
@property (nonatomic) CGFloat charonYawAngle;
@end

// The number a body object's objectID answers when no detector filled it in. Measured from the host's
// own instances; see the note above.
static const NSInteger CharonAVMetadataNoObject = -1;

@implementation AVMetadataBodyObject

@synthesize charonBodyID = _charonBodyID;
@synthesize charonObjectID = _charonObjectID;
@synthesize charonFaceID = _charonFaceID;
@synthesize charonHasRollAngle = _charonHasRollAngle;
@synthesize charonRollAngle = _charonRollAngle;
@synthesize charonHasYawAngle = _charonHasYawAngle;
@synthesize charonYawAngle = _charonYawAngle;

// A plain -init is what the differential calls, and it has to answer the measured default rather
// than a zero: this is the initializer behind every path that does not go through the port's own.
- (instancetype)init
{
    self = [super init];
    if (self) {
        _charonObjectID = CharonAVMetadataNoObject;
    }
    return self;
}

- (instancetype)charon_initWithBodyID:(NSInteger)bodyID
                             objectID:(NSInteger)objectID
                               faceID:(NSInteger)faceID
                            rollAngle:(CGFloat)rollAngle
                             yawAngle:(CGFloat)yawAngle
{
    self = ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("init"));
    if (self) {
        _charonBodyID = bodyID;
        _charonObjectID = objectID;
        _charonFaceID = faceID;
        _charonHasRollAngle = YES;
        _charonRollAngle = rollAngle;
        _charonHasYawAngle = YES;
        _charonYawAngle = yawAngle;
    }
    return self;
}

- (NSInteger)bodyID
{
    return self.charonBodyID;
}

- (NSInteger)objectID
{
    return self.charonObjectID;
}

- (NSInteger)faceID
{
    return self.charonFaceID;
}

- (BOOL)hasRollAngle
{
    return self.charonHasRollAngle;
}

- (CGFloat)rollAngle
{
    return self.charonRollAngle;
}

- (BOOL)hasYawAngle
{
    return self.charonHasYawAngle;
}

- (CGFloat)yawAngle
{
    return self.charonYawAngle;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] alloc] charon_initWithBodyID:self.bodyID objectID:self.objectID
                                                faceID:self.faceID rollAngle:self.rollAngle
                                               yawAngle:self.yawAngle];
}

- (BOOL)isEqual:(id)other
{
    if (other == self) {
        return YES;
    }
    if (![other isKindOfClass:[self class]]) {
        return NO;
    }
    AVMetadataBodyObject *that = other;
    return self.bodyID == that.bodyID && self.objectID == that.objectID
        && self.faceID == that.faceID && self.hasRollAngle == that.hasRollAngle
        && self.rollAngle == that.rollAngle && self.hasYawAngle == that.hasYawAngle
        && self.yawAngle == that.yawAngle;
}

- (NSUInteger)hash
{
    return (NSUInteger)(self.bodyID * 31 + self.objectID);
}

@end

// The three typed bodies share the base's members and add nothing: the header gives each the same six
// properties and no methods of its own, and the object type that tells a cat from a dog is the class
// itself. So one macro, three classes, and the base's initializer with the body id fixed at 0 - which
// is the number a body object has when nothing said otherwise, and the number a plain -init answers.
#define CHARON_AVMETADATA_BODY(cls) \
@implementation cls \
- (instancetype)charon_initWithObjectID:(NSInteger)objectID \
                                 faceID:(NSInteger)faceID \
                              rollAngle:(CGFloat)rollAngle \
                               yawAngle:(CGFloat)yawAngle \
{ \
    return [super charon_initWithBodyID:0 objectID:objectID faceID:faceID \
                             rollAngle:rollAngle yawAngle:yawAngle]; \
} \
@end

CHARON_AVMETADATA_BODY(AVMetadataCatBodyObject)
CHARON_AVMETADATA_BODY(AVMetadataDogBodyObject)
CHARON_AVMETADATA_BODY(AVMetadataHumanBodyObject)

#undef CHARON_AVMETADATA_BODY

// A salient object is the base's measurements with no body of its own, so it takes the same values
// without the body id and its class is the answer to "which object type" for the base shape. Its
// storage is its own: it subclasses AVMetadataObject, not AVMetadataBodyObject, so the base's
// extension is not in scope here and re-declaring those properties to share the base's would not
// compile ("property implementation must have its declaration in interface ... or one of its
// extensions"). Six properties, declared, is the honest shape for a class that holds the measurements
// itself.
@interface AVMetadataSalientObject ()
@property (nonatomic) NSInteger charonObjectID;
@property (nonatomic) NSInteger charonFaceID;
@property (nonatomic) BOOL charonHasRollAngle;
@property (nonatomic) CGFloat charonRollAngle;
@property (nonatomic) BOOL charonHasYawAngle;
@property (nonatomic) CGFloat charonYawAngle;
@end

@implementation AVMetadataSalientObject

@synthesize charonObjectID = _charonObjectID;
@synthesize charonFaceID = _charonFaceID;
@synthesize charonHasRollAngle = _charonHasRollAngle;
@synthesize charonRollAngle = _charonRollAngle;
@synthesize charonHasYawAngle = _charonHasYawAngle;
@synthesize charonYawAngle = _charonYawAngle;

- (instancetype)charon_initWithObjectID:(NSInteger)objectID
                                 faceID:(NSInteger)faceID
                              rollAngle:(CGFloat)rollAngle
                               yawAngle:(CGFloat)yawAngle
{
    self = ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("init"));
    if (self) {
        _charonObjectID = objectID;
        _charonFaceID = faceID;
        _charonHasRollAngle = YES;
        _charonRollAngle = rollAngle;
        _charonHasYawAngle = YES;
        _charonYawAngle = yawAngle;
    }
    return self;
}

- (NSInteger)objectID
{
    return self.charonObjectID;
}

- (NSInteger)faceID
{
    return self.charonFaceID;
}

- (BOOL)hasRollAngle
{
    return self.charonHasRollAngle;
}

- (CGFloat)rollAngle
{
    return self.charonRollAngle;
}

- (BOOL)hasYawAngle
{
    return self.charonHasYawAngle;
}

- (CGFloat)yawAngle
{
    return self.charonYawAngle;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] alloc] charon_initWithObjectID:self.objectID faceID:self.faceID
                                               rollAngle:self.rollAngle yawAngle:self.yawAngle];
}

- (BOOL)isEqual:(id)other
{
    if (other == self) {
        return YES;
    }
    if (![other isKindOfClass:[self class]]) {
        return NO;
    }
    AVMetadataSalientObject *that = other;
    return self.objectID == that.objectID && self.faceID == that.faceID
        && self.rollAngle == that.rollAngle && self.yawAngle == that.yawAngle;
}

- (NSUInteger)hash
{
    return (NSUInteger)self.objectID;
}

@end
