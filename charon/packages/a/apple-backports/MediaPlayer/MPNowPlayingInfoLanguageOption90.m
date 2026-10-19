#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

@implementation MPNowPlayingInfoLanguageOption

@synthesize languageOptionType = _languageOptionType;
@synthesize languageTag = _languageTag;
@synthesize languageOptionCharacteristics = _languageOptionCharacteristics;
@synthesize displayName = _displayName;
@synthesize identifier = _identifier;

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
