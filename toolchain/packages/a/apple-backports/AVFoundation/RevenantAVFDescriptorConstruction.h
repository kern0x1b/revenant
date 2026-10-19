#ifndef REVENANT_AVF_DESCRIPTOR_CONSTRUCTION_H
#define REVENANT_AVF_DESCRIPTOR_CONSTRUCTION_H

#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>

@interface AVPlayerMediaSelectionCriteria (RevenantAVFDescriptorConstruction)
- (instancetype)revenant_initWithPreferredLanguages:(NSArray<NSString *> *)preferredLanguages
                   preferredMediaCharacteristics:(NSArray<NSString *> *)preferredMediaCharacteristics
                       principalMediaCharacteristics:(NSArray<NSString *> *)principalMediaCharacteristics
    __attribute__((objc_method_family(init)));
- (NSArray<NSString *> *)revenant_preferredLanguages;
- (void)revenant_setPreferredLanguages:(NSArray<NSString *> *)preferredLanguages;
- (NSArray<NSString *> *)revenant_preferredMediaCharacteristics;
- (void)revenant_setPreferredMediaCharacteristics:(NSArray<NSString *> *)preferredMediaCharacteristics;
- (NSArray<NSString *> *)revenant_principalMediaCharacteristics;
- (void)revenant_setPrincipalMediaCharacteristics:(NSArray<NSString *> *)principalMediaCharacteristics;
@end

@interface AVCaptureBracketedStillImageSettings (RevenantAVFDescriptorConstruction)
- (instancetype)revenant_initWithExposureTargetBias:(float)exposureTargetBias
                                   exposureDuration:(CMTime)exposureDuration
                                               ISO:(float)iso
    __attribute__((objc_method_family(init)));
- (float)revenant_exposureTargetBias;
- (void)revenant_setExposureTargetBias:(float)exposureTargetBias;
- (CMTime)revenant_exposureDuration;
- (void)revenant_setExposureDuration:(CMTime)exposureDuration;
- (float)revenant_ISO;
- (void)revenant_setISO:(float)iso;
@end

@interface AVMediaSelection (RevenantAVFDescriptorConstruction)
- (instancetype)revenant_initWithSelectedOptionsByGroup:(NSDictionary<NSString *, AVMediaSelectionOption *> *)selected
    __attribute__((objc_method_family(init)));
- (NSDictionary<NSString *, AVMediaSelectionOption *> *)revenant_selected;
- (void)revenant_setSelected:(NSDictionary<NSString *, AVMediaSelectionOption *> *)selected;
@end

#endif
