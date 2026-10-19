// The port's own construction of the configuration and descriptor classes.
//
// The same shape as CharonHomeKitConstruction.h and CharonAVMetadataConstruction.h: a method may
// only assign `self` when it is in the `init` method family, and clang decides that from the
// attribute and not the spelling, so a port-owned selector needs `objc_method_family(init)` under a
// name the port owns.
//
// **The storage is associated and keyed on a string, not an ivar and not a property.** The classes
// below belong to the release from their own rung up, and a port may not add an ivar to a release's
// class - and a property declared in a category cannot be synthesized in the class implementation,
// which is the error this header's first version produced. So each value is reached through a
// getter/setter pair implemented with objc_getAssociatedObject, keyed on a string, and the category
// that carries the members which arrived AFTER the rung reads and writes the same pair. Two files,
// one value, and no way for them to disagree.
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
