#ifndef REVENANT_AVMETADATA_CONSTRUCTION_H
#define REVENANT_AVMETADATA_CONSTRUCTION_H

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

@interface AVMetadataItemFilter (RevenantAVMetadataConstruction)
+ (instancetype)revenant_metadataItemFilterWithIdentifiers:(NSArray<AVMetadataIdentifier> *)identifiers;
- (instancetype)revenant_initWithIdentifiers:(NSArray<AVMetadataIdentifier> *)identifiers
    __attribute__((objc_method_family(init)));
@property (nonatomic, readonly, copy) NSArray<AVMetadataIdentifier> *identifiers;
@property (nonatomic, readonly, copy) NSArray<AVMetadataIdentifier> *allowList;
@end

@interface AVMetadataGroup (RevenantAVMetadataConstruction)
- (instancetype)revenant_initWithItems:(NSArray<AVMetadataItem *> *)items
                           timeRange:(CMTimeRange)timeRange
    __attribute__((objc_method_family(init)));
@end

extern const void *RevenantAVMetadataTimedItemsKey;
extern const void *RevenantAVMetadataTimedRangeKey;

@interface AVTimedMetadataGroup (RevenantAVMetadataConstruction)
- (instancetype)revenant_initWithItems:(NSArray<AVMetadataItem *> *)items
                           timeRange:(CMTimeRange)timeRange
    __attribute__((objc_method_family(init)));
@end

@interface AVDateRangeMetadataGroup (RevenantAVMetadataConstruction)
- (instancetype)revenant_initWithItems:(NSArray<AVMetadataItem *> *)items
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
    __attribute__((objc_method_family(init)));
@end

@interface AVMetadataItemValueRequest (RevenantAVMetadataConstruction)
- (instancetype)revenant_initWithSpecifier:(id)specifier
    __attribute__((objc_method_family(init)));
@end

@interface AVMetadataBodyObject (RevenantAVMetadataConstruction)
- (instancetype)revenant_initWithBodyID:(NSInteger)bodyID
                             objectID:(NSInteger)objectID
                               faceID:(NSInteger)faceID
                            rollAngle:(CGFloat)rollAngle
                             yawAngle:(CGFloat)yawAngle
    __attribute__((objc_method_family(init)));
@end

#define REVENANT_AVMETADATA_BODY_CONSTRUCTION(cls) \
    @interface cls (RevenantAVMetadataConstruction) \
    - (instancetype)revenant_initWithObjectID:(NSInteger)objectID \
                                     faceID:(NSInteger)faceID \
                                  rollAngle:(CGFloat)rollAngle \
                                   yawAngle:(CGFloat)yawAngle \
    __attribute__((objc_method_family(init))); \
    @end

REVENANT_AVMETADATA_BODY_CONSTRUCTION(AVMetadataCatBodyObject)
REVENANT_AVMETADATA_BODY_CONSTRUCTION(AVMetadataDogBodyObject)
REVENANT_AVMETADATA_BODY_CONSTRUCTION(AVMetadataHumanBodyObject)

#undef REVENANT_AVMETADATA_BODY_CONSTRUCTION

@interface AVMetadataSalientObject (RevenantAVMetadataConstruction)
- (instancetype)revenant_initWithObjectID:(NSInteger)objectID
                                 faceID:(NSInteger)faceID
                              rollAngle:(CGFloat)rollAngle
                               yawAngle:(CGFloat)yawAngle
    __attribute__((objc_method_family(init)));
@end

#endif
