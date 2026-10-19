#ifndef CHARON_AVMETADATA_CONSTRUCTION_H
#define CHARON_AVMETADATA_CONSTRUCTION_H

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

@interface AVMetadataItemFilter (CharonAVMetadataConstruction)
+ (instancetype)charon_metadataItemFilterWithIdentifiers:(NSArray<AVMetadataIdentifier> *)identifiers;
- (instancetype)charon_initWithIdentifiers:(NSArray<AVMetadataIdentifier> *)identifiers
    __attribute__((objc_method_family(init)));
@property (nonatomic, readonly, copy) NSArray<AVMetadataIdentifier> *identifiers;
@property (nonatomic, readonly, copy) NSArray<AVMetadataIdentifier> *allowList;
@end

@interface AVMetadataGroup (CharonAVMetadataConstruction)
- (instancetype)charon_initWithItems:(NSArray<AVMetadataItem *> *)items
                           timeRange:(CMTimeRange)timeRange
    __attribute__((objc_method_family(init)));
@end

extern const void *CharonAVMetadataTimedItemsKey;
extern const void *CharonAVMetadataTimedRangeKey;

@interface AVTimedMetadataGroup (CharonAVMetadataConstruction)
- (instancetype)charon_initWithItems:(NSArray<AVMetadataItem *> *)items
                           timeRange:(CMTimeRange)timeRange
    __attribute__((objc_method_family(init)));
@end

@interface AVDateRangeMetadataGroup (CharonAVMetadataConstruction)
- (instancetype)charon_initWithItems:(NSArray<AVMetadataItem *> *)items
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
    __attribute__((objc_method_family(init)));
@end

@interface AVMetadataItemValueRequest (CharonAVMetadataConstruction)
- (instancetype)charon_initWithSpecifier:(id)specifier
    __attribute__((objc_method_family(init)));
@end

@interface AVMetadataBodyObject (CharonAVMetadataConstruction)
- (instancetype)charon_initWithBodyID:(NSInteger)bodyID
                             objectID:(NSInteger)objectID
                               faceID:(NSInteger)faceID
                            rollAngle:(CGFloat)rollAngle
                             yawAngle:(CGFloat)yawAngle
    __attribute__((objc_method_family(init)));
@end

#define CHARON_AVMETADATA_BODY_CONSTRUCTION(cls) \
    @interface cls (CharonAVMetadataConstruction) \
    - (instancetype)charon_initWithObjectID:(NSInteger)objectID \
                                     faceID:(NSInteger)faceID \
                                  rollAngle:(CGFloat)rollAngle \
                                   yawAngle:(CGFloat)yawAngle \
    __attribute__((objc_method_family(init))); \
    @end

CHARON_AVMETADATA_BODY_CONSTRUCTION(AVMetadataCatBodyObject)
CHARON_AVMETADATA_BODY_CONSTRUCTION(AVMetadataDogBodyObject)
CHARON_AVMETADATA_BODY_CONSTRUCTION(AVMetadataHumanBodyObject)

#undef CHARON_AVMETADATA_BODY_CONSTRUCTION

@interface AVMetadataSalientObject (CharonAVMetadataConstruction)
- (instancetype)charon_initWithObjectID:(NSInteger)objectID
                                 faceID:(NSInteger)faceID
                              rollAngle:(CGFloat)rollAngle
                               yawAngle:(CGFloat)yawAngle
    __attribute__((objc_method_family(init)));
@end

#endif
