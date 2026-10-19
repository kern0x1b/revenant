#import "CharonVideoToolbox.h"
#import "VideoToolboxValueStore.h"

// The two protocols' accessors, and the seventeen classes' own. Every one is written out rather than
// @dynamic, for the reason the header gives: a class the port defines inherits the conformance its
// protocol declares, so a @dynamic in a class implementation would leave the compiler synthesising a
// getter that reads an ivar nothing ever writes. This file is the two protocols and the first class,
// and the other sixteen follow from it.
//
// A class property has no instance to keep the value on, so it is kept on the class itself - a
// property whose value belongs to the type rather than to an instance, which is what a class property
// means. The CMVideoDimensions pair is a struct, and a struct is held as an NSValue over its own bytes:
// it can be neither cast out of the store the way an object can nor put in a dictionary.

@implementation VTMotionBlurConfiguration

- (instancetype)initWithFrameWidth:(NSInteger)frameWidth
                       frameHeight:(NSInteger)frameHeight
                 usePrecomputedFlow:(BOOL)usePrecomputedFlow
             qualityPrioritization:(VTMotionBlurConfigurationQualityPrioritization)qualityPrioritization
                           revision:(VTMotionBlurConfigurationRevision)revision
{
    // The designated initialiser the SDK declares, and the only way to make one of these: -[C init] and
    // +[C new] are both NS_UNAVAILABLE, so until this exists there is no object and nothing to read a
    // value out of.
    //
    // Each argument is put in under the property's OWN name - the same string the accessor reads and the
    // same string the property walk and -charon_setValue:forKey: use - so there is one spelling of each
    // name and a value that was set is a value that reads back. The arguments are values the release can
    // be given: 1920x1080, flow computed, prioritisation 3, revision 1.
    self = [super init];
    if (!self)
        return nil;
    CharonValueSet(self, @(frameWidth), @"frameWidth");
    CharonValueSet(self, @(frameHeight), @"frameHeight");
    CharonValueSet(self, @(usePrecomputedFlow), @"usePrecomputedFlow");
    CharonValueSet(self, @(qualityPrioritization), @"qualityPrioritization");
    CharonValueSet(self, @(revision), @"revision");
    return self;
}


#pragma mark - The protocol's own properties

+ (BOOL)isSupported
{
    // `supported` is a CLASS property in the protocol (class, nonatomic, readonly, getter=isSupported),
    // so the accessor belongs to the class and this is a class method rather than an instance one.
    //
    // The answer is NO, and it is the answer rather than a default: SDK 26.2 documents this property as
    // "whether the SYSTEM SUPPORTS this processor", and objc-inventory.lua over the armv7 6.1.3 dyld
    // cache finds no VTFrameProcessor class and no VTFrameProcessor* symbol there - the seventeen
    // configuration and parameter classes arrived with iOS 26.0 and the ladder this package builds for
    // ends at 10.3.4. The effects are motion estimation, interpolation, super resolution and temporal
    // noise filtering, which need the Neural Engine no armv7 device has. So this is a hardware answer,
    // and a store nothing writes would be NO by accident rather than by measurement.
    return NO;
}

- (NSArray<NSNumber *> *)frameSupportedPixelFormats
{
    return (NSArray<NSNumber *> *)CharonValueStore(self)[@"frameSupportedPixelFormats"];
}

- (NSDictionary<NSString *, id> *)sourcePixelBufferAttributes
{
    return (NSDictionary<NSString *, id> *)CharonValueStore(self)[@"sourcePixelBufferAttributes"];
}

- (NSDictionary<NSString *, id> *)destinationPixelBufferAttributes
{
    return (NSDictionary<NSString *, id> *)CharonValueStore(self)[@"destinationPixelBufferAttributes"];
}

- (NSInteger)nextFrameCount
{
    return (NSInteger)[CharonValueStore(self)[@"nextFrameCount"] longLongValue];
}

- (NSInteger)previousFrameCount
{
    return (NSInteger)[CharonValueStore(self)[@"previousFrameCount"] longLongValue];
}

+ (CMVideoDimensions)maximumDimensions
{
    // A struct, and a class property: the boxed value belongs to the class.
    CMVideoDimensions value = {0, 0};
    NSValue *boxed = CharonValueStoreOfClass([self class])[@"maximumDimensions"];
    if (boxed)
        [boxed getValue:&value];
    return value;
}

+ (CMVideoDimensions)minimumDimensions
{
    CMVideoDimensions value = {0, 0};
    NSValue *boxed = CharonValueStoreOfClass([self class])[@"minimumDimensions"];
    if (boxed)
        [boxed getValue:&value];
    return value;
}

#pragma mark - This class's own properties

- (NSInteger)frameWidth
{
    return (NSInteger)[CharonValueStore(self)[@"frameWidth"] longLongValue];
}

- (NSInteger)frameHeight
{
    return (NSInteger)[CharonValueStore(self)[@"frameHeight"] longLongValue];
}

- (BOOL)usePrecomputedFlow
{
    return (BOOL)[CharonValueStore(self)[@"usePrecomputedFlow"] longLongValue];
}

- (VTMotionBlurConfigurationQualityPrioritization)qualityPrioritization
{
    return (VTMotionBlurConfigurationQualityPrioritization)[CharonValueStore(self)[@"qualityPrioritization"] longLongValue];
}

- (VTMotionBlurConfigurationRevision)revision
{
    return (VTMotionBlurConfigurationRevision)[CharonValueStore(self)[@"revision"] longLongValue];
}

+ (NSIndexSet *)supportedRevisions
{
    return (NSIndexSet *)CharonValueStoreOfClass([self class])[@"supportedRevisions"];
}

+ (VTMotionBlurConfigurationRevision)defaultRevision
{
    return (VTMotionBlurConfigurationRevision)[CharonValueStoreOfClass([self class])[@"defaultRevision"] longLongValue];
}

#pragma mark - Initialisation, the one the header leaves open

- (instancetype)initWithFrameWidth:(NSInteger)frameWidth
                          frameHeight:(NSInteger)frameHeight
                 usePrecomputedFlow:(BOOL)usePrecomputedFlow
              qualityPrioritization:(VTMotionBlurConfigurationQualityPrioritization)qualityPrioritization
{
    if ((self = [super init])) {
        CharonValueStore(self)[@"frameWidth"] = @(frameWidth);
        CharonValueStore(self)[@"frameHeight"] = @(frameHeight);
        CharonValueStore(self)[@"usePrecomputedFlow"] = @(usePrecomputedFlow);
        CharonValueStore(self)[@"qualityPrioritization"] = @(qualityPrioritization);
    }
    return self;
}

@end

// A class property's value has no instance to sit on, so the store hangs off the class object, under a
// key of the property's own name - the same string the instance store uses, so one rule covers both.
// This file exports NO C symbol of its own, and that is checked rather than assumed. It had one -
// CharonVideoToolboxSetOnClass - and `nm -g` over the eighteen objects of this library named it, while a
// search of the tree found exactly one reference: the definition itself. A library of this package
// exports only the names the registry lists, and the registry lists only names an SDK header declares;
// CharonValueStore.h records what that was measured to be on a built libFoundationBackports.dylib - six
// os_log* symbols exported, zero charon_ C symbols, zero Charon* classes. A dead entry point that
// violates the invariant it was written under is worse than no entry point, so it is gone.
//
// Nothing needs it: a value is put in through the store's own -charon_setValue:forKey: with the
// property's own name as the key, and a class property's value is the class's own store under that same
// name. CharonValueSetOnClass is in VideoToolboxValueStore.h, static inline, for a class property's
// accessors to read.
