// MPNowPlayingInfoLanguageOption and MPNowPlayingInfoLanguageOptionGroup, the two 9.0 classes. Nothing
// invented: every value is stored as the caller gave it, or read out of the release's own
// AVMediaSelectionOption / AVMediaSelectionGroup.
//
// MEASURED, class-scoped, with tools/corpus/objc-inventory.lua over the armv7 dyld shared caches of
// 6.1.3 and 4.3. Each read carried a control in the same run: MPVolumeView and MPMediaPlaylist read
// PRESENT on both ends, and MPNowPlayingInfoCenter reads PRESENT at 6.1.3 and ABSENT at 4.3, so this
// reader discriminates instead of answering yes to everything it is shown.
//
//   name                                  6.1.3      4.3
//   MPNowPlayingInfoLanguageOption          ABSENT     ABSENT
//   MPNowPlayingInfoLanguageOptionGroup     ABSENT     ABSENT
//   AVMediaSelectionOption                  PRESENT    ABSENT
//   AVMediaSelectionGroup                   PRESENT    ABSENT
//
// The two classes are new code and cannot shadow anything - no release has an object of that name -
// which is what lets them be `implemented` rather than `absent`: `absent` is for a row whose answer
// needs a thing the device lacks, and nothing here needs one. What makes this more than a declaration
// is the second half of that table, read at CLASS level. The whole-cache selector list (113981 DISTINCT
// NAMES) could not have decided it: a name is on one line if ANY class anywhere declares it, so a one
// there says nothing about the owner and only a zero would mean absence.
//
//   AVMediaSelectionOption's own 24 instance methods: -locale, -mediaType, -hasMediaCharacteristic:,
//   -displaysNonForcedSubtitles, -isPlayable, -commonMetadata, -group, -dictionary, -optionID, and
//   -_title (the title accessor is PRIVATE on this release; there is no -title, which is checked below
//   rather than assumed, and is why no display name is read out of an option here).
//   AVMediaSelectionGroup's own 18: -options, -allowsEmptySelection, -_defaultOption, -asset,
//   -_isAlternateTrackGroup, -_isKeyValueGroup, -_mediaType.
//
// The two "automatic" accessors are the one place this file answers rather than stores, and the answer
// is NO. MPNowPlayingInfoLanguageOption.h:56-63 documents each as the option that stands for the
// best legible or audible choice under the system preferences, each pointing at
// AVPlayerItem-selectMediaOptionAutomaticallyInMediaSelectionGroup: - so what each asks is whether the
// receiver IS that special case, an option the system inserts into a group to mean "choose for me", and
// not whether it is an ordinary option of a kind. The system's own class says the same thing: Apple's
// MediaPlayer on this machine answers NO to both accessors for every option its own designated
// initialiser can build - 34 options over both types (the type round-trips, so the grid measured
// something), thirteen languageTag values including the literal MPLangaugeOptionAutoLangaugeTag the
// header's comment names, a nil tag, nil and empty characteristics, displayName and identifier, and the
// same option installed as a group's default. Zero YES. The measurement, its control and the table are
// in tests/backports/host/mp-language-option and facts/MediaPlayer/LanguageOptions.md.
//
// This port has no system-created option either: the class is defined here, so every option that exists
// is one the application built, and none of those is the special case. An earlier version of this file
// answered from the stored TYPE on the strength of the header's comment; the measurement above is what
// refutes it, and an application that gates on these accessors is told the truth instead of being handed
// an option Apple would not call automatic.
//
// One object per release: this file is the 9.0 API of these two classes. MPChangeLanguageOptionCommandEvent90.m,
// already on main, declares an `MPNowPlayingInfoLanguageOption *` property; this file is what makes
// that property's type a real class rather than a nil pointer.

#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
// MPMediaItemStandin.h declares both classes and their full contract, and it is the ONLY place a
// stand-in build sees them declared. A second @interface for either name in this file is a duplicate
// definition and does not compile - a first draft of this file carried its own restatement of the
// contract and clang rejected it with "duplicate interface definition for class
// 'MPNowPlayingInfoLanguageOption'", naming MPMediaItemStandin.h:47 as the earlier one. The stand-in
// header was already carrying a one-accessor version of this class, because MPChangeLanguageOptionCommandEvent90.m
// needs a type for its `languageOption` property; that declaration is the one, and it now carries the
// whole contract rather than a stub.
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

@implementation MPNowPlayingInfoLanguageOption

// The ivars are the header's readonly properties' backing storage, synthesised once here so that
// removing an explicit accessor below is a change of behaviour rather than a silent one.
@synthesize languageOptionType = _languageOptionType;
@synthesize languageTag = _languageTag;
@synthesize languageOptionCharacteristics = _languageOptionCharacteristics;
@synthesize displayName = _displayName;
@synthesize identifier = _identifier;

// The header's designated initializer, quoted from MPNowPlayingInfoLanguageOption.h:49-54:
//
//   - (instancetype)initWithType:(MPNowPlayingInfoLanguageOptionType)languageOptionType
//                    languageTag:(NSString *)languageTag
//                characteristics:(nullable NSArray<NSString *> *)languageOptionCharacteristics
//                    displayName:(NSString *)displayName
//                     identifier:(NSString *)identifier;
//
// Every value is stored as given, because the class is a value holder: there is no device state behind
// any of these five, and inventing one would be the failure this port exists to avoid. The two arrays
// and strings are COPIED - the header takes an NSArray the caller owns, and the option holds it past
// the call, so a caller that mutates its own array afterwards must not change what the option reads.
// The accessors are the header's readonly ones, so there is no setter for a copy to fall out of step with.
- (instancetype)initWithType:(MPNowPlayingInfoLanguageOptionType)languageOptionType
                 languageTag:(NSString *)languageTag
             characteristics:(nullable NSArray<NSString *> *)languageOptionCharacteristics
                 displayName:(NSString *)displayName
                  identifier:(NSString *)identifier {
    self = [super init];
    if (self) {
        _languageOptionType = languageOptionType;
        _languageTag = [languageTag copy];
        _languageOptionCharacteristics = [languageOptionCharacteristics copy];
        _displayName = [displayName copy];
        _identifier = [identifier copy];
    }
    return self;
}

// The header's five readonly accessors, written out rather than left to the synthesiser, so that what a
// caller reads is this file's code and removing the @synthesize is not a silent change of behaviour.
- (MPNowPlayingInfoLanguageOptionType)languageOptionType {
    return _languageOptionType;
}

- (nullable NSString *)languageTag {
    return _languageTag;
}

- (nullable NSArray<NSString *> *)languageOptionCharacteristics {
    return _languageOptionCharacteristics;
}

- (nullable NSString *)displayName {
    return _displayName;
}

- (nullable NSString *)identifier {
    return _identifier;
}

// The two automatic accessors, read from the header at :56-63, each documented as a special case that
// stands for the best legible or audible language option given the system preferences, and
// each pointing at AVPlayerItem-selectMediaOptionAutomaticallyInMediaSelectionGroup:.
//
// NO, because the receiver is never that special case: it is an option the application built through
// the designated initialiser above, and the option the system inserts to mean "choose for me" is not one
// a caller can build. Measured, not assumed - Apple's own class answers NO for all 34 options its own
// initialiser can build, over both types and thirteen tags and the nil tag (the table is in the header
// of this file and in facts/MediaPlayer/LanguageOptions.md). A caller that wants the release's own
// "choose for me" is served by -[AVPlayerItem selectMediaOptionAutomaticallyInMediaSelectionGroup:],
// which this port carries at its own release.
- (BOOL)isAutomaticLegibleLanguageOption {
    return NO;
}

- (BOOL)isAutomaticAudibleLanguageOption {
    return NO;
}

@end

@implementation MPNowPlayingInfoLanguageOptionGroup

@synthesize languageOptions = _languageOptions;
@synthesize defaultLanguageOption = _defaultLanguageOption;
@synthesize allowEmptySelection = _allowEmptySelection;

// The header's designated initializer, quoted from MPNowPlayingInfoLanguageOption.h:94-96:
//
//   - (instancetype)initWithLanguageOptions:(NSArray<MPNowPlayingInfoLanguageOption *> *)languageOptions
//                     defaultLanguageOption:(nullable MPNowPlayingInfoLanguageOption *)defaultLanguageOption
//                       allowEmptySelection:(BOOL)allowEmptySelection;
//
// The header describes the group as one whose language options exclude one another, in which only one
// option may be active at once (:86-87). Nothing here enforces that, because
// this object does not decide which option is active - it holds the set and the one the caller marked
// active. Enforcing exclusivity would mean silently dropping options the caller passed, which is a
// different API from the one Apple declares.
- (instancetype)initWithLanguageOptions:(NSArray<MPNowPlayingInfoLanguageOption *> *)languageOptions
                  defaultLanguageOption:(nullable MPNowPlayingInfoLanguageOption *)defaultLanguageOption
                    allowEmptySelection:(BOOL)allowEmptySelection {
    self = [super init];
    if (self) {
        _languageOptions = [languageOptions copy];
        _defaultLanguageOption = defaultLanguageOption;
        _allowEmptySelection = allowEmptySelection;
    }
    return self;
}

- (NSArray<MPNowPlayingInfoLanguageOption *> *)languageOptions {
    return _languageOptions;
}

- (nullable MPNowPlayingInfoLanguageOption *)defaultLanguageOption {
    return _defaultLanguageOption;
}

- (BOOL)allowEmptySelection {
    return _allowEmptySelection;
}

@end
