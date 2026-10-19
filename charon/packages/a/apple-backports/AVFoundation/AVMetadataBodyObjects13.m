#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "CharonAVMetadataConstruction.h"

@interface AVMetadataBodyObject ()
@property (nonatomic) NSInteger charonBodyID;
@property (nonatomic) NSInteger charonObjectID;
@property (nonatomic) NSInteger charonFaceID;
@property (nonatomic) BOOL charonHasRollAngle;
@property (nonatomic) CGFloat charonRollAngle;
@property (nonatomic) BOOL charonHasYawAngle;
@property (nonatomic) CGFloat charonYawAngle;
@end

static const NSInteger CharonAVMetadataNoObject = -1;

@implementation AVMetadataBodyObject

@synthesize charonBodyID = _charonBodyID;
@synthesize charonObjectID = _charonObjectID;
@synthesize charonFaceID = _charonFaceID;
@synthesize charonHasRollAngle = _charonHasRollAngle;
@synthesize charonRollAngle = _charonRollAngle;
@synthesize charonHasYawAngle = _charonHasYawAngle;
@synthesize charonYawAngle = _charonYawAngle;

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
