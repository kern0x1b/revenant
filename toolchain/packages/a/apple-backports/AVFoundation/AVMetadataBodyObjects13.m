#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "RevenantAVMetadataConstruction.h"

@interface AVMetadataBodyObject ()
@property (nonatomic) NSInteger revenantBodyID;
@property (nonatomic) NSInteger revenantObjectID;
@property (nonatomic) NSInteger revenantFaceID;
@property (nonatomic) BOOL revenantHasRollAngle;
@property (nonatomic) CGFloat revenantRollAngle;
@property (nonatomic) BOOL revenantHasYawAngle;
@property (nonatomic) CGFloat revenantYawAngle;
@end

static const NSInteger RevenantAVMetadataNoObject = -1;

@implementation AVMetadataBodyObject

@synthesize revenantBodyID = _revenantBodyID;
@synthesize revenantObjectID = _revenantObjectID;
@synthesize revenantFaceID = _revenantFaceID;
@synthesize revenantHasRollAngle = _revenantHasRollAngle;
@synthesize revenantRollAngle = _revenantRollAngle;
@synthesize revenantHasYawAngle = _revenantHasYawAngle;
@synthesize revenantYawAngle = _revenantYawAngle;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _revenantObjectID = RevenantAVMetadataNoObject;
    }
    return self;
}

- (instancetype)revenant_initWithBodyID:(NSInteger)bodyID
                             objectID:(NSInteger)objectID
                               faceID:(NSInteger)faceID
                            rollAngle:(CGFloat)rollAngle
                             yawAngle:(CGFloat)yawAngle
{
    self = ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("init"));
    if (self) {
        _revenantBodyID = bodyID;
        _revenantObjectID = objectID;
        _revenantFaceID = faceID;
        _revenantHasRollAngle = YES;
        _revenantRollAngle = rollAngle;
        _revenantHasYawAngle = YES;
        _revenantYawAngle = yawAngle;
    }
    return self;
}

- (NSInteger)bodyID
{
    return self.revenantBodyID;
}

- (NSInteger)objectID
{
    return self.revenantObjectID;
}

- (NSInteger)faceID
{
    return self.revenantFaceID;
}

- (BOOL)hasRollAngle
{
    return self.revenantHasRollAngle;
}

- (CGFloat)rollAngle
{
    return self.revenantRollAngle;
}

- (BOOL)hasYawAngle
{
    return self.revenantHasYawAngle;
}

- (CGFloat)yawAngle
{
    return self.revenantYawAngle;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] alloc] revenant_initWithBodyID:self.bodyID objectID:self.objectID
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

#define REVENANT_AVMETADATA_BODY(cls) \
@implementation cls \
- (instancetype)revenant_initWithObjectID:(NSInteger)objectID \
                                 faceID:(NSInteger)faceID \
                              rollAngle:(CGFloat)rollAngle \
                               yawAngle:(CGFloat)yawAngle \
{ \
    return [super revenant_initWithBodyID:0 objectID:objectID faceID:faceID \
                             rollAngle:rollAngle yawAngle:yawAngle]; \
} \
@end

REVENANT_AVMETADATA_BODY(AVMetadataCatBodyObject)
REVENANT_AVMETADATA_BODY(AVMetadataDogBodyObject)
REVENANT_AVMETADATA_BODY(AVMetadataHumanBodyObject)

#undef REVENANT_AVMETADATA_BODY

@interface AVMetadataSalientObject ()
@property (nonatomic) NSInteger revenantObjectID;
@property (nonatomic) NSInteger revenantFaceID;
@property (nonatomic) BOOL revenantHasRollAngle;
@property (nonatomic) CGFloat revenantRollAngle;
@property (nonatomic) BOOL revenantHasYawAngle;
@property (nonatomic) CGFloat revenantYawAngle;
@end

@implementation AVMetadataSalientObject

@synthesize revenantObjectID = _revenantObjectID;
@synthesize revenantFaceID = _revenantFaceID;
@synthesize revenantHasRollAngle = _revenantHasRollAngle;
@synthesize revenantRollAngle = _revenantRollAngle;
@synthesize revenantHasYawAngle = _revenantHasYawAngle;
@synthesize revenantYawAngle = _revenantYawAngle;

- (instancetype)revenant_initWithObjectID:(NSInteger)objectID
                                 faceID:(NSInteger)faceID
                              rollAngle:(CGFloat)rollAngle
                               yawAngle:(CGFloat)yawAngle
{
    self = ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("init"));
    if (self) {
        _revenantObjectID = objectID;
        _revenantFaceID = faceID;
        _revenantHasRollAngle = YES;
        _revenantRollAngle = rollAngle;
        _revenantHasYawAngle = YES;
        _revenantYawAngle = yawAngle;
    }
    return self;
}

- (NSInteger)objectID
{
    return self.revenantObjectID;
}

- (NSInteger)faceID
{
    return self.revenantFaceID;
}

- (BOOL)hasRollAngle
{
    return self.revenantHasRollAngle;
}

- (CGFloat)rollAngle
{
    return self.revenantRollAngle;
}

- (BOOL)hasYawAngle
{
    return self.revenantHasYawAngle;
}

- (CGFloat)yawAngle
{
    return self.revenantYawAngle;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] alloc] revenant_initWithObjectID:self.objectID faceID:self.faceID
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
