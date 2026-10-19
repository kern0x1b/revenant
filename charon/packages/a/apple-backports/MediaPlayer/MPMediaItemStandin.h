// The stand-in the contract check compiles the port's own source against: an item that answers
// valueForProperty: from a table, which is the whole of what the 26.2 header says the properties are
// conveniences over. No framework, so the check measures the port's code and not this Mac's MediaPlayer -
// whose MPMediaItem declares albumTrackNumber already, so a category compiled against it would be
// measuring the host and would look like a clobber.
#import <Foundation/Foundation.h>

// The framework spells the identifier type as a typedef over NSNumber; the stand-in must too,
// or the generated getters do not compile off-target.
typedef NSNumber *MPMediaEntityPersistentID;

@interface MPMediaItem : NSObject
- (id)valueForProperty:(NSString *)property;
@end

@interface MPMediaItem (Charon70)
@property (nonatomic, readonly) NSUInteger albumTrackNumber;
@property (nonatomic, readonly) NSUInteger discNumber;
@end

// The artwork class, as the release declares it, so the port's subclass has something to override and
// the check can see the override happen. The release's own imageWithSize: answers nil here, which is
// what makes the override observable rather than accidental.
@class UIImage;

@interface MPMediaItemArtwork : NSObject
- (instancetype)initWithImage:(id)image;
- (UIImage *)imageWithSize:(CGSize)size;
- (CGRect)bounds;
@end

@interface MPMediaItemArtwork (Charon100)
- (instancetype)initWithBoundsSize:(CGSize)boundsSize requestHandler:(UIImage *(^)(CGSize size))requestHandler;
@end

// The 9.0 command event's two types, and the base the port carries it over, so the check can compile
// the port's own source for a class the release does not have.
typedef NSUInteger MPChangeLanguageOptionSetting;
// The 8.0 repeat and shuffle events' types, spelled with the cases MPRemoteControlTypes.h gives them:
// MPRepeatTypeOff/One/All and MPShuffleTypeOff/Items/Collections, neither of which has an "unknown"
// case, so a stand-in that added one would let the port's own source compile against a type the SDK does
// not declare and the check would measure that instead of the port.
typedef NSInteger MPRepeatType;
enum { MPRepeatTypeOff = 0, MPRepeatTypeOne = 1, MPRepeatTypeAll = 2 };
typedef NSInteger MPShuffleType;
enum { MPShuffleTypeOff = 0, MPShuffleTypeItems = 1, MPShuffleTypeCollections = 2 };
// The 9.0 language option and its group, at the contract MPNowPlayingInfoLanguageOption90.m implements.
// It was already here as a bare NSObject with one accessor, because MPChangeLanguageOptionCommandEvent90.m
// needs a type for its `languageOption` property to compile against and the framework's own class is
// absent on this release. It now carries the full contract, so that object is the ONE place a stand-in
// build sees these classes declared - a second @interface for either name in the .m is a duplicate
// definition and does not compile, which is what a first draft of that object did and what this header
// is extended to prevent. The type and the two cases are spelled as MPNowPlayingInfoLanguageOption.h
// spells them; nothing here is invented to make a check pass.
typedef NSUInteger MPNowPlayingInfoLanguageOptionType;
enum { MPNowPlayingInfoLanguageOptionTypeAudible = 0, MPNowPlayingInfoLanguageOptionTypeLegible = 1 };
@interface MPNowPlayingInfoLanguageOption : NSObject
- (instancetype)initWithType:(MPNowPlayingInfoLanguageOptionType)languageOptionType
                 languageTag:(NSString *)languageTag
             characteristics:(NSArray<NSString *> *)languageOptionCharacteristics
                 displayName:(NSString *)displayName
                  identifier:(NSString *)identifier;
@property (nonatomic, readonly) MPNowPlayingInfoLanguageOptionType languageOptionType;
@property (nonatomic, readonly) NSString *languageTag;
@property (nonatomic, readonly) NSArray<NSString *> *languageOptionCharacteristics;
@property (nonatomic, readonly) NSString *displayName;
@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) BOOL isAutomaticLegibleLanguageOption;
@property (nonatomic, readonly) BOOL isAutomaticAudibleLanguageOption;
@end

@interface MPNowPlayingInfoLanguageOptionGroup : NSObject
- (instancetype)initWithLanguageOptions:(NSArray<MPNowPlayingInfoLanguageOption *> *)languageOptions
                  defaultLanguageOption:(MPNowPlayingInfoLanguageOption *)defaultLanguageOption
                    allowEmptySelection:(BOOL)allowEmptySelection;
@property (nonatomic, readonly) NSArray<MPNowPlayingInfoLanguageOption *> *languageOptions;
@property (nonatomic, readonly) MPNowPlayingInfoLanguageOption *defaultLanguageOption;
@property (nonatomic, readonly) BOOL allowEmptySelection;
@end
// What MPRemoteCommandCenter71.m needs to parse, transcribed from the SDK's own headers:
// MPRemoteCommandHandlerStatus and its cases from MediaPlayer.framework's MPRemoteCommand.h, the
// UIEventSubtypeRemoteControl* constants from UIKit's UIEvent.h, and the command classes from the
// framework's own headers.
//
// Why these are here: MPRemoteCommandCenter71.m guards its include of this header behind
// CHARON_MEDIAPLAYER_STANDIN, so a host check may include the port's object and have the port's own code
// measured rather than this Mac's MediaPlayer -- which has no MPSeekCommandEvent, MPSkipIntervalCommand
// or MPRatingCommand at all, and whose MPMediaItem declares albumTrackNumber, so a category compiled
// against it would look like a clobber. Without these declarations that include does not compile at all,
// and coordination/crutches.md's "MediaPlayer's command events have no host check" is the entry: it is
// still open, and the rest of what MPRemoteCommandCenter71.m needs -- MPSeekCommandEvent and
// MPSeekCommandEventType, MPRemoteCommand's own members, MPRemoteCommandCenter's -- is named there too.
//
// Nothing here changes the armv7 object. This header is read only when the .m that includes it is
// compiled with CHARON_MEDIAPLAYER_STANDIN defined, which is a host check and never a device build.
typedef NS_ENUM(NSInteger, MPRemoteCommandHandlerStatus) {
    MPRemoteCommandHandlerStatusSuccess = 0,
    MPRemoteCommandHandlerStatusUnknownError = 1,
    MPRemoteCommandHandlerStatusCommandFailed = 2,
    MPRemoteCommandHandlerStatusNoSuchContent = 100,
    MPRemoteCommandHandlerStatusNoActionableNowPlayingItem = 110,
    MPRemoteCommandHandlerStatusCommandInterruptionTimedOut = 120,
    MPRemoteCommandHandlerStatusCommandInterruptionRunLoop = 121,
    MPRemoteCommandHandlerStatusInterrupted = 130,
    MPRemoteCommandHandlerStatusNotApplicable = 140,
    MPRemoteCommandHandlerStatusTimedOut = 150,
    MPRemoteCommandHandlerStatusDenied = 160,
};

// The UIEventSubtypeRemoteControl* constants this object's switch runs on are declared by the
// UIKit stand-in beside this one (standin/UIKit/UIKit.h), which is where UIKit's own headers
// declare them; a second set of enumerators here and the two headers are on the include path
// together is a redefinition, measured.

// The base and the event, then the classes that subclass them: declared in this order because the
// command classes below name both as their superclass and C reads a declaration in order.
@interface MPRemoteCommand : NSObject
- (instancetype)initWithCommand:(id)command;
@property (nonatomic, assign, readonly, getter=isEnabled) BOOL enabled;
@end

@interface MPRemoteCommandEvent : NSObject
- (instancetype)initWithCommand:(MPRemoteCommand *)command;
@property (nonatomic, strong, readonly) MPRemoteCommand *command;
@property (nonatomic, assign, readonly) NSTimeInterval timestamp;
@end

// MPSeekCommandEvent and the enumeration its one property is of, from MediaPlayer.framework's
// MPRemoteCommandEvent.h. The cases' numbers are the SDK's own.
typedef NS_ENUM(NSInteger, MPSeekCommandEventType) {
    MPSeekCommandEventTypeBeginSeeking = 0,
    MPSeekCommandEventTypeEndSeeking = 1,
};

@interface MPSeekCommandEvent : MPRemoteCommandEvent
@property (nonatomic, assign, readonly) MPSeekCommandEventType type;
@end

// The command classes MPRemoteCommandCenter71.m creates lazily by class. Their own members are in their
// own objects (MPRatingCommandEvent.m, MPSkipIntervalCommandEvent.m and the 8.0/9.0 groups beside them),
// and none of those is what this stand-in is for: the check asks what the 7.1 object does with them.
@interface MPFeedbackCommand : MPRemoteCommand
@property (nonatomic, assign, readwrite) MPRemoteCommandHandlerStatus status;
@property (nonatomic, assign, readwrite) BOOL active;
@property (nonatomic, copy, readwrite) NSString *localizedTitle;
@property (nonatomic, copy, readwrite) NSString *localizedShortTitle;
@end
@interface MPSkipIntervalCommand : MPRemoteCommand
@property (nonatomic, assign, readwrite) NSInteger interval;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *preferredIntervals;
@end
@interface MPRatingCommand : MPRemoteCommand
@property (nonatomic, readonly) float minimumRating;
@property (nonatomic, readonly) float maximumRating;
@end
@interface MPChangePlaybackRateCommand : MPRemoteCommand
@property (nonatomic, readonly) NSArray<NSNumber *> *supportedPlaybackRates;
@end
@interface MPChangeRepeatModeCommand : MPRemoteCommand
@end
@interface MPChangeShuffleModeCommand : MPRemoteCommand
@end

// 8.0's, which the 7.1 object's switch names; its own members are in MPRemoteCommandCenter80.m.
@interface MPChangePlaybackPositionCommand : MPRemoteCommand
@property (nonatomic, assign, readwrite) NSTimeInterval positionTime;
@end
@interface MPChangePlaybackPositionCommandEvent : MPRemoteCommandEvent
@property (nonatomic, assign, readonly) NSTimeInterval positionTime;
@end

@interface MPRemoteCommandCenter : NSObject
+ (MPRemoteCommandCenter *)sharedCommandCenter;
@end
