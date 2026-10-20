#import <Foundation/Foundation.h>
#if defined(REVENANT_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

#if defined(REVENANT_MEDIAPLAYER_STANDIN)
@interface MPChangeLanguageOptionCommandEvent : MPRemoteCommandEvent
@property (nonatomic, strong, readwrite) MPNowPlayingInfoLanguageOption *languageOption;
@property (nonatomic, assign, readwrite) MPChangeLanguageOptionSetting setting;
@end
#else
@interface MPChangeLanguageOptionCommandEvent ()
@property (nonatomic, strong, readwrite) MPNowPlayingInfoLanguageOption *languageOption;
@property (nonatomic, assign, readwrite) MPChangeLanguageOptionSetting setting;
@end
#endif

@implementation MPChangeLanguageOptionCommandEvent
@synthesize languageOption = _languageOption;
@synthesize setting = _setting;

- (MPNowPlayingInfoLanguageOption *)languageOption {
    return _languageOption;
}

- (MPChangeLanguageOptionSetting)setting {
    return _setting;
}

@end
