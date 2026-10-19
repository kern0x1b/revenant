#import <Foundation/Foundation.h>

typedef NSNumber *MPMediaEntityPersistentID;

@interface MPMediaItem : NSObject
- (id)valueForProperty:(NSString *)property;
@end

@interface MPMediaItem (Revenant70)
@property (nonatomic, readonly) NSUInteger albumTrackNumber;
@property (nonatomic, readonly) NSUInteger discNumber;
@end

@class UIImage;

@interface MPMediaItemArtwork : NSObject
- (instancetype)initWithImage:(id)image;
- (UIImage *)imageWithSize:(CGSize)size;
- (CGRect)bounds;
@end

@interface MPMediaItemArtwork (Revenant100)
- (instancetype)initWithBoundsSize:(CGSize)boundsSize requestHandler:(UIImage *(^)(CGSize size))requestHandler;
@end

typedef NSUInteger MPChangeLanguageOptionSetting;
typedef NSInteger MPRepeatType;
enum { MPRepeatTypeOff = 0, MPRepeatTypeOne = 1, MPRepeatTypeAll = 2 };
typedef NSInteger MPShuffleType;
enum { MPShuffleTypeOff = 0, MPShuffleTypeItems = 1, MPShuffleTypeCollections = 2 };
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

@interface MPRemoteCommand : NSObject
- (instancetype)initWithCommand:(id)command;
@property (nonatomic, assign, readonly, getter=isEnabled) BOOL enabled;
@end

@interface MPRemoteCommandEvent : NSObject
- (instancetype)initWithCommand:(MPRemoteCommand *)command;
@property (nonatomic, strong, readonly) MPRemoteCommand *command;
@property (nonatomic, assign, readonly) NSTimeInterval timestamp;
@end

typedef NS_ENUM(NSInteger, MPSeekCommandEventType) {
    MPSeekCommandEventTypeBeginSeeking = 0,
    MPSeekCommandEventTypeEndSeeking = 1,
};

@interface MPSeekCommandEvent : MPRemoteCommandEvent
@property (nonatomic, assign, readonly) MPSeekCommandEventType type;
@end

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

@interface MPChangePlaybackPositionCommand : MPRemoteCommand
@property (nonatomic, assign, readwrite) NSTimeInterval positionTime;
@end
@interface MPChangePlaybackPositionCommandEvent : MPRemoteCommandEvent
@property (nonatomic, assign, readonly) NSTimeInterval positionTime;
@end

@interface MPRemoteCommandCenter : NSObject
+ (MPRemoteCommandCenter *)sharedCommandCenter;
@end
