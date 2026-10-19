#ifndef CHARON_AVF_DESCRIPTOR_CONSTRUCTION_H
#define CHARON_AVF_DESCRIPTOR_CONSTRUCTION_H

#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>

@interface AVPlayerMediaSelectionCriteria (CharonAVFDescriptorConstruction)
- (instancetype)charon_initWithPreferredLanguages:(NSArray<NSString *> *)preferredLanguages
                   preferredMediaCharacteristics:(NSArray<NSString *> *)preferredMediaCharacteristics
                       principalMediaCharacteristics:(NSArray<NSString *> *)principalMediaCharacteristics
    __attribute__((objc_method_family(init)));
- (NSArray<NSString *> *)charon_preferredLanguages;
- (void)charon_setPreferredLanguages:(NSArray<NSString *> *)preferredLanguages;
- (NSArray<NSString *> *)charon_preferredMediaCharacteristics;
- (void)charon_setPreferredMediaCharacteristics:(NSArray<NSString *> *)preferredMediaCharacteristics;
- (NSArray<NSString *> *)charon_principalMediaCharacteristics;
- (void)charon_setPrincipalMediaCharacteristics:(NSArray<NSString *> *)principalMediaCharacteristics;
@end

@interface AVCaptureBracketedStillImageSettings (CharonAVFDescriptorConstruction)
- (instancetype)charon_initWithExposureTargetBias:(float)exposureTargetBias
                                   exposureDuration:(CMTime)exposureDuration
                                               ISO:(float)iso
    __attribute__((objc_method_family(init)));
- (float)charon_exposureTargetBias;
- (void)charon_setExposureTargetBias:(float)exposureTargetBias;
- (CMTime)charon_exposureDuration;
- (void)charon_setExposureDuration:(CMTime)exposureDuration;
- (float)charon_ISO;
- (void)charon_setISO:(float)iso;
@end

@interface AVMediaSelection (CharonAVFDescriptorConstruction)
- (instancetype)charon_initWithSelectedOptionsByGroup:(NSDictionary<NSString *, AVMediaSelectionOption *> *)selected
    __attribute__((objc_method_family(init)));
- (NSDictionary<NSString *, AVMediaSelectionOption *> *)charon_selected;
- (void)charon_setSelected:(NSDictionary<NSString *, AVMediaSelectionOption *> *)selected;
@end

#endif
